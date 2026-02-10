#!/usr/bin/env bash
set -euo pipefail

run_filter() {
    local filter="$1"
    echo "[audio-guardrails] Running ${filter}..."
    swift test -Xswiftc -warnings-as-errors --filter "${filter}"
}

run_filter "AudioRecorderBackendSelectionTests"
run_filter "AudioRecorderConversionTests"
run_filter "AudioRecorderFileFormatTests"
run_filter "AudioRecorderWriteFormatValidationTests"
run_filter "CapturedAudioInspectorTests"
run_filter "DictationPipelineTests"

echo "[audio-guardrails] OK"
