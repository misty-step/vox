# Issue #195: Streaming STT Session Flow Integration

## Product Spec

### Problem
Vox needed session-level orchestration for streaming STT: feed chunks while recording, assemble transcript text, finalize quickly on stop, and degrade to batch STT without changing user-visible output behavior.

### Goal
Make streaming STT the default runtime path when available, while keeping reliability-first stop behavior and preserving rewrite/paste semantics.

### Non-Goals
- No new user-facing settings.
- No provider-specific UI branching.
- No change to downstream rewrite quality policy.

### Scope
1. Stream recorder chunks into a live `StreamingSTTSession`.
2. Assemble transcript output from final transcript, with partial fallback when needed.
3. Bound stop-time finalization with a timeout.
4. Fall back to batch `DictationPipeline` STT on setup/finalize failure.
5. Keep output semantics identical (rewrite + paste path unchanged).

### Acceptance Criteria
- [x] Streaming begins during recording and accumulates transcript state.
- [x] Stop attempts streaming finalize first with bounded timeout.
- [x] Timeout/error path falls back to batch STT and still produces output.
- [x] Existing empty-capture and audio guardrail tests remain green.
- [x] Bench evidence generated with the pipeline harness.

## Technical Design

### Design Summary
- `VoxSession` creates `StreamingAudioBridge` at record start and installs a chunk handler before recorder start.
- Streaming setup runs asynchronously with setup timeout protection.
- `StreamingAudioBridge` buffers chunks until session attach, then drains to `StreamingSessionPump`.
- `StreamingSessionPump` tracks latest non-empty partial transcript and uses it when `finish()` returns empty.
- Stop flow finalizes streaming with `withStreamingFinalizeTimeout`; non-fatal failures route to batch pipeline.

### Module Boundaries
- `VoxSession`: orchestration and fallback policy.
- `StreamingAudioBridge`: chunk buffering and pump lifecycle.
- `StreamingSessionPump`: send/finalize sequencing and partial transcript assembly.
- `DictationPipeline`: unchanged output processing contract (`process(audioURL:)` and `process(transcript:)`).

### Reliability Controls
- Setup timeout fails closed into batch fallback.
- Finalize timeout fails closed into batch fallback.
- Non-fallback-eligible streaming errors are surfaced after session cancel.
- Recorder-stop failures always clean up streaming bridge/session.

### Verification Plan
- Unit tests for:
  - successful streaming finalize transcript path
  - finalize timeout fallback path
  - partial transcript assembly fallback when final transcript is empty
  - setup buffering and setup timeout behavior
- Strict build/tests with warnings-as-errors.
- Audio guardrail contract script.
- Benchmark harness output recorded in PR.

## Verification Evidence (2026-02-11)

- `swift build -Xswiftc -warnings-as-errors` passed.
- `swift test -Xswiftc -warnings-as-errors` passed (includes streaming session suite additions).
- `./scripts/test-audio-guardrails.sh` passed.
- `./scripts/benchmark.sh` passed:
  - `Pipeline overhead p95 under 50ms (mock delays excluded)` passed
  - `Paste stage p95 within budget` passed
  - `Stage timings sum correctly across iterations` passed
  - `Full benchmark produces valid JSON artifact` passed
