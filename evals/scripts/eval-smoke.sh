#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
npx promptfoo@latest eval --config promptfooconfig.yaml
