#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "[lint] swiftlint not found. Install with: brew install swiftlint" >&2
    exit 1
fi

echo "[lint] Running SwiftLint..."
swiftlint lint --strict --config .swiftlint.yml
echo "[lint] OK"
