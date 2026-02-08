# Architecture

Vox = macOS voice-to-text app, layered Swift packages. Goal: keep core small, swap edges fast.

## Module Overview

```
                          VoxApp (executable)
                    ┌──────────────────────┐
                    │ main.swift            │
                    └──────────┬───────────┘
                               │
                     VoxAppKit (library)
 ┌─────────────────────────────────────────────────────────────────────┐
 │ AppDelegate • VoxSession • DictationPipeline • StatusBarController   │
 │ SettingsWindowController • PreferencesStore • ProcessingTab          │
 └─────────────────────────────────────────────────────────────────────┘
                ▲                         ▲
                │                         │
      VoxMac (OS integration)      VoxProviders (network + on-device)
 ┌──────────────────────────┐     ┌───────────────────────────────┐
 │ AudioRecorder            │     │ ElevenLabsClient (STT)         │
 │ AudioDeviceManager       │     │ DeepgramClient (STT)           │
 │ HotkeyMonitor            │     │ WhisperClient (STT)            │
 │ HUDController / HUDView  │     │ AppleSpeechClient (STT)        │
 │ ClipboardPaster          │     │ AudioConverter (CAF→WAV)       │
 │ KeychainHelper           │     │ OpenRouterClient (rewrite)     │
 │ PermissionManager        │     │ RewritePrompts                 │
 └──────────────────────────┘     └───────────────────────────────┘
                ▲                         ▲
                └──────────────┬──────────┘
                               │
                        VoxCore (foundation)
 ┌─────────────────────────────────────────────────────────────────────┐
 │ Protocols: STTProvider • RewriteProvider • TextPaster                │
 │ Decorators: TimeoutSTTProvider • RetryingSTTProvider                 │
 │             HealthAwareSTTProvider • ConcurrencyLimitedSTTProvider   │
 │             FallbackSTTProvider                                      │
 │ ProcessingLevel • RewriteQualityGate • Errors • MultipartFormData    │
 └─────────────────────────────────────────────────────────────────────┘
```

## STT Resilience Chain

Providers are wrapped in decorators. `HealthAwareSTTProvider` tracks rolling health and reorders attempts per request.

```text
                                 ConcurrencyLimit(8 default)
                                           │
                                           ▼
                                    FallbackSTTProvider
                                      primary │ fallback
                                              │
                                              └── Apple Speech (on-device, final fallback)
                                             
                                      HealthAwareSTTProvider(window: 20 attempts)
                                              │
                            dynamically ordered cloud-provider attempts
                                              │
      ElevenLabs(Timeout+Retry) • Deepgram(Timeout+Retry) • Whisper(Timeout+Retry)
```

Each decorator is a `STTProvider`:
- **TimeoutSTTProvider**: races transcription against a deadline
- **RetryingSTTProvider**: retries on `.isRetryable` errors with exponential backoff + jitter
- **HealthAwareSTTProvider**: tracks rolling success/latency/error-class metrics and reorders providers by health
- **ConcurrencyLimitedSTTProvider**: bounds in-flight STT requests and queues overflow
- **FallbackSTTProvider**: catches `.isFallbackEligible` errors and tries the next provider

Error classification is centralized in `STTError.isRetryable`, `STTError.isFallbackEligible`, and `STTError.isTransientForHealthScoring`.

## Data Flow (Dictation Pipeline)

1) User presses Option+Space
2) `HotkeyMonitor` fires → `VoxSession.toggleRecording()`
3) If a specific input device is selected, `AudioDeviceManager.setDefaultInputDevice()` applies it
4) `AudioRecorder` captures 16kHz/16-bit mono CAF audio
5) Health-aware STT router transcribes (dynamic order across configured providers, Apple Speech as final fallback)
6) Transcript → `OpenRouterClient` rewrite (if `ProcessingLevel` = light/aggressive)
7) `RewriteQualityGate` validates output length ratio
8) Result → `ClipboardPaster` → text insertion

## Input Device Selection

`AudioDeviceManager` (VoxMac) enumerates CoreAudio devices and manages the system default input. Uses stable `kAudioDevicePropertyDeviceUID` for persistence across reboots rather than volatile `AudioDeviceID`.

Behavior:
- **System Default** (nil): Vox records from whatever macOS has selected
- **Specific device**: set as system default before recording starts
- **Device unplugged**: silently falls back to current system default

