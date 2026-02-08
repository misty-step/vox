# Postmortem: Audio Capture Underflow After AVAudioEngine Migration

## Summary

On February 8, 2026 (UTC), Vox users reported that dictation captured little or no usable audio despite correct microphone selection (notably AirPods/Bluetooth inputs). The issue was introduced by the AVAudioEngine migration and caused per-tap conversion truncation when the converted frame count exceeded a fixed 100ms output buffer. We resolved it by draining converter output fully per tap, sizing output buffers from frame-ratio math, adding flush-drain correctness, and shipping regression tests that enforce duration preservation across common sample rates.

## Timeline (UTC)

- **2026-02-08 04:21:10** — Commit `f022cad` merged (`refactor(audio): AVAudioEngine for per-app device routing`).
- **2026-02-08 ~04:40** — Local user report: Vox no longer picks up audio, while SuperWhisper works with same AirPods input.
- **2026-02-08 ~04:43** — Debug session isolated truncation path in `AudioRecorder` conversion loop.
- **2026-02-08 04:50:34** — Fix branch pushed (`fix/audio-conversion-drain`, commit `85bc3f1`).
- **2026-02-08 04:50:43** — PR #177 opened with fix + regression tests.

## Root Cause

`AudioRecorder` converted each tap buffer once into a fixed output capacity (`1600` frames, 100ms at 16kHz). For Bluetooth-style input formats/rates (e.g. `24kHz` with `4096`-frame taps), expected converted output per tap is ~`2731` frames. The excess frames were dropped because conversion output was not drained (`status == .haveData` not looped), causing systematic audio loss.

## 5 Whys

1. Why did transcripts become empty/poor?
- Large portions of captured audio were dropped during format conversion.

2. Why were frames dropped?
- Conversion wrote a single fixed-size output buffer per tap and stopped.

3. Why was single-buffer conversion used?
- Refactor focused on per-app device routing and replaced recorder internals without a duration-preservation contract.

4. Why did tests not catch it?
- Existing tests covered metering math but not conversion throughput/integrity across sample rates.

5. Why was this gap allowed?
- No explicit architectural invariant defined for audio conversion correctness, and no mandatory regression fixture for Bluetooth-like input rates.

## What Went Well

- Issue was quickly localized to one module (`AudioRecorder`) with reproducible frame math.
- Fix was narrow and reversible, with no user-facing settings added.
- Regression tests now encode the exact failure shape and common hardware rates.
- Strict warnings-as-errors pipeline prevented unsafe concurrency warning drift during fix.

## What Went Wrong

- Critical audio-path refactor merged without conversion integrity tests.
- Manual validation did not include Bluetooth/low-sample-rate microphone scenarios.
- We had no documented module contract saying audio duration must be preserved across conversion.

## Follow-up Actions

1. **Done** — Drain converter output until exhausted per tap and on stop flush.
Owner: `@phaedrus`

2. **Done** — Add conversion integrity tests for `16k/24k/44.1k/48k` and explicit underflow regression fixture.
Owner: `@phaedrus`

3. **Done** — Add architecture-level conversion invariants to `docs/ARCHITECTURE.md`.
Owner: `@phaedrus`

4. **Done** — Codify testing guardrail in `CLAUDE.md` for any `AudioRecorder` changes.
Owner: `@phaedrus`

5. **Done** — Add PR template checklist item: “Audio path changes validated against `AudioRecorderConversionTests` and Bluetooth-rate fixture.”
Owner: `@phaedrus`
