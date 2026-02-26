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
 │ SettingsWindowController • PreferencesStore • SettingsView           │
 └─────────────────────────────────────────────────────────────────────┘
                ▲                         ▲
                │                         │
      VoxMac (OS integration)      VoxProviders (network + on-device)
 ┌──────────────────────────┐     ┌───────────────────────────────┐
│ AudioRecorder            │     │ ElevenLabsClient (STT)         │
│ AudioDeviceManager       │     │ DeepgramClient (STT)           │
│                          │     │ DeepgramStreamingClient (STT)  │
│ HotkeyMonitor            │     │ AppleSpeechClient (STT)        │
 │ HUDController / HUDView  │     │ AudioConverter (CAF→WAV)       │
 │ ClipboardPaster          │     │ GeminiClient (rewrite)         │
 │ KeychainHelper           │     │ OpenRouterClient (rewrite)     │
 │ PermissionManager        │     │ RewritePrompts                 │
 │                          │     │                               │
 └──────────────────────────┘     └───────────────────────────────┘
                ▲                         ▲
                └──────────────┬──────────┘
                               │
                        VoxCore (foundation)
 ┌─────────────────────────────────────────────────────────────────────┐
 │ Protocols: STTProvider • StreamingSTTProvider • RewriteProvider        │
 │            TextPaster • AudioRecording • AudioChunkStreaming           │
 │            DictationProcessing • TranscriptProcessing • PreferencesReading │
 │            HUDDisplaying                                                │
 │ Decorators: TimeoutSTTProvider • RetryingSTTProvider                 │
 │             HedgedSTTProvider • ConcurrencyLimitedSTTProvider        │
 │             HealthAwareSTTProvider • FallbackSTTProvider             │
 │ ProcessingLevel • RewriteQualityGate • Errors • MultipartFormData    │
 └─────────────────────────────────────────────────────────────────────┘
```

## STT Resilience Chain

Providers are wrapped in decorators.

Default routing: sequential primary → fallback → Apple Speech safety net.

```text
                         ConcurrencyLimit(8 default)
                                   │
                                   ▼
                     Sequential FallbackSTTProvider chain
                                   │
      ElevenLabs(Timeout+Retry) → Deepgram(Timeout+Retry) → Apple Speech
```

Opt-in hedged routing: `VOX_STT_ROUTING=hedged` runs a staggered parallel race.

```text
                                 ConcurrencyLimit(8 default)
                                           │
                                           ▼
                                 HedgedSTTProvider
                                            │
      Apple Speech(0s) • ElevenLabs(0s Timeout+Retry) • Deepgram(5s Timeout+Retry)
