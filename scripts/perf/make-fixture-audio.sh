#!/usr/bin/env bash
set -euo pipefail

# Generates a deterministic-ish speech fixture using macOS `say`, then converts to 16kHz mono CAF.
# Purpose: CI-safe audio input without committing binary fixtures.

OUT_PATH="${1:-}"

TMP_ROOT="${TMPDIR:-/tmp}"
WORK_DIR="$(mktemp -d "${TMP_ROOT%/}/vox-perf-audio.XXXXXX")"
AIFF_PATH="$WORK_DIR/fixture.aiff"
CAF_PATH="$WORK_DIR/fixture.caf"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

TEXT="Vox performance fixture. The quick brown fox jumps over the lazy dog. Vox performance fixture. The quick brown fox jumps over the lazy dog. Vox performance fixture. The quick brown fox jumps over the lazy dog."

say -o "$AIFF_PATH" "$TEXT"
afconvert "$AIFF_PATH" -o "$CAF_PATH" -f caff -d LEI16@16000 -c 1

if [ -n "$OUT_PATH" ]; then
  mkdir -p "$(dirname "$OUT_PATH")"
  cp "$CAF_PATH" "$OUT_PATH"
  echo "$OUT_PATH"
else
  # Caller can read the path and manage cleanup.
  # If they don't, it dies with this script. Prefer passing an explicit output.
  cp "$CAF_PATH" "$TMP_ROOT/vox-perf-fixture.caf"
  echo "$TMP_ROOT/vox-perf-fixture.caf"
fi

