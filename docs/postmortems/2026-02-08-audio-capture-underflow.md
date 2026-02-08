# Postmortem: Audio Capture Regression After AVAudioEngine Migration

## Summary

On February 8, 2026 (UTC), Vox regressions caused recordings to produce header-only CAF files (`audio bytes: 0`) even though recording duration advanced and input device selection looked correct (AirPods/Bluetooth included).  

Two issues existed:

- A real converter underflow bug in the new AVAudioEngine path (fixed first).
- A broader capture reliability regression from switching the default backend from `AVAudioRecorder` to `AVAudioEngine` (root production impact).

Final fix: restore `AVAudioRecorder` as default capture backend, keep `AVAudioEngine` behind explicit opt-in (`VOX_AUDIO_BACKEND=engine`), and add a pipeline invariant that rejects header-only CAFs before STT.

## Impact

- User-visible symptom: recordings completed, but STT returned empty transcript (`No transcript returned.`).
- Technical symptom: recovery CAF files contained only container header (`audio bytes: 0`).
- Scope: all users on builds where `AVAudioEngine` became default capture path (`f022cad`), with elevated risk on Bluetooth/default-route setups.

## Detection

- Primary detection came from user report, not automated checks.
- Existing CI passed because it lacked an explicit contract for default backend reliability and zero-frame payload detection.
- Recovery artifact inspection (`afinfo`) was decisive signal for isolation.

## Timeline (UTC)

- **2026-02-08 04:21:10** — Commit `f022cad` merged (`refactor(audio): AVAudioEngine for per-app device routing`).
- **2026-02-08 ~04:40** — User reports Vox no longer captures usable audio while SuperWhisper works with same AirPods.
- **2026-02-08 04:50:34** — Commit `85bc3f1` shipped converter drain fix + sample-rate tests.
- **2026-02-08 ~05:20** — Regression persists: new recordings still header-only CAF (`audio bytes: 0`).
- **2026-02-08 ~05:30** — Root impact isolated to AVAudioEngine default backend behavior on real routes/devices.
- **2026-02-08 ~05:45** — Reliability fix implemented: `AVAudioRecorder` default, engine opt-in, header-only CAF fast-fail guard.

## Root Cause

`f022cad` changed the default capture primitive from `AVAudioRecorder` to `AVAudioEngine` to support per-app routing.  

That refactor coupled two concerns:

- experimental routing behavior
- default capture path used by every user

Result: on affected route/device combinations, tap callbacks produced no payload frames, and Vox wrote only CAF headers. Converter fixes alone could not solve this class because there were no frames to convert.

## Why It Reached Production

1. Audio refactor changed the default backend, not just an optional path.
2. CI had no behavioral contract for backend stability (only converter math once added).
3. Manual checks did not include post-merge verification on Bluetooth/default-route combinations for zero-frame output.
4. No pipeline guard existed to stop and surface header-only captures before STT.

## Verification Evidence

- Runtime logs now show selected capture backend at start (`[AudioRecorder] Backend: ...`).
- Payload validation is centralized (`CapturedAudioInspector`) and emits typed failure (`VoxError.emptyCapture`) before STT.
- Guardrail tests now cover:
  - backend-selection contract
  - conversion-duration contract
  - payload validation for valid/empty/corrupt/missing captures
  - pipeline fail-fast behavior on empty capture

## Ousterhout Strategic Fixes

1. **Deep module boundary restored**: `AudioRecorder` exposes one stable interface while backend complexity is internal. Default is reliability-first (`AVAudioRecorder`); experimental path is explicit opt-in.
2. **Information hiding improved**: per-app routing complexity is no longer on the default path.
3. **Invariant at module boundary**: `DictationPipeline` now rejects header-only CAF payloads before STT (`No audio frames captured...`) to fail fast.
4. **Contract tests added**:
   - backend-selection contract (`AudioRecorderBackendSelectionTests`)
   - conversion-duration contract (`AudioRecorderConversionTests`)
   - payload-inspection contract (`CapturedAudioInspectorTests`)
   - pipeline empty-capture guard (`DictationPipelineTests`)
5. **Process hardening**:
   - architecture doc updated with backend + payload invariants
   - CLAUDE guardrail updated for audio changes
   - PR checklist updated to require backend + conversion + fast-fail test coverage

## Follow-up Actions

1. **Done** — Default backend reverted to `AVAudioRecorder`; `AVAudioEngine` is opt-in via `VOX_AUDIO_BACKEND=engine`.
2. **Done** — Converter drain + stale-format recovery tests retained for engine path.
3. **Done** — Payload validation moved to dedicated module (`CapturedAudioInspector`) with typed failure (`VoxError.emptyCapture`).
4. **Done** — Pipeline fast-fail on empty capture before STT.
5. **Done** — Documentation and PR/test guardrails updated.
6. **Done** — ADR-0003 recorded reliability-first backend policy and payload contract.
