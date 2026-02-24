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

# Delete all prior perf comments if they exist (match marker).
COMMENT_IDS="$(gh api \
  repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments \
  --jq '.[] | select(.body | contains("<!-- vox-perf-audit -->")) | .id' \
  2>/dev/null || true)"

if [ -n "$COMMENT_IDS" ]; then
  while IFS= read -r comment_id; do
    [ -n "$comment_id" ] || continue
    gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${comment_id}" -X DELETE 2>/dev/null || true
  done <<< "$COMMENT_IDS"
fi

gh pr comment "$PR_NUMBER" --body-file "$REPORT_PATH"
