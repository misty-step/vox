# Vox

Voice-to-text for macOS with optional AI polish.

## Why

Dictation apps either give you raw transcripts (unusable for professional writing) or lock refinement behind complex settings and subscriptions. Vox takes a different approach: speak naturally, get polished text. No configuration maze, no learning curve.

SuperWhisper alternative that's simpler and smarter.

## Features

- **Press Option+Space** to start/stop recording
- **STT resilience**: sequential fallback (ElevenLabs → Deepgram → Whisper → Apple Speech); opt-in hedged routing via `VOX_STT_ROUTING=hedged`
- **Proactive STT concurrency limiter**: queues requests before provider caps (`VOX_MAX_CONCURRENT_STT`, default `8`)
- **Three processing levels**: Raw (verbatim transcript), Clean (tidy up), Polish (full rewrite)
- **Microphone selection**: choose input device from Settings
- **Auto-paste** directly into any application
- **Menu bar app** with minimal footprint
- **State-aware visual identity**: consistent menu icon + HUD language for ready/recording/processing
- **VoiceOver-aware HUD**: accessibility labels/values + state announcements for recording transitions
- **BYOK** (Bring Your Own Keys) for complete control over costs
- **Secure storage** via macOS Keychain

## Quick Start

```bash
# Clone and build
git clone https://github.com/misty-step/vox.git
cd vox
swift build

# Configure keys
cp .env.example .env.local
# edit .env.local
# (or configure in Settings after launch)

# Run
./scripts/run.sh
```

Grant Accessibility permissions when prompted. Press Option+Space to dictate.

## Setup

### Prerequisites

- macOS 14 (Sonoma) or later
- Swift 5.9+
- [SwiftLint](https://github.com/realm/SwiftLint) (development only, `brew install swiftlint`)
- [ElevenLabs API key](https://elevenlabs.io) for primary transcription
- [Gemini API key](https://ai.google.dev/) for AI rewriting
- [OpenRouter API key](https://openrouter.ai) (optional) for rewrite fallback
- [Deepgram API key](https://console.deepgram.com) (optional) for fallback transcription and streaming STT
- [OpenAI API key](https://platform.openai.com) (optional) for Whisper fallback transcription
- Apple Speech is always available as an on-device fallback (no key needed)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/misty-step/vox.git
   cd vox
   ```

2. Build the app:
   ```bash
   swift build -c release
   ```

3. Run:
   ```bash
   .build/release/Vox
   ```

### Signed Distribution (Maintainers)

For a signed + notarized `Vox.app` distribution artifact:

```bash
export VOX_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export VOX_NOTARY_PROFILE="vox-notary"
./scripts/release-macos.sh
```

**Automated Releases:** Vox uses [Landfall](https://github.com/misty-step/landfall) for automated versioning and releases. When PRs merge to `master` with conventional commits (`feat:`, `fix:`, etc.), Landfall automatically bumps the version, updates the changelog, and creates GitHub releases.

See `docs/RELEASE.md` for full setup (certificate, notary credentials, CI secrets) and `CONTRIBUTING.md` for release workflow details.

### Configuration

API keys can be provided two ways:

**Environment variables** (recommended for development):
```bash
export ELEVENLABS_API_KEY=your-key
export GEMINI_API_KEY=your-key
export OPENROUTER_API_KEY=your-key         # optional rewrite fallback
export DEEPGRAM_API_KEY=your-key           # optional STT fallback + streaming
export OPENAI_API_KEY=your-key             # optional Whisper fallback
export VOX_MAX_CONCURRENT_STT=8            # optional global STT in-flight limit
export VOX_DISABLE_STREAMING_STT=1         # optional: disable streaming STT path
export VOX_STT_ROUTING=hedged              # optional: parallel race w stagger delays
export VOX_AUDIO_BACKEND=recorder          # optional: legacy file-only audio backend
```

**Settings window** (persisted in Keychain):
Click the menu bar icon and select Settings. Keys stored securely in macOS Keychain.

### Permissions

Vox requires Accessibility permissions to paste text into applications. macOS will prompt on first launch. If denied, enable manually:

System Settings > Privacy & Security > Accessibility > Enable Vox

## Development

```bash
# Build debug
swift build

# Build release
swift build -c release

# Build signed + notarized release app bundle (maintainers)
./scripts/release-macos.sh

# Lint
./scripts/lint.sh

# CI-equivalent strict tests with hang timeout
./scripts/run-tests-ci.sh

# Run (loads .env.local)
./scripts/run.sh
```

### Project Structure

```
Sources/
  VoxCore/       # Protocols, errors, decorators (timeout/retry/concurrency/routing/health-aware)
  VoxProviders/  # STT clients (ElevenLabs, Deepgram, Whisper, Apple Speech), OpenRouter rewriting
  VoxMac/        # macOS-specific: audio recording, device selection, Keychain, HUD, hotkeys
  VoxAppKit/     # Session, pipeline, settings, UI controllers (testable library)
  VoxApp/        # Executable entry point (just main.swift)
```

### Rewrite Models

Default rewrite model (Clean/Polish): `gemini-2.5-flash-lite` (Gemini direct) / `google/gemini-2.5-flash-lite` (OpenRouter)

See `docs/MODEL_EVALUATION.md` and `evals/polish-bakeoff.yaml` for bakeoff candidates and selection notes.

## Product Standards

- **Version/build in-app**: shown in Settings footer (release build via Info.plist; dev can set `VOX_APP_VERSION`/`VOX_BUILD_NUMBER`).
- **Attribution**: Vox by Misty Step.
- **Contact/help**: open a support issue at https://github.com/misty-step/vox/issues.

## Contributing

Contributions welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for dev setup, code style, and PR guidelines.

Quick version: fork, branch, `./scripts/lint.sh && swift build -Xswiftc -warnings-as-errors && ./scripts/run-tests-ci.sh`, submit PR.

## Use as a Library

Vox publishes `VoxCore`, `VoxProviders`, `VoxMac`, and `VoxAppKit` as SwiftPM library products. See [Wrapper Integration Points](docs/ARCHITECTURE.md#wrapper-integration-points) for dependency setup and extension seams.

## Docs

- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- ADRs: [docs/adr/](docs/adr/)
- Postmortems: [docs/postmortems/](docs/postmortems/)

## License

MIT
