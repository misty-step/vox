#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

workflow=".github/workflows/cerberus.yml"

if [[ ! -f "$workflow" ]]; then
  echo "[cerberus-lint] Missing $workflow" >&2
  exit 1
fi

expect_contains() {
  local needle="$1"
  if ! rg -n --fixed-strings "$needle" "$workflow" >/dev/null; then
    echo "[cerberus-lint] Expected line missing: $needle" >&2
    exit 1
  fi
}

expect_absent() {
  local pattern="$1"
  if rg -n "$pattern" "$workflow" >/dev/null; then
    echo "[cerberus-lint] Forbidden legacy token matched: $pattern" >&2
    exit 1
  fi
}

# Enforce stock reusable workflow at master.
expect_contains "name: Cerberus"
expect_contains "uses: misty-step/cerberus/.github/workflows/cerberus.yml@master"
expect_contains 'api-key: ${{ secrets.OPENROUTER_API_KEY }}'

# Legacy council/named-reviewer config should not reappear.
expect_absent "Cerberus Council|Council Verdict|reviewer:\s*(APOLLO|ATHENA|SENTINEL|VULCAN|ARTEMIS)"

# Ensure this file is a reusable-workflow wrapper, not custom matrix/verdict wiring.
expect_absent "misty-step/cerberus@v2|misty-step/cerberus/verdict@v2|strategy:\s*$|matrix:\s*$"

echo "[cerberus-lint] OK"
