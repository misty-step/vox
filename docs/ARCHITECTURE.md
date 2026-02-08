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
 │             HedgedSTTProvider • ConcurrencyLimitedSTTProvider        │
 │             HealthAwareSTTProvider • FallbackSTTProvider             │
 │ ProcessingLevel • RewriteQualityGate • Errors • MultipartFormData    │
 └─────────────────────────────────────────────────────────────────────┘
```

## STT Resilience Chain

Providers are wrapped in decorators. The default runtime path uses `HedgedSTTProvider` for staggered parallel launch.

```text
                                 ConcurrencyLimit(8 default)
                                           │
                                           ▼
                                 HedgedSTTProvider
                                            │
      Apple Speech(0s) • ElevenLabs(0s Timeout+Retry) • Deepgram(5s Timeout+Retry) • Whisper(10s Timeout+Retry)
```

Each decorator is a `STTProvider`:
- **TimeoutSTTProvider**: races transcription against a deadline
- **RetryingSTTProvider**: retries on `.isRetryable` errors with exponential backoff + jitter
- **HedgedSTTProvider**: launches providers with stagger delays and returns first success
- **ConcurrencyLimitedSTTProvider**: bounds in-flight STT requests and queues overflow
- **HealthAwareSTTProvider / FallbackSTTProvider**: retained for alternative routing strategies and tests

Error classification is centralized in `STTError.isRetryable`, `STTError.isFallbackEligible`, and `STTError.isTransientForHealthScoring`.

## Data Flow (Dictation Pipeline)

1) User presses Option+Space
2) `HotkeyMonitor` fires → `VoxSession.toggleRecording()`
3) `VoxSession` applies selected input as system default (compatibility path), then `AudioRecorder` starts `AVAudioEngine` capture
4) `AudioRecorder` captures 16kHz/16-bit mono CAF audio via `AVAudioEngine` tap + format conversion
5) Hedged STT router transcribes (Apple Speech + staggered cloud hedges)
6) Transcript → `OpenRouterClient` rewrite (if `ProcessingLevel` = light/aggressive)
7) `RewriteQualityGate` validates output length ratio
8) Result → `ClipboardPaster` → text insertion

## Audio Conversion Integrity Contract

`AudioRecorder` owns hardware-to-upload normalization (`AVAudioEngine` input format → 16kHz/16-bit mono CAF). This module has one non-negotiable contract: **preserve spoken duration across sample-rate and device differences**.

Runtime invariants:
- **Drain per tap**: each input tap must drain `AVAudioConverter` output until status is no longer `.haveData`.
- **Dynamic capacity**: output buffer capacity is derived from `inputFrames * (outputRate / inputRate)` with a 100ms minimum floor.
- **Drain on stop**: flush uses repeated `.endOfStream` conversion calls until converter output is exhausted.
- **Underflow guard**: recorder logs a one-time warning if per-tap output ratio drops below expected threshold (currently `0.85`).

Test invariants:
- `AudioRecorderConversionTests` validates duration preservation for common input rates (`16k`, `24k`, `44.1k`, `48k`).
- Regression fixture explicitly checks the old truncation failure shape (`4096 @ 24k` incorrectly capped to `1600` output frames) is detected as unhealthy.

## Input Device Selection

`AudioDeviceManager` (VoxMac) enumerates CoreAudio devices and resolves stable `kAudioDevicePropertyDeviceUID` to runtime `AudioDeviceID`.

Default behavior prioritizes reliability:
- `VoxSession` sets the selected input as macOS default before recording starts.
- `AudioRecorder` captures from the default route using `AVAudioEngine`.

Optional per-app routing is available for experiments only:
- set `VOX_ENABLE_PER_APP_AUDIO_ROUTING=1` to attempt `kAudioOutputUnitProperty_CurrentDevice` on the input `AudioUnit`.
- if per-app routing is unavailable/fails, capture continues on the default route.

Behavior:
- **System Default** (nil UID): `AVAudioEngine` uses whatever macOS has selected
- **Specific device**: Vox sets system default input to the selected UID before capture
- **Device unplugged**: silently falls back to current system default
- **Optional per-app mode**: guarded by `VOX_ENABLE_PER_APP_AUDIO_ROUTING=1`

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
- `DEEPGRAM_API_KEY` — hedged cloud STT (Deepgram Nova-3, launches at 5s)
- `OPENAI_API_KEY` — hedged cloud STT (Whisper, launches at 10s)
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
| STT decorators | VoxCore | `TimeoutSTTProvider.swift`, `RetryingSTTProvider.swift`, `HedgedSTTProvider.swift`, `ConcurrencyLimitedSTTProvider.swift`, `HealthAwareSTTProvider.swift`, `FallbackSTTProvider.swift` |
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
- `[STT]` — decorator-level retries, hedge launches, winner/failure transitions
- `[Pipeline]` — processing stages
- `[Vox]` — session-level events
- `[Paster]` — clipboard and paste operations
