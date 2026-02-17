#!/usr/bin/env bash
set -euo pipefail

REPORT_PATH="${1:-}"
REASON="${2:-}"

if [ -z "$REPORT_PATH" ] || [ -z "$REASON" ]; then
  echo "usage: $0 <report.md> <reason>" >&2
  exit 2
fi

mkdir -p "$(dirname "$REPORT_PATH")"

cat >"$REPORT_PATH" <<EOF
<!-- vox-perf-audit -->
## Performance Report

Skipped: ${REASON}

To run locally:
\`\`\`bash
bash scripts/perf/make-fixture-audio.sh /tmp/vox-perf-fixture.caf
swift run VoxPerfAudit --audio /tmp/vox-perf-fixture.caf --output /tmp/vox-perf.json --iterations 2
python3 scripts/perf/format-perf-report.py --head /tmp/vox-perf.json
\`\`\`
EOF

