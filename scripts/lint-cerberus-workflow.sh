#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[@]}")/.."

workflow=".github/workflows/cerberus.yml"

if [[ ! -f "$workflow" ]]; then
  echo "[cerberus-lint] Missing $workflow" >&2
  exit 1
fi

# Prefer upstream Cerberus validator for contract validation.
UPSTREAM_SCRIPT="${TMPDIR:-/tmp}/cerberus_consumer_workflow_validator.py"
UPSTREAM_URL="https://raw.githubusercontent.com/misty-step/cerberus/master/scripts/lib/consumer_workflow_validator.py"
FETCH_OK=false

if command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  if curl -fsSL --max-time 10 -o "$UPSTREAM_SCRIPT" "$UPSTREAM_URL" 2>/dev/null; then
    FETCH_OK=true
  else
    echo "[cerberus-lint] note: could not fetch upstream validator (using local fallback)" >&2
  fi
fi

run_upstream() {
  local tmp_output
  tmp_output=$(mktemp)
  local code=0
  if ! python3 "$UPSTREAM_SCRIPT" "$workflow" --fail-on-warnings="true" >"$tmp_output" 2>&1; then
    code=$?
  fi
  local errors=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^::(error|warning)::(.*)$ ]]; then
      local lvl="${BASH_REMATCH[1]}"
      local msg="${BASH_REMATCH[2]}"
      if [[ "$lvl" == "error" ]]; then
        errors=$((errors+1))
        # Upstream treats missing api-key as warning; we enforce it below.
        if [[ "$msg" == *"api-key"* ]]; then
          : # skip, we enforce separately
        else
          echo "[cerberus-lint] $lvl: $msg" >&2
        fi
      else
        # Only pass through misc warnings
        if [[ "$msg" != *"api-key"* ]]; then
          echo "[cerberus-lint] $lvl: $msg" >&2
        fi
      fi
    fi
  done <"$tmp_output"
  rm -f "$tmp_output"

  if [[ $errors -gt 0 || $code -ne 0 ]]; then
    exit 1
  fi
}

if [[ "$FETCH_OK" == "true" ]]; then
  run_upstream
fi

# Local enforcement of secret naming policy (hard requirement over upstream’s warning).
# Cerberus prefers CERBERUS_OPENROUTER_API_KEY; we enforce it.
if grep -nE 'api-key:\s*\$\{\{\s*secrets\.OPENROUTER_API_KEY\s*\}\}' "$workflow" >/dev/null; then
  echo "[cerberus-lint] error: use secrets.CERBERUS_OPENROUTER_API_KEY (dedicated Cerberus key), not secrets.OPENROUTER_API_KEY" >&2
  exit 1
fi

if ! grep -nE 'api-key:\s*\$\{\{\s*secrets\.CERBERUS_OPENROUTER_API_KEY\s*\}\}' "$workflow" >/dev/null; then
  echo "[cerberus-lint] error: missing required secret mapping secrets.CERBERUS_OPENROUTER_API_KEY" >&2
  exit 1
fi

echo "[cerberus-lint] OK"
