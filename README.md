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
- Required: `ELEVENLABS_API_KEY`
- Rewrite provider: `VOX_REWRITE_PROVIDER` (gemini | openrouter, default: gemini)
- Optional gateway: `VOX_GATEWAY_URL`, `VOX_GATEWAY_TOKEN` (routes STT + rewrite via gateway)
- Gemini: `GEMINI_API_KEY` required when provider=gemini
- Optional (Gemini): `GEMINI_MODEL_ID` (default: `gemini-3-flash-preview`, accepts gemini-3-pro* or gemini-3-flash*), `GEMINI_TEMPERATURE`, `GEMINI_MAX_TOKENS` (default: 65536), `GEMINI_THINKING_LEVEL`
- OpenRouter: `OPENROUTER_API_KEY`, `OPENROUTER_MODEL_ID` required when provider=openrouter
- Optional (OpenRouter): `OPENROUTER_TEMPERATURE`, `OPENROUTER_MAX_TOKENS`
- Optional: `ELEVENLABS_MODEL_ID`, `ELEVENLABS_LANGUAGE`
- Optional: `VOX_CONTEXT_PATH`, `VOX_PROCESSING_LEVEL` (fallback: `VOX_REWRITE_LEVEL`, default: `light`)
  - `VOX_PROCESSING_LEVEL` overrides menu selection; UI changes won’t persist until removed
- Optional: `VOX_HISTORY=0` disable local history artifacts (default: on)
- Optional: `VOX_HISTORY_DIR=/path/to/dir` override history location
- Optional: `VOX_HISTORY_REDACT=1` store redacted history text
- Optional: `VOX_LOG_LEVEL` (debug | info | error | off; default: info)

Fallback: `~/Documents/Vox/config.json`
- Auto-generated on first run if missing
- `rewrite.provider` selects provider id
- `rewrite.providers` list: `{ id, apiKey, modelId, temperature?, maxOutputTokens?, thinkingLevel? }`
- `processingLevel`: off | light | aggressive (default: light)

## Usage
- Hotkey: Option+Space (default)
- HUD states: recording → processing → copied
- If paste is blocked, Vox keeps text on clipboard
- History artifacts: `~/Documents/Vox/history/YYYY-MM-DD/<sessionId>` (raw/rewrite/final + metadata)

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
- Monorepo layout: `docs/plan/monorepo-layout.md`

## Monorepo apps
- `apps/web` — marketing + download + checkout UI (Next.js)
- `apps/gateway` — API gateway + webhooks (Next.js, Node runtime)

## Quality gates
- Hooks: `git config core.hooksPath .githooks`
- Hooks skip when no Swift/Package changes; targets: pre-commit <5s, pre-push <15s
- CI: GitHub Actions on push/PR
