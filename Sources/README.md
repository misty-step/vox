# Sources

Swift package containing the Vox macOS dictation app.

## Module Structure

```
Sources/
├── VoxApp/          # App wiring + orchestration
├── VoxCore/         # Contracts, errors, utilities
├── VoxMac/          # macOS integration
└── VoxProviders/    # Provider adapters (pure, no UI)
```

## VoxApp

Application entry point and orchestration layer.

| Component | Purpose |
|-----------|---------|
| `SessionController` | Hotkey toggle, state machine, UI signals |
| `DictationPipeline` | STT → rewrite pipeline, returns final text |
| `ProviderFactory` | Creates STT/rewrite providers from config |
| `AppConfig` | Configuration loading and validation |

## VoxCore

Shared contracts and utilities. No dependencies on macOS or external APIs.

| Component | Purpose |
|-----------|---------|
| `STTProvider` | Protocol for speech-to-text providers |
| `RewriteProvider` | Protocol for LLM rewrite providers |
| `ProcessingLevel` | Enum: `off`, `light`, `aggressive` |
| `VoxError`, `RewriteError`, `STTError` | Typed errors |

## VoxMac

macOS-specific integration. Depends on AppKit, AVFoundation.

| Component | Purpose |
|-----------|---------|
| `AudioRecorder` | Microphone capture |
| `ClipboardPaster` | Paste via Cmd+V simulation |
| `HUDController` | Status overlay UI |
| `HotkeyMonitor` | Global hotkey registration |
| `PermissionManager` | Accessibility/microphone permissions |

## VoxProviders

Pure provider adapters. No UI logic, no state.

| Provider | Service |
|----------|---------|
| `ElevenLabsSTTProvider` | ElevenLabs speech-to-text API |
| `GeminiRewriteProvider` | Google Gemini rewrite API |
| `OpenRouterRewriteProvider` | OpenRouter rewrite API |

## Commands

```bash
swift build              # Compile all targets
swift test               # Run unit tests
swift run VoxApp         # Build and run the app
```

## Dependency Flow

```
VoxApp → VoxCore, VoxMac, VoxProviders
VoxMac → VoxCore
VoxProviders → VoxCore
VoxCore → (none)
```
