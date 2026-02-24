#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  backfill-perf-audit.sh [options]

Options:
  --source-repo <owner/repo>   Source repo with perf workflows (default: misty-step/vox)
  --audit-repo <owner/repo>    Destination perf store repo (default: misty-step/vox-perf-audit)
  --workflow-id <id>           Perf: Audit workflow id (default: 235386171)
  --days <n>                   Backfill window in days (default: 14)
  --max-runs <n>               Max recent pull_request runs to scan (default: 100, API cap)
  --run-id <id>                Process one workflow run id only
  --require-pr                 Fail if PR number cannot be resolved
  --dry-run                    Print intended writes only
  -h, --help                   Show help
EOF
}

SOURCE_REPO="${SOURCE_REPO:-misty-step/vox}"
AUDIT_REPO="${AUDIT_REPO:-misty-step/vox-perf-audit}"
WORKFLOW_ID="${WORKFLOW_ID:-235386171}"
DAYS="${DAYS:-14}"
MAX_RUNS="${MAX_RUNS:-100}"
RUN_ID=""
REQUIRE_PR=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --source-repo) SOURCE_REPO="$2"; shift 2 ;;
    --audit-repo) AUDIT_REPO="$2"; shift 2 ;;
    --workflow-id) WORKFLOW_ID="$2"; shift 2 ;;
    --days) DAYS="$2"; shift 2 ;;
    --max-runs) MAX_RUNS="$2"; shift 2 ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    --require-pr) REQUIRE_PR=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [ -z "${GH_TOKEN:-}" ]; then
  echo "GH_TOKEN is required." >&2
  exit 1
fi

if ! printf '%s' "$DAYS" | grep -Eq '^[0-9]+$'; then
  echo "--days must be an integer." >&2
  exit 1
fi
if ! printf '%s' "$MAX_RUNS" | grep -Eq '^[0-9]+$' || [ "$MAX_RUNS" -lt 1 ] || [ "$MAX_RUNS" -gt 100 ]; then
  echo "--max-runs must be an integer in [1,100]." >&2
  exit 1
fi
if [ -n "$RUN_ID" ] && ! printf '%s' "$RUN_ID" | grep -Eq '^[0-9]+$'; then
  echo "--run-id must be numeric." >&2
  exit 1
fi

