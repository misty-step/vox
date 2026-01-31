# Vox

Voice-to-text for macOS with optional AI polish.

## Why

Dictation apps either give you raw transcripts (unusable for professional writing) or lock refinement behind complex settings and subscriptions. Vox takes a different approach: speak naturally, get polished text. No configuration maze, no learning curve.

SuperWhisper alternative that's simpler and smarter.

## Features

- **Press Option+Space** to start/stop recording
- **Three processing levels**: Off (raw transcript), Light (cleanup), Aggressive (full rewrite)
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
- [ElevenLabs API key](https://elevenlabs.io) for transcription
- [OpenRouter API key](https://openrouter.ai) for AI rewriting

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
  VoxCore/       # Protocols, errors, shared types
  VoxProviders/  # ElevenLabs STT, OpenRouter rewriting
  VoxMac/        # macOS-specific: Keychain, HUD, hotkeys, permissions
  VoxApp/        # Main executable, UI, pipeline orchestration
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
3. Make your changes
4. Run `swift build` to verify compilation
5. Submit a pull request

Keep changes focused and minimal. Match existing code style.

## License

MIT
