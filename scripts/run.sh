#!/bin/bash
# Run Vox with API keys from local .env.local

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOX_ENV="${SCRIPT_DIR}/../.env.local"
ROOT_DIR="${SCRIPT_DIR}/.."

if [ -f "$VOX_ENV" ]; then
    while IFS= read -r line; do
        [ -n "$line" ] && export "$line"
    done < <(grep -E '^(ELEVENLABS_API_KEY|GEMINI_API_KEY|OPENROUTER_API_KEY|DEEPGRAM_API_KEY|OPENAI_API_KEY)=' "$VOX_ENV" || true)
fi

if [ -z "${VOX_APP_VERSION:-}" ]; then
    tag="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || true)"
    tag="${tag#v}"
    export VOX_APP_VERSION="${tag:-0.0.0-dev}"
fi

if [ -z "${VOX_BUILD_NUMBER:-}" ]; then
    sha="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || true)"
    export VOX_BUILD_NUMBER="${sha:-local}"
fi

exec "${SCRIPT_DIR}/../.build/debug/Vox" "$@"