CUTOFF_ISO="$(python3 - "$DAYS" <<'PY'
from datetime import datetime, timedelta, timezone
import sys
days = int(sys.argv[1])
dt = datetime.now(timezone.utc) - timedelta(days=days)
print(dt.strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/vox-perf-backfill.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

resolve_pr_number() {
  local run_pr="$1"
  local sha="$2"
  local head_branch="$3"
  local pr_lookup repo_owner
  if printf '%s' "$run_pr" | grep -Eq '^[0-9]+$'; then
    echo "$run_pr"
    return 0
  fi

  pr_lookup="$(gh api \
    -H "Accept: application/vnd.github+json" \
    "repos/${SOURCE_REPO}/commits/${sha}/pulls" \
    --jq 'map(select(.base.ref=="master")) | sort_by(.number) | last | .number // empty' \
    2>/dev/null || true)"
  if printf '%s' "$pr_lookup" | grep -Eq '^[0-9]+$'; then
    echo "$pr_lookup"
    return 0
  fi

  if [ -n "$head_branch" ]; then
    repo_owner="${SOURCE_REPO%%/*}"
    pr_lookup="$(gh api \
      --method GET \
      "repos/${SOURCE_REPO}/pulls" \
      -f state=all \
      -f head="${repo_owner}:${head_branch}" \
      -f per_page=5 \
      --jq 'sort_by(.number) | last | .number // empty' \
      2>/dev/null || true)"
    if printf '%s' "$pr_lookup" | grep -Eq '^[0-9]+$'; then
      echo "$pr_lookup"
      return 0
    fi
  fi
  echo ""
}

resolve_pr_from_artifact() {
  local artifact_json="$1"
  local expected_sha="$2"
  local artifact_pr artifact_sha

  artifact_pr="$(jq -r '.pullRequestNumber // empty' "$artifact_json" 2>/dev/null || true)"
  artifact_sha="$(jq -r '.commitSHA // empty' "$artifact_json" 2>/dev/null || true)"
  artifact_sha="$(printf '%s' "$artifact_sha" | tr '[:upper:]' '[:lower:]')"

  if ! printf '%s' "$artifact_pr" | grep -Eq '^[0-9]+$'; then
    echo ""
    return 0
  fi
  if ! printf '%s' "$artifact_sha" | grep -Eq '^[0-9a-f]{40}$'; then
    echo ""
    return 0
  fi
  if [ "$artifact_sha" != "$expected_sha" ]; then
    echo ""
    return 0
  fi

  echo "$artifact_pr"
}

upload_file() {
  local src="$1"
  local dest_path="$2"
  local msg="$3"
  local payload content http_out

  if gh api "repos/${AUDIT_REPO}/contents/${dest_path}" >/dev/null 2>&1; then
    echo "skip exists ${dest_path}"
    return 2
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "dry-run upload ${dest_path}"
    return 0
  fi

  content="$(base64 < "$src" | tr -d '\n')"
  payload="$(mktemp "${tmp_dir}/upload.XXXXXX.json")"
  jq -n \
    --arg message "$msg" \
    --arg content "$content" \
    '{
      message: $message,
      content: $content,
      committer: {
        name: "github-actions[bot]",
        email: "41898282+github-actions[bot]@users.noreply.github.com"
      }
    }' > "$payload"

  http_out="$(gh api \
    --method PUT \
    "repos/${AUDIT_REPO}/contents/${dest_path}" \
    --input "$payload" \
    2>&1)" || {
      rm -f "$payload"
      if echo "$http_out" | grep -Eqi "already exists|HTTP/[0-9.]+ 422|sha wasn't supplied"; then
        echo "skip exists ${dest_path}"
        return 2
      fi
      echo "upload failed ${dest_path}: $http_out" >&2
      return 1
    }
  rm -f "$payload"
  echo "uploaded ${dest_path}"
  return 0
}

