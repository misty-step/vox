#!/usr/bin/env bash
set -euo pipefail

PR_NUMBER="${1:-}"
REPORT_PATH="${2:-}"

if [ -z "$PR_NUMBER" ] || [ -z "$REPORT_PATH" ]; then
  echo "usage: $0 <pr-number> <report.md>" >&2
  exit 2
fi

if [ ! -f "$REPORT_PATH" ]; then
  echo "missing report file: $REPORT_PATH" >&2
  exit 2
fi

if [ -z "${GH_TOKEN:-}" ]; then
  echo "missing GH_TOKEN" >&2
  exit 2
fi

if [ -z "${GITHUB_REPOSITORY:-}" ]; then
  echo "missing GITHUB_REPOSITORY" >&2
  exit 2
fi

MARKER="<!-- vox-coverage-report -->"

# Gather all coverage comments across all pages, then keep one sticky comment.
COMMENT_ROWS="$(gh api --paginate \
  "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
  --jq ".[] | select(.body | contains(\"${MARKER}\")) | [.id, .updated_at] | @tsv" \
  2>/dev/null || true)"

PRIMARY_COMMENT_ID=""
if [ -n "$COMMENT_ROWS" ]; then
  PRIMARY_COMMENT_ID="$(printf '%s\n' "$COMMENT_ROWS" | sort -k2 | tail -n 1 | cut -f1)"
fi

if [ -n "$PRIMARY_COMMENT_ID" ]; then
  PAYLOAD="$(mktemp "${RUNNER_TEMP:-/tmp}/vox-coverage-comment.XXXXXX.json")"
  jq -Rs '{body: .}' "$REPORT_PATH" > "$PAYLOAD"
  gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${PRIMARY_COMMENT_ID}" \
    --method PATCH \
    --input "$PAYLOAD" >/dev/null
  rm -f "$PAYLOAD"
else
  gh pr comment "$PR_NUMBER" --body-file "$REPORT_PATH" >/dev/null
fi

# Delete duplicates if any remain.
if [ -n "$COMMENT_ROWS" ]; then
  while IFS=$'\t' read -r comment_id _updated_at; do
    [ -n "$comment_id" ] || continue
    [ "$comment_id" = "$PRIMARY_COMMENT_ID" ] && continue
    gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${comment_id}" -X DELETE >/dev/null 2>&1 || true
  done <<< "$COMMENT_ROWS"
fi
