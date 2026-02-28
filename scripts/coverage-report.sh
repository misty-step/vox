#!/usr/bin/env bash
set -euo pipefail

OUTPUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) OUTPUT="$2"; shift 2 ;;
    *) echo "usage: $0 [--output report.md]" >&2; exit 2 ;;
  esac
done

echo "[coverage] Running tests with coverage enabled..."
swift test --enable-code-coverage -Xswiftc -warnings-as-errors 2>&1 | tee /tmp/vox-coverage-test.log | tail -n 5

# Locate profdata and test binary
CODECOV_PATH="$(swift test --show-codecov-path 2>/dev/null)"
PROFDATA_DIR="$(dirname "$CODECOV_PATH")"
PROFDATA="${PROFDATA_DIR}/default.profdata"

if [ ! -f "$PROFDATA" ]; then
  echo "[coverage] profdata not found at $PROFDATA" >&2
  exit 1
fi

# Find the merged test binary
TEST_BINARY="$(find .build -name "VoxPackageTests.xctest" -type d 2>/dev/null | head -n 1)"
if [ -z "$TEST_BINARY" ]; then
  echo "[coverage] VoxPackageTests.xctest bundle not found" >&2
  exit 1
fi
TEST_BINARY="${TEST_BINARY}/Contents/MacOS/VoxPackageTests"

if [ ! -f "$TEST_BINARY" ]; then
  echo "[coverage] test binary not found at $TEST_BINARY" >&2
  exit 1
fi

echo "[coverage] Generating coverage report..."

# Export coverage JSON, excluding .build and Tests directories
COVERAGE_JSON_FILE="$(mktemp)"
trap 'rm -f "$COVERAGE_JSON_FILE"' EXIT
xcrun llvm-cov export \
  -summary-only \
  -instr-profile "$PROFDATA" \
  "$TEST_BINARY" \
  -ignore-filename-regex='\.build|Tests/' 2>/dev/null > "$COVERAGE_JSON_FILE"

# Parse JSON into markdown with python3
REPORT="$(python3 - "$COVERAGE_JSON_FILE" << 'PYEOF'
import json
import sys

with open(sys.argv[1]) as f:
    data = json.load(f)

# Module names we care about (source directories under Sources/)
MODULE_NAMES = [
    "VoxCore", "VoxProviders", "VoxMac", "VoxDiagnostics",
    "VoxPipeline", "VoxUI", "VoxSession", "VoxAppKit",
    "VoxPerfAuditKit",
]

# Aggregate per-module stats and collect per-file stats
modules = {}  # name -> {covered, total}
files_below_threshold = []  # (path, covered, total, pct)
THRESHOLD = 50

for fn in data.get("data", [{}])[0].get("files", []):
    filename = fn["filename"]
    lines = fn["summary"]["lines"]
    covered = lines["covered"]
    total = lines["count"]

    # Determine module from path (Sources/<Module>/...)
    module = None
    if "/Sources/" in filename:
        parts = filename.split("/Sources/")[1].split("/")
        if parts:
            candidate = parts[0]
            if candidate in MODULE_NAMES:
                module = candidate

    if module:
        if module not in modules:
            modules[module] = {"covered": 0, "total": 0}
        modules[module]["covered"] += covered
        modules[module]["total"] += total

    # Track low-coverage files
    if total > 0:
        pct = (covered / total) * 100
        if pct < THRESHOLD:
            # Shorten path for display
            short = filename.split("/Sources/")[1] if "/Sources/" in filename else filename.rsplit("/", 2)[-1]
            files_below_threshold.append((short, covered, total, pct))

# Sort modules by name, low-coverage files by coverage ascending
sorted_modules = sorted(modules.items())
files_below_threshold.sort(key=lambda x: x[3])

# Totals
total_covered = sum(m["covered"] for m in modules.values())
total_lines = sum(m["total"] for m in modules.values())
total_pct = (total_covered / total_lines * 100) if total_lines > 0 else 0

# Build markdown
lines_out = []
lines_out.append("<!-- vox-coverage-report -->")
lines_out.append("## Test Coverage")
lines_out.append("")
lines_out.append("| Module | Lines | Coverage |")
lines_out.append("|--------|-------|----------|")

for name, stats in sorted_modules:
    c, t = stats["covered"], stats["total"]
    pct = (c / t * 100) if t > 0 else 0
    lines_out.append(f"| {name} | {c}/{t} | {pct:.1f}% |")

lines_out.append(f"| **Total** | **{total_covered}/{total_lines}** | **{total_pct:.1f}%** |")
lines_out.append("")

if files_below_threshold:
    n = len(files_below_threshold)
    lines_out.append(f"<details><summary>Files below {THRESHOLD}% coverage ({n} files)</summary>")
    lines_out.append("")
    lines_out.append("| File | Lines | Coverage |")
    lines_out.append("|------|-------|----------|")
    for path, c, t, pct in files_below_threshold:
        lines_out.append(f"| {path} | {c}/{t} | {pct:.1f}% |")
    lines_out.append("")
    lines_out.append("</details>")

print("\n".join(lines_out))
PYEOF
)"

if [ -n "$OUTPUT" ]; then
  echo "$REPORT" > "$OUTPUT"
  echo "[coverage] Report written to $OUTPUT"
else
  echo "$REPORT"
fi

# Enforce per-module coverage thresholds.
# VoxMac / VoxUI / VoxAppKit excluded: hardware I/O, SwiftUI, composition root.
THRESHOLD_CHECK_OUTPUT=""
THRESHOLD_CHECK_EXIT=0
THRESHOLD_CHECK_OUTPUT="$(python3 - "$COVERAGE_JSON_FILE" << 'PYEOF'
import json, sys

THRESHOLDS = {
    "VoxCore": 90,
    "VoxPipeline": 90,
    "VoxPerfAuditKit": 90,
    "VoxProviders": 72,  # AppleSpeechClient (93 lines, 0%) requires hardware
    "VoxDiagnostics": 60,
    "VoxSession": 60,
}

MODULE_NAMES = list(THRESHOLDS.keys()) + ["VoxMac", "VoxUI", "VoxAppKit"]

with open(sys.argv[1]) as f:
    data = json.load(f)
modules = {}
for fn in data.get("data", [{}])[0].get("files", []):
    filename = fn["filename"]
    lines = fn["summary"]["lines"]
    if "/Sources/" not in filename:
        continue
    parts = filename.split("/Sources/")[1].split("/")
    if not parts:
        continue
    module = parts[0]
    if module not in MODULE_NAMES:
        continue
    if module not in modules:
        modules[module] = {"covered": 0, "total": 0}
    modules[module]["covered"] += lines["covered"]
    modules[module]["total"] += lines["count"]

violations = []
for name, threshold in THRESHOLDS.items():
    stats = modules.get(name)
    if not stats or stats["total"] == 0:
        continue
    pct = stats["covered"] / stats["total"] * 100
    if pct < threshold:
        violations.append(f"  {name}: {pct:.1f}% < {threshold}% required")

if violations:
    print("Coverage threshold violations:")
    for v in violations:
        print(v)
    sys.exit(1)
PYEOF
)" || THRESHOLD_CHECK_EXIT=$?
if [ "$THRESHOLD_CHECK_EXIT" -ne 0 ]; then
  echo "[coverage] Coverage gate failed:" >&2
  echo "$THRESHOLD_CHECK_OUTPUT" >&2
  exit "$THRESHOLD_CHECK_EXIT"
fi