process_run() {
  local id="$1"
  local run_number="$2"
  local created_at="$3"
  local conclusion="$4"
  local sha="$5"
  local run_pr="$6"
  local head_branch="$7"

  local pr artifact_id run_dir zip_path extract_dir head_json codepath_json should_copy rc artifact_pr meta_json
  local uploaded_for_run=0

  if [ "$conclusion" != "success" ]; then
    echo "skip run ${id}: conclusion=${conclusion}"
    return 0
  fi
  if [ -z "$RUN_ID" ] && [ "$created_at" \< "$CUTOFF_ISO" ]; then
    return 0
  fi
  if ! printf '%s' "$sha" | grep -Eq '^[0-9a-fA-F]{40}$'; then
    echo "skip run ${id}: invalid sha ${sha}" >&2
    return 0
  fi
  sha="$(printf '%s' "$sha" | tr '[:upper:]' '[:lower:]')"

  pr="$(resolve_pr_number "$run_pr" "$sha" "$head_branch")"

  artifact_id="$(gh api "repos/${SOURCE_REPO}/actions/runs/${id}/artifacts" \
    --jq '.artifacts[] | select(.expired==false) | select(.name | startswith("perf-audit-pr-")) | .id' \
    2>/dev/null | head -n 1 || true)"
  if [ -z "$artifact_id" ]; then
    echo "skip run ${id}: no perf artifact"
    return 0
  fi

  run_dir="${tmp_dir}/run-${id}"
  mkdir -p "$run_dir"
  zip_path="${run_dir}/artifact.zip"
  extract_dir="${run_dir}/extract"
  gh api "repos/${SOURCE_REPO}/actions/artifacts/${artifact_id}/zip" > "$zip_path"
  unzip -q "$zip_path" -d "$extract_dir"

  head_json="$(find "$extract_dir" -name head.json -type f | head -n 1 || true)"
  codepath_json="$(find "$extract_dir" -name head-codepath.json -type f | head -n 1 || true)"
  if [ -z "$head_json" ] && [ -z "$codepath_json" ]; then
    echo "skip run ${id}: artifact missing head JSON files"
    return 0
  fi

  if ! printf '%s' "$pr" | grep -Eq '^[0-9]+$'; then
    meta_json="${head_json:-$codepath_json}"
    artifact_pr="$(resolve_pr_from_artifact "$meta_json" "$sha")"
    if printf '%s' "$artifact_pr" | grep -Eq '^[0-9]+$'; then
      pr="$artifact_pr"
      echo "resolved PR from artifact metadata for run ${id}: pr=${pr}"
    fi
  fi
  if ! printf '%s' "$pr" | grep -Eq '^[0-9]+$'; then
    if [ "$REQUIRE_PR" -eq 1 ]; then
      echo "failed run ${id}: unable to resolve PR for ${sha}" >&2
      return 1
    fi
    echo "skip run ${id}: unresolved PR for ${sha}"
    return 0
  fi

  if [ -n "$head_json" ]; then
    if upload_file \
      "$head_json" \
      "audit/pr/${pr}/${sha}.json" \
      "perf(audit): pr#${pr} ${sha} (run ${run_number})"; then
      rc=0
    else
      rc=$?
    fi
    if [ "$rc" -eq 1 ]; then
      return 1
    fi
    if [ "$rc" -eq 0 ]; then
      uploaded_for_run=1
    fi
  fi

  if [ -n "$codepath_json" ]; then
    should_copy=1
    if [ -n "$head_json" ] && cmp -s "$codepath_json" "$head_json"; then
      should_copy=0
    fi
    if [ "$should_copy" -eq 1 ]; then
      if upload_file \
        "$codepath_json" \
        "audit/pr/${pr}/${sha}-codepath.json" \
        "perf(audit): pr#${pr} ${sha} codepath (run ${run_number})"; then
        rc=0
      else
        rc=$?
      fi
      if [ "$rc" -eq 1 ]; then
        return 1
      fi
      if [ "$rc" -eq 0 ]; then
        uploaded_for_run=1
      fi
    fi
  fi

  if [ "$uploaded_for_run" -eq 1 ]; then
    echo "processed run ${id}: pr=${pr} sha=${sha}"
  else
    echo "processed run ${id}: no new files (already present)"
  fi
}

if [ -n "$RUN_ID" ]; then
  run_line="$(gh api "repos/${SOURCE_REPO}/actions/runs/${RUN_ID}" \
    --jq '[.id, .run_number, .created_at, .conclusion, .head_sha, (.pull_requests[0].number // "__none__"), (.head_branch // "__none__")] | @tsv')"
  if [ -z "$run_line" ]; then
    echo "run ${RUN_ID} not found." >&2
    exit 1
  fi
  IFS=$'\t' read -r id run_number created_at conclusion sha run_pr head_branch <<< "$run_line"
  if [ "$run_pr" = "__none__" ]; then
    run_pr=""
  fi
  if [ "$head_branch" = "__none__" ]; then
    head_branch=""
  fi
  process_run "$id" "$run_number" "$created_at" "$conclusion" "$sha" "$run_pr" "$head_branch"
  exit 0
fi

runs_tsv="$(gh api \
  "repos/${SOURCE_REPO}/actions/workflows/${WORKFLOW_ID}/runs?event=pull_request&status=completed&per_page=${MAX_RUNS}" \
  --jq '.workflow_runs[] | [.id, .run_number, .created_at, .conclusion, .head_sha, (.pull_requests[0].number // "__none__"), (.head_branch // "__none__")] | @tsv')"

if [ -z "$runs_tsv" ]; then
  echo "No workflow runs found."
  exit 0
fi

echo "Scanning up to ${MAX_RUNS} pull_request runs from ${SOURCE_REPO} since ${CUTOFF_ISO}."
while IFS=$'\t' read -r id run_number created_at conclusion sha run_pr head_branch; do
  if [ "$run_pr" = "__none__" ]; then
    run_pr=""
  fi
  if [ "$head_branch" = "__none__" ]; then
    head_branch=""
  fi
  process_run "$id" "$run_number" "$created_at" "$conclusion" "$sha" "$run_pr" "$head_branch"
done <<< "$runs_tsv"
