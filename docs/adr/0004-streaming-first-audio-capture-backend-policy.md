# ADR-0004: Streaming-First Audio Capture Backend Policy

## Status

Accepted

Supersedes: [ADR-0003](./0003-audio-capture-reliability-first-backend-policy.md)

## Context

Vox supports real-time (streaming) STT, which needs low-latency PCM chunk emission during capture.

`AVAudioRecorder` is a reliable file-based capture primitive, but it does not provide tap-based chunk streaming.
`AVAudioEngine` enables chunk emission (and optional per-app routing), but previously caused reliability regressions when it became the default backend.

We need:

- streaming-capable capture as the default path (to avoid hidden “opt-in” complexity in the session/pipeline)
- explicit escape hatch to a simpler legacy backend
- hard guardrails so audio capture failures surface as typed errors (not empty transcripts or system traps)

## Decision

Adopt a streaming-first backend policy:

1. Make `AVAudioEngine` the default capture backend (`VOX_AUDIO_BACKEND` unset).
2. Keep `AVAudioRecorder` as a legacy opt-out backend (`VOX_AUDIO_BACKEND=recorder`).
3. Enable streaming STT by default when a Deepgram key is present, with a kill switch to force batch-only behavior (`VOX_DISABLE_STREAMING_STT=1|true|yes`).
4. Treat audio format safety as a contract:
   - use explicit `AVAudioFile` initialization to align `processingFormat` with writes
   - validate buffer/file format compatibility before writes (turn system traps into `VoxError.audioCaptureFailed`)
5. Preserve pipeline invariants:
   - reject zero-frame captures before STT (`VoxError.emptyCapture`)
   - fall back to batch STT when streaming setup/finalize fails or times out

## Consequences

### Positive

- Streaming STT is available on the default path without hidden configuration.
- Lower end-to-end latency when Deepgram streaming is configured.
- Capture reliability regressions are guarded by tests and runtime validation instead of “best effort”.

### Negative

- Default capture path is higher-complexity (engine + converter + tap).
- More surface area for Apple audio format quirks; requires strict guardrails.

### Neutral

- Two backends remain supported; policy is env-driven, not a user-facing setting.
- Per-app routing stays opt-in (`VOX_ENABLE_PER_APP_AUDIO_ROUTING=1`) even though engine is default.

## Alternatives Considered

### Alternative 1: Keep `AVAudioRecorder` as default, streaming opt-in

Rejected because it keeps streaming behavior as a “special case” and increases change amplification in session orchestration and docs.

### Alternative 2: Remove `AVAudioRecorder` entirely

Rejected because it removes a low-complexity escape hatch that is valuable for reliability recovery and investigation.

