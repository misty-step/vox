# Vox

**Voice-to-text for macOS. Speak naturally — get polished text.**

Option+Space to record. Auto-pastes into any app. No configuration maze.

---

<!-- Demo: ~30s GIF showing Option+Space → recording HUD → text pasted -->
<!-- Add demo.gif here once captured: ![Vox demo](docs/assets/demo.gif) -->

---

## Quick Start

```bash
git clone https://github.com/misty-step/vox.git
cd vox
cp .env.example .env.local   # add your API keys
swift build
./scripts/run.sh
```

Grant Accessibility permission when prompted. Press **Option+Space** to dictate.

Recommended: one [ElevenLabs](https://elevenlabs.io) key (STT) and one [Gemini](https://ai.google.dev/) key (rewrites) for best quality. Apple Speech available on-device as no-key fallback.

---

## Why Vox

| | Vox | SuperWhisper | macOS Dictation |
|---|---|---|---|
| AI rewriting (Clean/Polish) | ✅ | ✅ | ❌ |
| Open source / BYOK | ✅ | ❌ (subscription) | ❌ |
| Resilient STT fallback chain | ✅ | ❌ | ❌ |
| On-device fallback (no key) | ✅ | ❌ | ✅ |
| Minimal footprint (menu bar) | ✅ | ✅ | ❌ |
| Configuration maze | ❌ | ⚠️ | ❌ |

BYOK = bring your own API keys. You pay providers directly, not a middleman.

---

## Features

- **Option+Space** to start/stop recording (global hotkey)
- **Three processing levels** — Raw (verbatim), Clean (tidy), Polish (full rewrite)
- **Resilient STT chain** — ElevenLabs → Deepgram → Apple Speech; opt-in hedged routing via `VOX_STT_ROUTING=hedged`
- **Streaming transcription** — Deepgram WebSocket for real-time results (enabled by default)
- **Auto-paste** directly into the focused application
- **Microphone selection** from Settings
- **Recovery actions** — Copy Last Raw Transcript, Retry Last Rewrite
- **Accessibility-first HUD** — VoiceOver labels + state announcements
- **Exportable diagnostics bundle** — privacy-safe (no transcript text, no audio, no keys)
- **Secure key storage** via macOS Keychain

---

## Setup

### Prerequisites

- macOS 14 (Sonoma) or later
- Swift 5.9+
- API keys: [ElevenLabs](https://elevenlabs.io) (STT) + [Gemini](https://ai.google.dev/) (rewrites)
- Optional: [Deepgram](https://console.deepgram.com) (streaming STT + fallback), [OpenRouter](https://openrouter.ai) (rewrite fallback)
- [SwiftLint](https://github.com/realm/SwiftLint) for development (`brew install swiftlint`)

### Configuration

**`.env.local`** (development):
```bash
ELEVENLABS_API_KEY=your-key
GEMINI_API_KEY=your-key
DEEPGRAM_API_KEY=your-key           # optional, enables streaming STT
OPENROUTER_API_KEY=your-key         # optional, rewrite fallback
```

**Settings window** (persistent): click the menu bar icon → Settings. Keys stored in Keychain.

Advanced env overrides — add to `.env.local` (loaded by `run.sh`) or inline-prefix the command:
```bash
VOX_MAX_CONCURRENT_STT=8            # global STT in-flight cap (default 8)
VOX_DISABLE_STREAMING_STT=1         # force batch-only transcription
VOX_STT_ROUTING=hedged              # parallel cloud race w/ stagger delays
VOX_AUDIO_BACKEND=recorder          # legacy file-only audio backend
VOX_PERF_INGEST_URL=https://...     # pipeline timing upload endpoint
```

Example: `VOX_DISABLE_STREAMING_STT=1 ./scripts/run.sh`

### Permissions

Vox requires Accessibility access to paste text. macOS prompts on first launch. If missed:

> System Settings → Privacy & Security → Accessibility → Enable Vox

---

## Development

```bash
swift build                                  # debug build
swift build -c release                       # release build
swift test                                   # run all tests
./scripts/run-tests-ci.sh                    # CI-equivalent (strict + timeout)
./scripts/test-audio-guardrails.sh           # audio regression contract tests
./scripts/lint.sh                            # SwiftLint
./scripts/run.sh                             # launch with .env.local keys
```

### Project Structure

```text
Sources/
  VoxCore/       # Protocols, errors, decorators (no dependencies)
  VoxProviders/  # STT/rewrite clients (ElevenLabs, Deepgram, Apple, Gemini, OpenRouter)
  VoxMac/        # macOS: audio, Keychain, HUD, hotkeys
  VoxAppKit/     # Session, pipeline, settings, UI (testable library)
  VoxApp/        # Entry point (main.swift only)
```

See [docs/CODEBASE_MAP.md](docs/CODEBASE_MAP.md) for detailed navigation.

### Releases

Vox uses [Landfall](https://github.com/misty-step/landfall) for automated releases — conventional commits (`feat:`, `fix:`) on `master` trigger version bumps and GitHub releases automatically.

For signed + notarized distribution:
```bash
export VOX_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export VOX_NOTARY_PROFILE="vox-notary"
./scripts/release-macos.sh
```

See `docs/RELEASE.md` for full certificate and CI setup.

---

## Contributing

Fork, branch, submit PR. Quick check:

```bash
./scripts/lint.sh && swift build -Xswiftc -warnings-as-errors && ./scripts/run-tests-ci.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for code style, PR guidelines, and branch naming.

---

## Docs

- [Architecture](docs/ARCHITECTURE.md)
- [ADRs](docs/adr/)
- [Codebase Map](docs/CODEBASE_MAP.md)
- [Postmortems](docs/postmortems/)

## Product

- **Version**: shown in Settings footer (release build via Info.plist)
- **Attribution**: Vox by [Misty Step](https://github.com/misty-step)
- **Support**: [open an issue](https://github.com/misty-step/vox/issues)

## Library Use

`VoxCore`, `VoxProviders`, `VoxMac`, and `VoxAppKit` are published as SwiftPM library products. See [Wrapper Integration Points](docs/ARCHITECTURE.md#wrapper-integration-points).

## License

MIT
