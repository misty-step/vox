#!/bin/bash
# Run Vox with API keys from local .env.local

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOX_ENV="${SCRIPT_DIR}/../.env.local"

if [ -f "$VOX_ENV" ]; then
    export $(grep -E '^(ELEVENLABS_API_KEY|OPENROUTER_API_KEY)=' "$VOX_ENV" | xargs)
fi

exec "${SCRIPT_DIR}/../.build/debug/Vox" "$@"
