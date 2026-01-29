#!/bin/bash
# Run VoxLocal with API keys from sibling vox repo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOX_ENV="${SCRIPT_DIR}/../../vox/.env.local"

if [ -f "$VOX_ENV" ]; then
    export $(grep -E '^(ELEVENLABS_API_KEY|OPENROUTER_API_KEY)=' "$VOX_ENV" | xargs)
fi

exec "${SCRIPT_DIR}/../.build/debug/VoxLocal" "$@"