```

Each decorator is a `STTProvider`:
- **TimeoutSTTProvider**: races transcription against a dynamic deadline (`max(baseTimeout, baseTimeout + fileSizeMB * secondsPerMB)`); current cloud wiring uses `baseTimeout: 30`, `secondsPerMB: 2`
- **RetryingSTTProvider**: retries on `.isRetryable` errors with exponential backoff + jitter
- **FallbackSTTProvider**: sequential primary → fallback on eligible errors
- **HedgedSTTProvider**: launches providers with stagger delays and returns first success (opt-in)
- **ConcurrencyLimitedSTTProvider**: bounds in-flight STT requests and queues overflow
- **HealthAwareSTTProvider**: retained for adaptive routing strategies and tests

Error classification is centralized in `STTError.isRetryable`, `STTError.isFallbackEligible`, and `STTError.isTransientForHealthScoring`.

## Data Flow (Dictation Pipeline)

1) User presses Option+Space
2) `HotkeyMonitor` fires → `VoxSession.toggleRecording()`
3) `VoxSession` applies selected input as system default (compatibility path), then `AudioRecorder` starts capture
4) `AudioRecorder` records 16kHz/16-bit mono CAF via `AVAudioEngine` (default backend) and emits PCM chunks when available
5) If streaming STT is available (ElevenLabs preferred; Deepgram fallback) and not disabled (`VOX_DISABLE_STREAMING_STT`), `VoxSession` forwards PCM chunks to a `StreamingSTTSession`
6) On stop, `VoxSession` attempts streaming `finish()` with two-layer timeout: provider-level (scaled by streamed audio duration, recovers partial transcripts) and session-level safety net (90s default, catches transport-level hangs like stuck WebSocket drains)
7) If streaming is unavailable, setup fails, or finalize fails/times out, fallback to batch STT router (default sequential; opt-in `VOX_STT_ROUTING=hedged`)
8) Transcript → rewrite (Gemini, fallback OpenRouter) when `ProcessingLevel` = clean/polish
9) `RewriteQualityGate` scores rewrite similarity (benchmarks/debug)
10) Result → `ClipboardPaster` → text insertion

Before STT, `DictationPipeline` delegates payload validation to `CapturedAudioInspector` and fails fast with `VoxError.emptyCapture` when decoded frame count is zero.

## Diagnostics

Vox records structured, privacy-safe diagnostics events to `~/Library/Application Support/Vox/Diagnostics/` as JSONL:

- `diagnostics-current.jsonl` (append-only), rotated to `diagnostics-<timestamp>-<id>.jsonl`
- Export via menu bar: "Export Diagnostics…" creates a zip containing `context.json` + recent log files (copies path to clipboard)
- Logs never include transcript text or API keys (counts/booleans/timings only)
- Optional: set `VOX_PERF_INGEST_URL` to upload `pipeline_timing` events as NDJSON (disabled by default)

## Audio Capture Contract

`AudioRecorder` has two backends with reliability-first defaults:

- **Default (`AVAudioEngine`)**: 16kHz/16-bit mono CAF capture with real-time audio chunk emission for streaming STT.
- **Legacy opt-out (`AVAudioRecorder`)**: enabled with `VOX_AUDIO_BACKEND=recorder`; direct file-based capture without streaming support.

Non-negotiable contract: **recorded speech duration and frame payload must survive capture and conversion across device/sample-rate differences**.

Runtime invariants:
- **Payload guard**: pipeline validates capture payload via `CapturedAudioInspector` before STT (fast failure over silent empty transcripts).
- **Encoded payload guard**: when Opus conversion returns an empty file, pipeline falls back to original CAF before STT.
- **Engine drain per tap**: each input tap drains `AVAudioConverter` output until status is no longer `.haveData`.
- **Engine dynamic capacity**: output buffer capacity uses `inputFrames * (outputRate / inputRate)` with a 100ms floor.
- **Engine drain on stop**: flush repeats `.endOfStream` conversion calls until converter output is exhausted.
- **Engine converter coherence**: stop-time flush reads the latest converter through lock-protected state shared with tap recovery.
- **Engine underflow guard**: recorder logs one-time warning when per-tap output ratio drops below threshold (`0.85`).

Test invariants:
- `AudioRecorderBackendSelectionTests` enforces default backend = `AVAudioEngine` and `recorder` opt-out behavior.
- `AudioRecorderConversionTests` validates duration preservation for common input rates (`16k`, `24k`, `44.1k`, `48k`).
- Regression fixture explicitly checks the old truncation failure shape (`4096 @ 24k` incorrectly capped to `1600` output frames) is detected as unhealthy.
- `AudioRecorderFileFormatTests` verifies `AVAudioFile` processingFormat alignment and Int16 writes (prevents macOS 26+ traps).
- `AudioRecorderWriteFormatValidationTests` verifies runtime guard throws on buffer/file format mismatch.
- `CapturedAudioInspectorTests` validates payload detection across valid/empty/corrupt/missing capture files.
- `DictationPipelineTests` asserts header-only capture payloads fail fast with `VoxError.emptyCapture` before STT.

## Input Device Selection

`AudioDeviceManager` (VoxMac) enumerates CoreAudio devices and resolves stable `kAudioDevicePropertyDeviceUID` to runtime `AudioDeviceID`.

Default behavior uses `AVAudioEngine` for streaming-capable capture:
- `VoxSession` sets the selected input as macOS default before recording starts.
- `AudioRecorder` captures via `AVAudioEngine` with real-time chunk emission for streaming STT.

Optional overrides:
- set `VOX_AUDIO_BACKEND=recorder` to use legacy `AVAudioRecorder` backend (no streaming).
- set `VOX_ENABLE_PER_APP_AUDIO_ROUTING=1` to attempt `kAudioOutputUnitProperty_CurrentDevice` on the input `AudioUnit`.
- if per-app routing is unavailable/fails, capture continues on the default route.

Behavior:
- **System Default** (nil UID): recorder uses whatever macOS has selected
- **Specific device**: Vox sets system default input to the selected UID before capture
- **Device unplugged**: silently falls back to current system default
- **Optional per-app mode**: `VOX_ENABLE_PER_APP_AUDIO_ROUTING=1` (requires engine backend, which is now default)

## State Machine

```
 idle ── start ──▶ recording ── stop ──▶ processing ── done ──▶ idle
        ▲                                      │
        └────────────── error/permission ──────┘
