# Vox

Invisible editor for macOS. Hotkey → record → STT → LLM rewrite → paste.

Status: working prototype.

## Prereqs
- macOS 13+
- Xcode Command Line Tools

## Quickstart
1. Add `.env.local` in repo root
2. Run `swift run VoxApp`
3. Tap Option+Space to record, tap again to submit

## Config
Preferred: `.env.local`
- Required: `ELEVENLABS_API_KEY`, `GEMINI_API_KEY`
- Optional: `ELEVENLABS_MODEL_ID`, `ELEVENLABS_LANGUAGE`
- Optional: `GEMINI_MODEL_ID`, `GEMINI_TEMPERATURE`, `GEMINI_MAX_TOKENS`, `GEMINI_THINKING_LEVEL`
- Optional: `VOX_CONTEXT_PATH`, `VOX_PROCESSING_LEVEL` (fallback: `VOX_REWRITE_LEVEL`, default: `light`)
  - `VOX_PROCESSING_LEVEL` overrides menu selection; UI changes won’t persist until removed
- Optional: `VOX_LOG_LEVEL` (debug | info | error | off; default: info)

Fallback: `~/Documents/Vox/config.json`
- Auto-generated on first run if missing
- `processingLevel`: off | light | aggressive (default: light)

## Usage
- Hotkey: Option+Space (default)
- HUD states: recording → processing → copied
- If paste is blocked, Vox keeps text on clipboard

## Paste controls
- `VOX_PASTE_RESTORE=0` keep clipboard contents
- `VOX_PASTE_RESTORE_DELAY_MS=500` delay restore
- `VOX_CLIPBOARD_HOLD_MS=120000` hold clipboard on fallback

## Troubleshooting
- Enable alerts: `VOX_DEBUG_ALERTS=1 swift run VoxApp`
- Paste not working: check Secure Keyboard Entry
- Mic/paste require macOS permissions
- ElevenLabs language must be ISO 639-3 (e.g. `eng`)

## Docs
- Architecture: `docs/architecture.md`
- Quality gates: `docs/quality.md`
- ADRs: `docs/adr/`

## Quality gates
- Hooks: `git config core.hooksPath .githooks`
- Hooks skip when no Swift/Package changes; targets: pre-commit <5s, pre-push <15s
- CI: GitHub Actions on push/PR
