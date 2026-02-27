# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
swift build                                    # Debug build
swift build -c release                         # Release build
swift build -Xswiftc -warnings-as-errors       # Strict build (matches CI + pre-push hook)
swift test                                     # Run all tests
swift test -Xswiftc -warnings-as-errors        # Strict test (matches CI)
./scripts/run-tests-ci.sh                      # CI strict tests with timeout + timeout diagnostics
./scripts/test-audio-guardrails.sh             # Critical audio regression contract tests
swift test --filter VoxCoreTests               # Run one test target
swift test --filter RetryingSTTProviderTests    # Run one test class
./scripts/benchmark.sh                         # Run pipeline latency benchmark
./scripts/run.sh                               # Launch debug binary with keys from .env.local
```

CI runs on macOS 14 with Xcode 16.2. Warnings-as-errors is enforced in CI. All builds and tests must pass with `-Xswiftc -warnings-as-errors`.

Git hooks (`.githooks/`): pre-commit runs SwiftLint on staged files (<1s), pre-push runs `swift build -Xswiftc -warnings-as-errors` (~30s). Full test suite and audio guardrails run only in CI.

## Architecture

Pure SwiftPM, zero external dependencies. Nine targets forming a strict dependency DAG (plus auxiliary: `VoxBenchmarks`, `VoxPerfAudit`, `VoxPerfAuditKit`):

```
VoxCore          — protocols, errors, decorators, shared types (no deps)
VoxProviders     — STT clients, rewrite clients, streaming (depends: VoxCore)
VoxMac           — macOS integrations: audio, keychain, HUD, hotkeys (depends: VoxCore)
VoxDiagnostics   — diagnostics store, perf ingest, product info (depends: VoxCore)
VoxPipeline      — dictation pipeline, rewrite cache, recovery store (depends: VoxCore)
VoxUI            — status bar, settings, onboarding, debug workbench (depends: VoxCore, VoxMac, VoxDiagnostics)
VoxSession       — session state machine, streaming bridge, provider assembly (depends: VoxCore, VoxProviders, VoxMac, VoxDiagnostics, VoxPipeline, VoxUI)
VoxAppKit        — composition root: AppDelegate only (depends: all above)
VoxApp           — executable entry point, just main.swift (depends: VoxAppKit)
```

VoxPipeline depends only on VoxCore — all I/O (diagnostics, opus conversion, audio validation) is injected via closures.

### STT Resilience Chain

Providers are wrapped in composable decorators, with default routing via sequential fallback:

```text
                         ConcurrencyLimit(8 default)
                                   │
                                   ▼
                     Sequential FallbackSTTProvider chain
                                   │
      ElevenLabs(Timeout+Retry) → Deepgram(Timeout+Retry) → Apple STT

