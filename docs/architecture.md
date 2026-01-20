# Architecture

## Goal
- Hotkey → record → transcribe → rewrite → paste
- Few moving parts, deep modules, clear seams

## Module map
- `VoxApp`: app wiring + orchestration
  - `SessionController`: hotkey toggle, state, UI signals
  - `DictationPipeline`: STT → rewrite, returns final text
- `VoxMac`: macOS integration
  - `AudioRecorder`: mic → file
  - `ClipboardPaster`: copy + paste + restore
  - `HUDController`/`HUDView`: feedback UI
  - `HotkeyMonitor`, `PermissionManager`
- `VoxProviders`: provider adapters
  - `ElevenLabsSTTProvider`
  - `GeminiRewriteProvider`
- `VoxCore`: contracts + errors + utilities

## Data flow
1. Hotkey tap: start recording, capture target app
2. Hotkey tap: stop recording, run pipeline
3. STT returns raw transcript
4. LLM rewrites transcript (fallback to raw on failure)
5. Paste into target app, keep clipboard for manual paste

## State model
- `idle` → `recording` → `processing` → `idle`
- UI is driven by state + status messages

## Core contracts
- `TranscriptionRequest` → `Transcript`
- `RewriteRequest` → `RewriteResponse`
- Providers are pure adapters with no UI logic

## Clipboard policy
- Always write to pasteboard
- Attempt Cmd+V paste
- Keep clipboard for `VOX_CLIPBOARD_HOLD_MS` (default 120s)

## Failure policy
- STT fail: stop, log, no paste
- Rewrite fail: use raw transcript
- Paste fail: keep clipboard + show message

## Config
- `.env.local` overrides, else `~/Documents/Vox/config.json`
- No UI config in prototype

## Security
- Prototype uses local API keys
- Production should move secrets to backend