```

## Protocol Architecture

`VoxCore/Protocols.swift` defines core contracts:
- `STTProvider`: async transcription from audio URL
- `StreamingSTTProvider` / `StreamingSTTSession`: realtime STT lifecycle (`makeSession`, chunk feed, finalize)
- `AudioChunk` / `PartialTranscript`: streaming payload + incremental transcript domain types
- `RewriteProvider`: async rewrite with prompt + model
- `TextPaster`: async main-actor text insertion
- `AudioRecording`: start/level/stop recording contract
- `AudioChunkStreaming`: optional recorder seam for realtime chunk callbacks
- `HUDDisplaying`: recording + processing + completion HUD updates
- `DictationProcessing`: pipeline abstraction for processing captured audio
- `TranscriptProcessing`: rewrite/paste abstraction for precomputed transcripts
- `TranscriptRecoveryProcessing`: transcript replay with explicit processing level + cache bypass controls
- `PreferencesReading`: read-only app settings + API key access for DI

App wires concrete providers in `DictationPipeline`. Swap implementations without touching flow logic.

## Wrapper Integration Points

Vox is designed for composition. Wrappers should import Vox modules and add behavior through seams, not by forking `VoxSession` or `DictationPipeline`.

### SwiftPM Dependency

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/misty-step/vox.git", from: "1.7.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "VoxAppKit", package: "vox"),
            // Or pick individual layers:
            // .product(name: "VoxCore", package: "vox"),
            // .product(name: "VoxProviders", package: "vox"),
            // .product(name: "VoxMac", package: "vox"),
        ]
    ),
]
```

### Primary seams
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
- `GEMINI_API_KEY` — primary rewriting
- `OPENROUTER_API_KEY` — model-routed rewriting for non-Gemini models + fallback path
- `DEEPGRAM_API_KEY` — STT fallback + optional streaming STT
- `VOX_MAX_CONCURRENT_STT` — optional global in-flight STT limit (default: `8`)
- `VOX_DISABLE_STREAMING_STT` — kill switch to force batch-only STT (`1`/`true`)
- `VOX_STT_ROUTING` — set to `hedged` for staggered parallel STT race (default: sequential fallback)
- `VOX_AUDIO_BACKEND` — `recorder` for legacy AVAudioRecorder (default: engine)

Endpoints:
- ElevenLabs STT: `https://api.elevenlabs.io/v1/speech-to-text`
- Deepgram STT: `https://api.deepgram.com/v1/listen?model=nova-3`
- Deepgram streaming STT: `wss://api.deepgram.com/v1/listen`
- OpenRouter chat: `https://openrouter.ai/api/v1/chat/completions`
- Gemini generateContent: `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`

