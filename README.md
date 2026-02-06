# Vox

Voice-to-text for macOS with optional AI polish.

## Why

Dictation apps either give you raw transcripts (unusable for professional writing) or lock refinement behind complex settings and subscriptions. Vox takes a different approach: speak naturally, get polished text. No configuration maze, no learning curve.

SuperWhisper alternative that's simpler and smarter.

## Features

- **Press Option+Space** to start/stop recording
- **Resilient STT chain**: ElevenLabs → Deepgram → Whisper → Apple Speech (on-device fallback)
- **Three processing levels**: Off (raw transcript), Light (cleanup), Aggressive (full rewrite)
- **Microphone selection**: choose input device from Settings
- **Auto-paste** directly into any application
- **Menu bar app** with minimal footprint
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
- [ElevenLabs API key](https://elevenlabs.io) for primary transcription
- [OpenRouter API key](https://openrouter.ai) for AI rewriting
- [Deepgram API key](https://console.deepgram.com) (optional) for fallback transcription
- [OpenAI API key](https://platform.openai.com) (optional) for Whisper fallback transcription
- Apple Speech is always available as a final on-device fallback (no key needed)

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

### Configuration

API keys can be provided two ways:

**Environment variables** (recommended for development):
```bash
export ELEVENLABS_API_KEY=your-key
export OPENROUTER_API_KEY=your-key
export DEEPGRAM_API_KEY=your-key  # optional fallback
export OPENAI_API_KEY=your-key    # optional Whisper fallback
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

# Run with verbose output
swift run Vox
```

### Project Structure

```
Sources/
  VoxCore/       # Protocols, errors, decorators (retry/fallback/timeout)
  VoxProviders/  # STT clients (ElevenLabs, Deepgram, Whisper, Apple Speech), OpenRouter rewriting
  VoxMac/        # macOS-specific: audio recording, device selection, Keychain, HUD, hotkeys
  VoxApp/        # Main executable, UI, pipeline orchestration, settings
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

Contributions welcome. Please:

1. Fork the repository
2. Create a feature branch
3. Enable the pre-push hook: `git config core.hooksPath .githooks`
4. Make your changes
5. Run `swift build -Xswiftc -warnings-as-errors` to verify
6. Submit a pull request

The pre-push hook runs a warnings-as-errors build before each push. CI enforces the same check.

Keep changes focused and minimal. Match existing code style.

## License

MIT