Apple STT (macOS 26+): SpeechTranscriberClient → AppleSpeechClient
Apple STT (macOS < 26): AppleSpeechClient
```

- **Default routing**: sequential primary+fallback — tries providers in order, falls back on failure
- **Opt-in hedged routing**: `VOX_STT_ROUTING=hedged` restores parallel cloud race with stagger delays
- **TimeoutSTTProvider**: dynamic deadline — `baseTimeout + fileSizeMB * secondsPerMB`
- **RetryingSTTProvider**: exponential backoff + jitter on `STTError.isRetryable` errors
- **HedgedSTTProvider**: parallel race with stagger delays (opt-in only)
- **FallbackSTTProvider**: sequential primary → fallback on eligible errors
- **ConcurrencyLimitedSTTProvider**: bounds in-flight STT transcribes and queues overflow
- **HealthAwareSTTProvider**: retained for adaptive routing strategies and tests
- Hedge/fallback logic treats non-STTError failures as fallback-eligible network/transient failures
- `CancellationError` must propagate cleanly through all decorators

### Data Flow

Option+Space → VoxSession sets selected input as system default (compat path) → AudioRecorder (default backend: AVAudioEngine @ 16kHz/16-bit mono CAF with streaming chunk emission; legacy AVAudioRecorder opt-in via `VOX_AUDIO_BACKEND=recorder`) → streaming STT via Deepgram WebSocket (if Deepgram key present, kill switch: `VOX_DISABLE_STREAMING_STT=1`) with batch fallback → CapturedAudioInspector validates capture payload (`VoxError.emptyCapture` on zero frames) → optional Opus conversion (empty output falls back to CAF) → STT chain → optional rewrite via ProviderAssembly cloud routing (ModelRoutedRewriteProvider when Gemini+OpenRouter are both configured; otherwise direct provider) → ClipboardPaster inserts text → SecureFileDeleter cleans up

### State Machine

`VoxSession`: idle → recording → processing → idle (error returns to idle)

## Key Patterns

**Decorator composition**: Add cross-cutting concerns (timeout, retry, hedged routing, concurrency limits) by wrapping `STTProvider`. Never add special-case branches inside providers.

**DI via constructor injection**: `VoxSession` accepts optional `AudioRecording`, `DictationProcessing`, `HUDDisplaying`, `PreferencesReading`. Pass `nil` for defaults. Protocols live in `VoxCore/Protocols.swift`.

**Error classification**: `STTError.isRetryable`, `.isFallbackEligible`, and `.isTransientForHealthScoring` centralize error semantics across retry/hedge/routing.

**Quality gate**: `RewriteQualityGate` scores candidate/raw similarity (ratio + distance metrics) for evaluation and benchmarks only — removed from production path in #284 (clean: 0.6, polish: 0.3).

**Availability gating (macOS 26+)**: `#if canImport(FoundationModels)` as compile-time SDK proxy + `@available(macOS 26.0, *)` runtime check. `SpeechTranscriberClient` uses this double-gate. On Xcode 16.2 CI it compiles out; on Xcode 26+ it's fully exercised.

**API key resolution**: env vars checked first (`ProcessInfo.environment`), then Keychain. Keys: `ELEVENLABS_API_KEY`, `OPENROUTER_API_KEY`, `DEEPGRAM_API_KEY`, `GEMINI_API_KEY`. Optional STT throttle guard: `VOX_MAX_CONCURRENT_STT` (default `8`). Runtime overrides: `VOX_AUDIO_BACKEND=recorder` (opt out of AVAudioEngine default), `VOX_DISABLE_STREAMING_STT=1` (force batch-only STT), `VOX_STT_ROUTING=hedged` (opt in to parallel cloud race instead of sequential fallback). Diagnostics: `VOX_PERF_INGEST_URL` (HTTP endpoint for pipeline timing upload).

**Release automation safety**: release scripts that generate plist/XML content must validate output with `plutil -lint`; CI secret checks should fail with explicit missing-secret names (avoid bare `test -n` without context).

## Audio Platform Gotchas

- **AVAudioFile init**: Never use `AVAudioFile(forWriting:settings:)` — it auto-selects Float32 non-interleaved as `processingFormat`, which crashes on `write(from:)` with Int16 interleaved buffers (macOS 26+ assertion in `ExtAudioFile::WriteInputProc`). Always use the explicit 4-param init:
  ```swift
  AVAudioFile(forWriting: url, settings: fmt.settings,
              commonFormat: fmt.commonFormat, interleaved: fmt.isInterleaved)
  ```
- **Pre-write validation**: `validateWriteFormatCompatible(buffer:file:)` guards every `file.write(from:)` call — converts system trap to recoverable `VoxError.audioCaptureFailed`
- **Format contract tests**: `AudioRecorderFileFormatTests` verifies processingFormat alignment and actual Int16 write success without hardware

## Concurrency Gotchas

- `@MainActor` protocol default params can't call `@MainActor` init in default expressions — use `nil` + resolve in body
- Swift 6: don't pass non-Sendable deps into actor init (esp. for `static let shared`); construct inside actor instead
- `AudioConverter` uses `terminationHandler` continuation, not blocking `waitUntilExit()`
- Mock providers in tests use `NSLock` + `@unchecked Sendable` for thread safety (callbacks arrive from non-MainActor threads)
- Continuation guards need `NSLock` — see `ContinuationGuard` pattern in `AppleSpeechClient`

