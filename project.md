# Project: Vox

## Vision
Voice-to-text with optional AI polish — from raw transcript to refined prose, for writers and developers who dictate frequently.

**North Star:** The invisible writing assistant. Press hotkey, speak naturally, get text your way. No configuration maze, no learning curve, no friction. Just works.

**Target User:** Writers, developers, knowledge workers who dictate frequently. People frustrated by apps with too many settings, subscription fatigue, and clunky UIs.

**Current Focus:** Q1 2026 — Polish core experience, performance, design identity, documentation, and modular architecture for future Vox Pro wrapper.

**Key Differentiators:**
- Rewrite as first-class feature — Clean tidy-up, Polish refinement, or Raw transcript
- Zero configuration — Works perfectly out of the box, BYOK simplicity
- World-class UX — Delightful interactions, not feature sprawl
- Open source core — Community-driven, extensible, trustworthy

## Domain Glossary

Terms agents must understand to work in this codebase.

| Term | Definition |
|------|-----------|
| STT | Speech-to-text — transcription of audio to text |
| Rewrite | AI post-processing of raw transcript (Clean = light tidy, Polish = richer prose) |
| Clean | Rewrite mode: minimal cleanup (punctuation, filler words), preserves user's voice |
| Polish | Rewrite mode: more refined prose, improves flow and clarity |
| Raw | No rewrite — paste exact transcript |
| HUD | Heads-up display — floating status indicator shown during recording/processing |
| Pipeline | The full dictation flow: record → STT → optional rewrite → paste |
| Decorator | Composable STT wrapper (timeout, retry, hedge, concurrency limit) |
| BYOK | Bring Your Own Key — users supply their own API keys (ElevenLabs, Deepgram, etc.) |
| Hedged routing | Parallel STT provider race with stagger delays (opt-in via VOX_STT_ROUTING=hedged) |
| Sequential fallback | Default STT routing: try primary, fall back to next on failure |
| Streaming STT | Deepgram WebSocket-based real-time transcription (enabled by default with key) |
| Opus | Compressed audio format used for upload efficiency (8x smaller than WAV) |
| CAF | Core Audio Format — recording output format from AVAudioEngine |

## Active Focus

- **Milestone:** Streaming-First Latency Path (Q1 2026)
- **Key Issues:** #259 (rewrite model bakeoff), #226 (Opus flakiness), #208 (processing UX)
- **Theme:** Minimize time from stop→paste. Streaming STT is live; now tighten rewrite latency and polish UX.

## Quality Bar

What "done" means beyond "tests pass."

- [ ] Pre-push hook passes: `swift build -Xswiftc -warnings-as-errors`
- [ ] Audio guardrails pass: `./scripts/test-audio-guardrails.sh`
- [ ] No transcript content in logs (char counts only)
- [ ] No new user-facing settings without ADR justification (ADR-0001 simplicity gate)
- [ ] Hotkey → paste latency perceptibly fast for ≤60s recordings
- [ ] Works out of the box with zero config (BYOK optional, not required)
- [ ] No crashes, no silent failures — errors surface to user

## Patterns to Follow

### Decorator Composition (STT)
```swift
// Wrap providers, don't branch inside them
let provider = ConcurrencyLimitedSTTProvider(
    limit: 8,
    wrapping: FallbackSTTProvider(
        primary: RetryingSTTProvider(wrapping: TimeoutSTTProvider(wrapping: elevenLabs)),
        fallback: RetryingSTTProvider(wrapping: TimeoutSTTProvider(wrapping: deepgram))
    )
)
```

### Error Classification
```swift
// Centralize in STTError, not in each provider
extension STTError {
    var isRetryable: Bool { ... }
    var isFallbackEligible: Bool { ... }
}
```

### Constructor DI
```swift
// VoxSession: pass nil for defaults
init(recorder: AudioRecording? = nil,
     pipeline: DictationProcessing? = nil,
     hud: HUDDisplaying? = nil,
     prefs: PreferencesReading? = nil)
```

### Thread-Safe Mocks (NSLock)
```swift
// Tests: callbacks arrive from non-MainActor threads
class MockSTTProvider: STTProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0
    var callCount: Int { lock.withLock { _callCount } }
}
```

## Lessons Learned

| Decision | Outcome | Lesson |
|----------|---------|--------|
| AVAudioFile(forWriting:settings:) | Crashed on macOS 26+ (Int16 buffer assertion) | Always use 4-param explicit init with commonFormat+interleaved |
| AVAudioConverter input block | Frame duplication on re-entry | Gate with hasData flag, return .noDataNow on re-entry |
| Changing default backend | Exposed bugs in unchanged code paths | Defaults flip = latent bug exposure; test real I/O not just mocks |

---
*Last updated: 2026-02-23*
*Updated during: /groom session*
