# Vox

Voice-to-text for macOS with optional AI polish.

## Why

Dictation apps either give you raw transcripts (unusable for professional writing) or lock refinement behind complex settings and subscriptions. Vox takes a different approach: speak naturally, get polished text. No configuration maze, no learning curve.

SuperWhisper alternative that's simpler and smarter.

## Features

- **Press Option+Space** to start/stop recording
- **Hedged STT racing**: Apple Speech + cloud providers run in a staggered race (ElevenLabs `0s`, Deepgram `5s`, Whisper `10s`)
- **Proactive STT concurrency limiter**: queues requests before provider caps (`VOX_MAX_CONCURRENT_STT`, default `8`)
- **Three processing levels**: Off (raw transcript), Light (cleanup), Aggressive (full rewrite)
- **Microphone selection**: choose input device from Settings
- **Auto-paste** directly into any application
- **Menu bar app** with minimal footprint
- **State-aware visual identity**: consistent menu icon + HUD language for ready/recording/processing
- **BYOK** (Bring Your Own Keys) for complete control over costs
- **Secure storage** via macOS Keychain

## Quick Start

```bash
# Clone and build
git clone https://github.com/misty-step/vox.git
cd vox
swift build

# Set API keys (or configure in Settings after launch)
export ELEVENLABS_API_KEY=your-key
export OPENROUTER_API_KEY=your-key

# Run
swift run Vox
```

Grant Accessibility permissions when prompted. Press Option+Space to dictate.

## Setup

### Prerequisites

- macOS 14 (Sonoma) or later
- Swift 5.9+
- [SwiftLint](https://github.com/realm/SwiftLint) (development only, `brew install swiftlint`)
- [ElevenLabs API key](https://elevenlabs.io) for primary transcription
- [OpenRouter API key](https://openrouter.ai) for AI rewriting
- [Deepgram API key](https://console.deepgram.com) (optional) for hedged cloud transcription
- [OpenAI API key](https://platform.openai.com) (optional) for Whisper hedged cloud transcription
- Apple Speech is always available and launches at hedge start (no key needed)

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

See `docs/RELEASE.md` for full setup (certificate, notary credentials, CI secrets).

### Configuration

API keys can be provided two ways:

**Environment variables** (recommended for development):
```bash
export ELEVENLABS_API_KEY=your-key
export OPENROUTER_API_KEY=your-key
export DEEPGRAM_API_KEY=your-key  # optional fallback
export OPENAI_API_KEY=your-key    # optional Whisper fallback
export VOX_MAX_CONCURRENT_STT=8   # optional global STT in-flight limit
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

# Run with verbose output
swift run Vox
```

### Project Structure

```
Sources/
  VoxCore/       # Protocols, errors, decorators (timeout/retry/concurrency/hedged racing/health-aware)
  VoxProviders/  # STT clients (ElevenLabs, Deepgram, Whisper, Apple Speech), OpenRouter rewriting
  VoxMac/        # macOS-specific: audio recording, device selection, Keychain, HUD, hotkeys
  VoxAppKit/     # Session, pipeline, settings, UI controllers (testable library)
  VoxApp/        # Executable entry point (just main.swift)
```

### Supported Models

Default model: `google/gemini-2.5-flash-lite`

Available via OpenRouter:
- google/gemini-2.5-flash-lite
- xiaomi/mimo-v2-flash
- deepseek/deepseek-v3.2
- google/gemini-2.5-flash
- moonshotai/kimi-k2.5
- google/gemini-3-flash-preview

## Contributing

Contributions welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for dev setup, code style, and PR guidelines.

Quick version: fork, branch, `./scripts/lint.sh && swift build -Xswiftc -warnings-as-errors && swift test -Xswiftc -warnings-as-errors`, submit PR.

## License

MIT