## Testing

XCTest and Swift Testing with async tests. ~200 tests across eight targets:
- `VoxCoreTests` — decorators, error classification, quality gate, multipart encoding
- `VoxProvidersTests` — client request format, streaming protocol, file size limits, error branches
- `VoxDiagnosticsTests` — error code mapping, diagnostics value codable, event names
- `VoxPipelineTests` — pipeline integration, opus conversion, rewrite cache, diagnostics callbacks
- `VoxUITests` — debug workbench, preferences cache, onboarding, settings, status bar
- `VoxSessionTests` — session state machine, streaming bridge, grace window
- `VoxAppTests` — audio recorder, HUD state, format validation, benchmark SLO
- `VoxPerfAuditKitTests` — config parsing, provider plan, distribution math

Test method naming: `test_methodName_behaviorWhenCondition` (e.g., `test_transcribe_retriesOnThrottledError`).

Shared mock: `Tests/VoxCoreTests/MockSTTProvider.swift` — thread-safe with NSLock.

Async timeout tests should avoid sub-100ms thresholds unless explicitly testing timeout granularity. Prefer `>= 0.1s` to reduce CI scheduler-jitter flakes.

Audio regression guardrail:
- Changes to `Sources/VoxMac/AudioRecorder.swift` must preserve backend reliability defaults and conversion duration invariants. Keep/extend:
  - `AudioRecorderBackendSelectionTests` (default backend = `AVAudioEngine`; `recorder` is opt-out)
  - `AudioRecorderConversionTests` (Bluetooth-like `24k` plus `16k/44.1k/48k` sample-rate coverage; converter drain logic tested, not assumed)
  - `AudioRecorderFileFormatTests` (AVAudioFile processingFormat alignment; Int16 write integration — prevents macOS 26+ crash)
  - `AudioRecorderWriteFormatValidationTests` (runtime format guard catches mismatch before system trap)
  - `CapturedAudioInspectorTests` (valid/empty/corrupt/missing payload detection)
  - `DictationPipelineTests` empty-capture fast-fail guard (`VoxError.emptyCapture`) and Opus-empty fallback contract
  - `scripts/test-audio-guardrails.sh` as CI gate entrypoint

## Conventions

- **Commits**: Conventional Commits — `feat(scope):`, `fix(security):`, `refactor(di):`, `docs:`
- **Branches**: `feat/`, `fix/`, `refactor/`, `docs/`
- **Logging**: bracket-prefixed tags — `[ElevenLabs]`, `[STT]`, `[Pipeline]`, `[Vox]`, `[Paster]`, `[AudioRecorder]`
- **Security**: no transcript content in logs (char counts only); debug logs gated behind `#if DEBUG`
- **Audio cleanup**: `SecureFileDeleter` — relies on FileVault; `preserveAudio()` returns `URL?` for error recovery dialog
- **Simplicity gate** ([ADR-0001](docs/adr/0001-simplicity-first-design.md)): no new user-facing settings without ADR justification; no advanced tabs, threshold tuning, or model selection UI; defaults over options; no dark features (stored prefs without UI)

## Triad Workflow (Quality, Simplicity, Speed)

- Every issue and PR must state expected deltas for all three axes: `quality`, `simplicity`, `speed`.
- Use triad labels on issues: exactly one from each axis (`quality:+|0|-`, `simplicity:+|0|-`, `speed:+|0|-`).
- Mark each issue as `triad:no-brainer` or `triad:tradeoff`.
- For tradeoffs, include explicit justification and latency budget notes in the issue body.
- Prefer designs that keep rewrite critical path fast: move heavy context work off critical path.

For detailed architecture, module guide, and navigation, see [docs/CODEBASE_MAP.md](docs/CODEBASE_MAP.md).
