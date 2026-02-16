#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

npx promptfoo@latest eval \
  --no-cache \
  --config polish-smoke.yaml \
  --output output/polish-smoke-results.json \
  --output output/polish-smoke-results.html \
  "$@"