Note: this changes the system-wide default. See [issue #136](https://github.com/misty-step/vox/issues/136) for future per-app AVAudioEngine approach.

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
- `TextPaster`: async main-actor text insertion

App wires concrete providers in `DictationPipeline`. Swap implementations without touching flow logic.

## Wrapper Integration Points

Vox is designed for composition. Wrappers should import Vox modules and add behavior through seams, not by forking `VoxSession` or `DictationPipeline`.

Primary seams:
- Decorate `STTProvider` / `RewriteProvider` for network policy, retries, and metering.
- Replace `PreferencesReading` and key providers for managed configuration.
- Implement `SessionExtension` to add:
  - authorization before recording starts
  - completion hooks with `DictationUsageEvent` metadata
  - failure hooks with sanitized reason codes

`SessionExtension` keeps a small interface while hiding session internals. The default implementation (`NoopSessionExtension`) preserves current OSS behavior.

## API Configuration

BYOK. `PreferencesStore` reads env first, then Keychain:
- `ELEVENLABS_API_KEY` — primary STT (ElevenLabs Scribe v2)
- `OPENROUTER_API_KEY` — rewriting
- `DEEPGRAM_API_KEY` — fallback STT (Deepgram Nova-3)
- `OPENAI_API_KEY` — fallback STT (Whisper)
- `VOX_MAX_CONCURRENT_STT` — optional global in-flight STT limit (default: `8`)

Endpoints:
- ElevenLabs STT: `https://api.elevenlabs.io/v1/speech-to-text`
- Deepgram STT: `https://api.deepgram.com/v1/listen?model=nova-3`
- OpenAI Whisper: `https://api.openai.com/v1/audio/transcriptions`
- OpenRouter chat: `https://openrouter.ai/api/v1/chat/completions`

Keychain storage in `KeychainHelper` (`com.vox.*` account keys).

## File Locations

| Area | Module | Files |
| --- | --- | --- |
| Entry point | VoxApp | `main.swift` |
| App lifecycle | VoxAppKit | `AppDelegate.swift`, `StatusBarController.swift`, `StatusBarIconRenderer.swift` |
| Session + pipeline | VoxAppKit | `VoxSession.swift`, `DictationPipeline.swift` |
| Settings | VoxAppKit | `PreferencesStore.swift`, `SettingsWindowController.swift`, `SettingsView.swift`, `ProcessingTab.swift`, `APIKeysTab.swift` |
| STT providers | VoxProviders | `ElevenLabsClient.swift`, `DeepgramClient.swift`, `WhisperClient.swift`, `AppleSpeechClient.swift` |
| STT decorators | VoxCore | `TimeoutSTTProvider.swift`, `RetryingSTTProvider.swift`, `HealthAwareSTTProvider.swift`, `ConcurrencyLimitedSTTProvider.swift`, `FallbackSTTProvider.swift` |
| Rewrite provider | VoxProviders | `OpenRouterClient.swift`, `RewritePrompts.swift` |
| Audio | VoxMac + VoxProviders | `AudioRecorder.swift`, `AudioDeviceManager.swift` (VoxMac), `AudioConverter.swift` (VoxProviders) |
| macOS integration | VoxMac | `HotkeyMonitor.swift`, `HUDController.swift`, `HUDView.swift`, `ClipboardPaster.swift`, `PermissionManager.swift`, `KeychainHelper.swift` |
| Core | VoxCore | `Protocols.swift`, `SessionExtension.swift`, `ProcessingLevel.swift`, `RewriteQualityGate.swift`, `Errors.swift`, `MultipartFormData.swift`, `BrandIdentity.swift` |

All paths under `Sources/{VoxApp,VoxAppKit,VoxCore,VoxMac,VoxProviders}/`.

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
- Speech Recognition: checked by `SFSpeechRecognizer.authorizationStatus()` before Apple Speech fallback; guarded against TCC crash for unbundled binaries
- Accessibility: required for paste; checked by `PermissionManager.isAccessibilityTrusted()` and prompted via `promptForAccessibilityIfNeeded()`

## Logging Convention

All modules log with bracket-prefixed tags to stdout:
- `[ElevenLabs]`, `[Deepgram]`, `[Whisper]`, `[AppleSpeech]` — provider-level request/response
- `[STT]` — decorator-level retries, fallback transitions
- `[Pipeline]` — processing stages
- `[Vox]` — session-level events
- `[Paster]` — clipboard and paste operations