Keychain storage in `KeychainHelper` (`com.vox.*` account keys).

## File Locations

| Area | Module | Files |
| --- | --- | --- |
| Entry point | VoxApp | `main.swift` |
| App lifecycle | VoxAppKit | `AppDelegate.swift`, `StatusBarController.swift`, `StatusBarIconRenderer.swift` |
| Session + pipeline | VoxAppKit | `VoxSession.swift`, `DictationPipeline.swift` |
| Settings | VoxAppKit | `PreferencesStore.swift`, `SettingsWindowController.swift`, `HotkeyState.swift`, `SettingsView.swift`, `BasicsSection.swift`, `CloudProvidersSection.swift`, `CloudKeysSheet.swift`, `CloudProviderCatalog.swift` |
| STT providers | VoxProviders | `ElevenLabsClient.swift`, `DeepgramClient.swift`, `DeepgramStreamingClient.swift`, `AppleSpeechClient.swift` |
| STT decorators | VoxCore | `TimeoutSTTProvider.swift`, `RetryingSTTProvider.swift`, `HedgedSTTProvider.swift`, `ConcurrencyLimitedSTTProvider.swift`, `HealthAwareSTTProvider.swift`, `FallbackSTTProvider.swift` |
| Rewrite providers | VoxProviders | `ProviderAssembly.swift`, `OpenRouterClient.swift`, `GeminiClient.swift`, `RewritePrompts.swift` |
| Rewrite routing | VoxCore | `ModelRoutedRewriteProvider.swift`, `FallbackRewriteProvider.swift` |
| Audio | VoxMac + VoxProviders | `AudioRecorder.swift`, `CapturedAudioInspector.swift`, `AudioDeviceManager.swift` (VoxMac), `AudioConverter.swift` (VoxProviders) |
| macOS integration | VoxMac | `HotkeyMonitor.swift`, `HUDController.swift`, `HUDView.swift`, `ClipboardPaster.swift`, `PermissionManager.swift`, `KeychainHelper.swift` |
| Core | VoxCore | `Protocols.swift`, `SessionExtension.swift`, `ProcessingLevel.swift`, `RewriteQualityGate.swift`, `Errors.swift`, `MultipartFormData.swift`, `BrandIdentity.swift` |

All paths under `Sources/{VoxApp,VoxAppKit,VoxCore,VoxMac,VoxProviders}/`.

## Quality Gate

`RewriteQualityGate` compares trimmed character count ratio:

```
ratio = candidate.count / max(raw.count, 1)
```

Minimum ratios:
- `raw`: 0 (rewrite skipped)
- `clean`: 0.6
- `polish`: 0.3

Maximum ratios:
- `clean`: 3.0 (other levels uncapped)

Benchmarks treat below min (or above max when defined) as a reject signal; the runtime pipeline does not block on this score (it only falls back on rewrite errors/empty output).

## macOS Permissions

- Microphone: requested by `PermissionManager.requestMicrophoneAccess()` before recording
- Speech Recognition: checked by `SFSpeechRecognizer.authorizationStatus()` before Apple Speech fallback; guarded against TCC crash for unbundled binaries
- Accessibility: required for paste; checked by `PermissionManager.isAccessibilityTrusted()` and prompted via `promptForAccessibilityIfNeeded()`

## Logging Convention

All modules log with bracket-prefixed tags to stdout:
- `[ElevenLabs]`, `[Deepgram]`, `[AppleSpeech]` — provider-level request/response
- `[STT]` — decorator-level retries, hedge launches, winner/failure transitions
- `[Pipeline]` — processing stages
- `[Vox]` — session-level events
- `[AudioRecorder]` — capture backend and conversion diagnostics
- `[Paster]` — clipboard and paste operations
