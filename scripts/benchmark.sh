#!/usr/bin/env bash
set -euo pipefail

# Pipeline latency benchmark runner.
# Runs benchmark assertions in PipelineBenchmarkTests under strict compilation.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_PATH="$(mktemp "${TMPDIR:-/tmp}/benchmark.XXXXXX")"

cleanup() {
    rm -f "$OUTPUT_PATH"
}
trap cleanup EXIT

cd "$REPO_DIR"

echo "Running pipeline benchmark..."
if ! VOX_RUN_BENCHMARK_TESTS=1 swift test --filter PipelineBenchmarkTests -Xswiftc -warnings-as-errors >"$OUTPUT_PATH" 2>&1; then
    TEST_EXIT=$?
    grep -v "^\[Pipeline\]" "$OUTPUT_PATH" || true
    echo ""
    echo "Pipeline benchmark assertions failed (exit code $TEST_EXIT)."
    exit "$TEST_EXIT"
fi

grep -v "^\[Pipeline\]" "$OUTPUT_PATH" || true
echo ""
echo "Pipeline benchmark assertions passed."
exit 0
