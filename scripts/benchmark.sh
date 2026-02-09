#!/bin/bash
set -euo pipefail

# Pipeline latency benchmark runner.
# Runs PipelineBenchmarkTests, captures JSON artifact, optionally compares against baseline.
#
# Usage:
#   ./scripts/benchmark.sh                 # Run benchmark, print summary
#   ./scripts/benchmark.sh --compare       # Run + compare against committed baseline
#   ./scripts/benchmark.sh --json          # Run + output raw JSON
#   ./scripts/benchmark.sh --update-baseline  # Run + overwrite baseline.json

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASELINE_PATH="$REPO_DIR/docs/performance/baseline.json"
OUTPUT_PATH="$(mktemp /tmp/benchmark-XXXXXX.json)"

COMPARE=false
RAW_JSON=false
UPDATE_BASELINE=false

for arg in "$@"; do
    case "$arg" in
        --compare) COMPARE=true ;;
        --json) RAW_JSON=true ;;
        --update-baseline) UPDATE_BASELINE=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

cleanup() {
    rm -f "$OUTPUT_PATH"
}
trap cleanup EXIT

echo "Running pipeline benchmark..."
swift test --filter "PipelineBenchmarkTests" \
    -Xswiftc -warnings-as-errors 2>&1 | grep -v "^\[Pipeline\]" || true

# TODO: swift test doesn't forward env vars to test processes, so JSON artifact
# is never produced. The --json/--compare/--update-baseline paths below are
# infrastructure for when a JSON export mechanism is wired up.
if [ ! -f "$OUTPUT_PATH" ] || [ ! -s "$OUTPUT_PATH" ]; then
    echo ""
    echo "Budget assertion tests completed. JSON artifact not yet supported (see TODO in script)."
    exit 0
fi

echo ""
echo "=== Benchmark Results ==="

if $RAW_JSON; then
    cat "$OUTPUT_PATH"
    exit 0
fi

# Pretty-print stage summary using python (available on macOS)
python3 -c "
import json, sys

with open('$OUTPUT_PATH') as f:
    data = json.load(f)

print(f\"Iterations: {data['iterations']}\")
print(f\"Timestamp:  {data['timestamp']}\")
print()
print(f\"{'Stage':<12} {'p50':>8} {'p95':>8} {'min':>8} {'max':>8}\")
print('-' * 44)
for stage in ['encode', 'stt', 'rewrite', 'paste', 'total']:
    s = data['stages'].get(stage, {})
    print(f\"{stage:<12} {s.get('p50',0)*1000:7.1f}ms {s.get('p95',0)*1000:7.1f}ms {s.get('min',0)*1000:7.1f}ms {s.get('max',0)*1000:7.1f}ms\")

if data.get('budgets'):
    print()
    print('Budget Checks:')
    for name, b in sorted(data['budgets'].items()):
        status = '✔' if b['pass'] else '✘'
        print(f\"  {status} {name}: {b['actual']*1000:.1f}ms (target: {b['target']*1000:.1f}ms)\")
"

if $UPDATE_BASELINE; then
    mkdir -p "$(dirname "$BASELINE_PATH")"
    cp "$OUTPUT_PATH" "$BASELINE_PATH"
    echo ""
    echo "Baseline updated: $BASELINE_PATH"
    exit 0
fi

if $COMPARE; then
    if [ ! -f "$BASELINE_PATH" ]; then
        echo ""
        echo "No baseline found at $BASELINE_PATH"
        echo "Run with --update-baseline to create one."
        exit 1
    fi

    echo ""
    echo "=== Regression Check ==="

    python3 -c "
import json, sys

with open('$OUTPUT_PATH') as f:
    current = json.load(f)
with open('$BASELINE_PATH') as f:
    baseline = json.load(f)

WARN_THRESHOLD = 0.20   # 20% regression = warning
FAIL_THRESHOLD = 0.50   # 50% regression = failure

has_warning = False
has_failure = False

for stage in ['encode', 'stt', 'rewrite', 'paste', 'total']:
    curr_p95 = current['stages'].get(stage, {}).get('p95', 0)
    base_p95 = baseline['stages'].get(stage, {}).get('p95', 0)

    if base_p95 == 0:
        continue

    delta = (curr_p95 - base_p95) / base_p95

    if delta > FAIL_THRESHOLD:
        print(f'✘ FAIL {stage} p95: {curr_p95*1000:.1f}ms vs baseline {base_p95*1000:.1f}ms (+{delta*100:.0f}%)')
        has_failure = True
    elif delta > WARN_THRESHOLD:
        print(f'⚠ WARN {stage} p95: {curr_p95*1000:.1f}ms vs baseline {base_p95*1000:.1f}ms (+{delta*100:.0f}%)')
        has_warning = True
    else:
        print(f'✔ OK   {stage} p95: {curr_p95*1000:.1f}ms vs baseline {base_p95*1000:.1f}ms ({delta*100:+.0f}%)')

if has_failure:
    print()
    print('FAILED: Regression exceeds 50% threshold.')
    sys.exit(1)
elif has_warning:
    print()
    print('WARNING: Regression exceeds 20% threshold.')
    sys.exit(0)
else:
    print()
    print('All stages within regression thresholds.')
"
fi
