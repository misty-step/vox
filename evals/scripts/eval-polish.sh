#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

npx promptfoo@latest eval \
  --no-cache \
  --config polish-bakeoff.yaml \
  --output output/polish-bakeoff-results.json \
  --output output/polish-bakeoff-results.html \
  "$@"
