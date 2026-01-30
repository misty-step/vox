# Architecture

Vox = macOS voice-to-text app, layered Swift packages. Goal: keep core small, swap edges fast.

## Module Overview

```
                         VoxApp (top)
 ┌─────────────────────────────────────────────────────────────────────┐
 │ AppDelegate • VoxSession • DictationPipeline • StatusBarController   │
 │ SettingsWindowController • PreferencesStore                          │
 └─────────────────────────────────────────────────────────────────────┘
                ▲                         ▲
                │                         │
      VoxMac (OS integration)      VoxProviders (network)
 ┌──────────────────────────┐     ┌───────────────────────────────┐
 │ AudioRecorder            │     │ ElevenLabsClient (STT)         │
 │ HotkeyMonitor            │     │ OpenRouterClient (rewrite)     │
 │ HUDController            │     │ RewritePrompts                 │
 │ ClipboardPaster          │     └───────────────────────────────┘
 │ KeychainHelper           │
 │ PermissionManager        │
 └──────────────────────────┘
                ▲                         ▲
                └──────────────┬──────────┘
                               │
                        VoxCore (foundation)
 ┌─────────────────────────────────────────────────────────────────────┐
 │ Protocols: STTProvider • RewriteProvider • TextPaster                │
 │ ProcessingLevel • RewriteQualityGate • Errors • MultipartFormData    │
 └─────────────────────────────────────────────────────────────────────┘
```

## Data Flow (Dictation Pipeline)

1) User presses Option+Space  
2) `HotkeyMonitor` fires → `VoxSession.toggleRecording()`  
3) `AudioRecorder` captures CAF audio  
4) `ElevenLabsClient` transcribes  
5) Transcript → `OpenRouterClient` rewrite (if `ProcessingLevel` = light/aggressive)  
6) `RewriteQualityGate` validates output length ratio  
7) Result → `ClipboardPaster` → text insertion

## State Machine

```
 idle ── start ──▶ recording ── stop ──▶ processing ── done ──▶ idle
        ▲                                      │
        └────────────── error/permission ──────┘
```

## Protocol Architecture

`VoxCore/Protocols.swift` defines core contracts:
- `STTProvider`: async transcription from audio URL
- `RewriteProvider`: async rewrite with prompt + model
- `TextPaster`: main-actor text insertion

App wires concrete providers in `DictationPipeline`. Swap implementations without touching flow logic.

## Extension Points for Vox Pro

From `vision.md`: “Vox is the engine; future Vox Pro wrapper adds auth/billing/sync.”  
Design supports composition, not fork.

Injection points:
- Wrap providers (STT / rewrite) with decorators
- Replace `PreferencesStore` for remote config
- Replace `KeychainHelper` for managed secrets

Recommended wrapper pattern:

```swift
public final class MeteredRewriteProvider: RewriteProvider {
    private let base: RewriteProvider
    private let onUsage: (Int) -> Void

    public init(base: RewriteProvider, onUsage: @escaping (Int) -> Void) {
        self.base = base
        self.onUsage = onUsage
    }

    public func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        let output = try await base.rewrite(transcript: transcript, systemPrompt: systemPrompt, model: model)
        onUsage(output.count)
        return output
    }
}
```

## API Configuration

BYOK. `PreferencesStore` reads env first, then Keychain:
- `ELEVENLABS_API_KEY`
- `OPENROUTER_API_KEY`

Endpoints:
- ElevenLabs STT: `https://api.elevenlabs.io/v1/speech-to-text`
- OpenRouter chat: `https://openrouter.ai/api/v1/chat/completions`

Keychain storage in `KeychainHelper` (`com.vox.*` account keys).

## File Locations

| Area | Role | Files |
| --- | --- | --- |
| App entry | App lifecycle, hotkey, status bar | `Sources/VoxApp/AppDelegate.swift`, `Sources/VoxApp/StatusBarController.swift` |
| Session + pipeline | State machine, dictation flow | `Sources/VoxApp/VoxSession.swift`, `Sources/VoxApp/DictationPipeline.swift` |
| Settings | Preferences + UI | `Sources/VoxApp/Settings/PreferencesStore.swift`, `Sources/VoxApp/SettingsWindowController.swift`, `Sources/VoxApp/Settings/SettingsView.swift` |
| Providers | STT + rewrite | `Sources/VoxProviders/ElevenLabsClient.swift`, `Sources/VoxProviders/OpenRouterClient.swift`, `Sources/VoxProviders/RewritePrompts.swift` |
| macOS integration | Audio, hotkey, HUD, paste, permissions | `Sources/VoxMac/AudioRecorder.swift`, `Sources/VoxMac/HotkeyMonitor.swift`, `Sources/VoxMac/HUDController.swift`, `Sources/VoxMac/ClipboardPaster.swift`, `Sources/VoxMac/PermissionManager.swift`, `Sources/VoxMac/KeychainHelper.swift` |
| Core | Protocols + shared types | `Sources/VoxCore/Protocols.swift`, `Sources/VoxCore/ProcessingLevel.swift`, `Sources/VoxCore/RewriteQualityGate.swift`, `Sources/VoxCore/Errors.swift`, `Sources/VoxCore/MultipartFormData.swift` |

## Quality Gate

`RewriteQualityGate` compares trimmed character count ratio:

```
ratio = candidate.count / max(raw.count, 1)
```

Minimum ratios:
- `off`: 0 (rewrite skipped)
- `light`: 0.6
- `aggressive`: 0.3

If below min, pipeline falls back to raw transcript.

## macOS Permissions

- Microphone: requested by `PermissionManager.requestMicrophoneAccess()` before recording
- Accessibility: required for paste; checked by `PermissionManager.isAccessibilityTrusted()` and prompted via `promptForAccessibilityIfNeeded()`
