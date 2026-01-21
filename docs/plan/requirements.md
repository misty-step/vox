# Requirements

## Goals (MVP)
- Global toggle hotkey (start/stop)
- Menu bar state indicator
- Batch STT on stop
- Rewrite for quality, not speed
- Insert at cursor reliably
- Minimal config file (prototype)
- Single rewrite level setting (off/light/aggressive)

## Non-goals (MVP)
- Commands or agent actions
- Screen/context reading beyond `context.md`
- Offline transcription
- Multi-step editor

## Non-functional
- Quality > speed, especially for long dictations
- Latency: bounded but not tight (seconds ok)
- Reliability: fallback path always available
- Prototype: API keys in local config
- Portability: provider swap without app rewrite

## Data and storage
- Local: `context.md`, config, logs (redacted)
- Local history artifacts: raw/rewrite/final + metadata in `~/Documents/Vox/history` (disable: `VOX_HISTORY=0`, redact: `VOX_HISTORY_REDACT=1`)
- No audio retention by default

## Permissions
- Microphone
- Accessibility (caret + paste)
