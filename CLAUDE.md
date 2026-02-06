# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
swift build                                    # Debug build
swift build -c release                         # Release build
swift build -Xswiftc -warnings-as-errors       # Strict build (matches CI + pre-push hook)
swift test                                     # Run all tests
swift test -Xswiftc -warnings-as-errors        # Strict test (matches CI)
swift test --filter VoxCoreTests               # Run one test target
swift test --filter RetryingSTTProviderTests    # Run one test class
./scripts/run.sh                               # Launch debug binary with keys from .env.local
```

CI runs on macOS 14 with Xcode 16.2. Warnings-as-errors is enforced in CI and via a `.githooks/pre-push` hook. All builds and tests must pass with `-Xswiftc -warnings-as-errors`.

## Architecture

Pure SwiftPM, zero external dependencies. Five targets forming a strict dependency hierarchy:

```
VoxCore          — protocols, errors, decorators, shared types (no deps)
VoxProviders     — STT clients + OpenRouter rewriting (depends: VoxCore)
VoxMac           — macOS integrations: audio, keychain, HUD, hotkeys (depends: VoxCore)
VoxAppKit        — session, pipeline, settings, UI controllers (depends: all above)
VoxApp           — executable entry point, just main.swift + AppDelegate (depends: VoxAppKit)
```

VoxAppKit was extracted from VoxApp so tests can import it — SwiftPM executable targets can't be test dependencies.

### STT Resilience Chain

Providers are wrapped in composable decorators, each an `STTProvider` wrapping another:

```
ElevenLabs → Timeout → Retry(3x) ─┐
                                    ├→ Fallback
Deepgram   → Timeout → Retry(2x) ─┤     ├→ Fallback
                                    │     │     ├→ Fallback → Final result
Whisper    → Timeout → Retry(2x) ──┘     │     │
                                          │     │
Apple Speech (on-device, always available) ┘     │
```

- **TimeoutSTTProvider**: dynamic deadline — `baseTimeout + fileSizeMB * secondsPerMB`
- **RetryingSTTProvider**: exponential backoff + jitter on `STTError.isRetryable` errors
- **FallbackSTTProvider**: catches `STTError.isFallbackEligible`, invokes callback, tries next
- Both retry and fallback decorators have catch-all for non-STTError types (URLError, NSError)
- `CancellationError` must propagate cleanly through all decorators

### Data Flow

Option+Space → AudioRecorder (16kHz/16-bit mono CAF) → STT chain → optional rewrite via OpenRouterClient → RewriteQualityGate validates output → ClipboardPaster inserts text → SecureFileDeleter cleans up

### State Machine

`VoxSession`: idle → recording → processing → idle (error returns to idle)

## Key Patterns

**Decorator composition**: Add cross-cutting concerns (timeout, retry, fallback) by wrapping `STTProvider`. Never add special-case branches inside providers.

**DI via constructor injection**: `VoxSession` accepts optional `AudioRecording`, `DictationProcessing`, `HUDDisplaying`, `PreferencesReading`. Pass `nil` for defaults. Protocols live in `VoxCore/Protocols.swift`.

**Error classification**: `STTError.isRetryable` and `.isFallbackEligible` centralize which errors trigger which decorator behavior.

**Quality gate**: `RewriteQualityGate` compares candidate/raw character count ratio. Falls back to raw transcript if below threshold (light: 0.6, aggressive: 0.3, enhance: 0.2).

**API key resolution**: env vars checked first (`ProcessInfo.environment`), then Keychain. Keys: `ELEVENLABS_API_KEY`, `OPENROUTER_API_KEY`, `DEEPGRAM_API_KEY` (optional), `OPENAI_API_KEY` (optional).

## Concurrency Gotchas

- `@MainActor` protocol default params can't call `@MainActor` init in default expressions — use `nil` + resolve in body
- `AudioConverter` uses `terminationHandler` continuation, not blocking `waitUntilExit()`
- Mock providers in tests use `NSLock` + `@unchecked Sendable` for thread safety (callbacks arrive from non-MainActor threads)
- Continuation guards need `NSLock` — see `ContinuationGuard` pattern in `AppleSpeechClient`

## Testing

XCTest with async tests. ~50 tests across three targets:
- `VoxCoreTests` — decorators, error classification, quality gate, multipart encoding
- `VoxProvidersTests` — client request format, file size limits
- `VoxAppTests` — DI contract verification for VoxSession

Test method naming: `test_methodName_behaviorWhenCondition` (e.g., `test_transcribe_retriesOnThrottledError`).

Shared mock: `Tests/VoxCoreTests/MockSTTProvider.swift` — thread-safe with NSLock.

## Conventions

- **Commits**: Conventional Commits — `feat(scope):`, `fix(security):`, `refactor(di):`, `docs:`
- **Branches**: `feat/`, `fix/`, `refactor/`, `docs/`
- **Logging**: bracket-prefixed tags — `[ElevenLabs]`, `[STT]`, `[Pipeline]`, `[Vox]`, `[Paster]`
- **Security**: no transcript content in logs (char counts only); debug logs gated behind `#if DEBUG`
- **Audio cleanup**: `SecureFileDeleter` — relies on FileVault; `preserveAudio()` returns `URL?` for error recovery dialog
- **Simplicity gate** ([ADR-0001](docs/adr/0001-simplicity-first-design.md)): no new user-facing settings without ADR justification; no advanced tabs, threshold tuning, or model selection UI; defaults over options; no dark features (stored prefs without UI)
