# ADR-0003: Audio Capture Reliability-First Backend Policy

## Status

Superseded

Superseded by: [ADR-0004](./0004-streaming-first-audio-capture-backend-policy.md)

## Context

`AudioRecorder` was refactored from `AVAudioRecorder` to `AVAudioEngine` as the default capture primitive to enable per-app routing.  
That change coupled an experimental capability (routing/control) to the default path used by every user.

The result was a production regression where capture wrote CAF headers but no payload frames on some real device/route combinations (notably Bluetooth/default-route scenarios). STT then ran on empty audio and returned no transcript.

The decision needed: how to preserve advanced audio capabilities without putting core capture reliability at risk.

## Decision

Adopt a reliability-first backend policy:

1. Keep `AVAudioRecorder` as the default capture backend.
2. Keep `AVAudioEngine` available only as explicit opt-in (`VOX_AUDIO_BACKEND=engine`) for experiments and advanced routing.
3. Enforce a payload invariant before STT: captured audio must contain decodable frames.
4. Centralize payload validation in `CapturedAudioInspector` and surface typed failure as `VoxError.emptyCapture`.
5. Treat backend selection and payload validation as contract-tested behavior.

## Consequences

### Positive

- Default path is simpler and uses a proven capture primitive.
- Experimental complexity is isolated behind an opt-in seam.
- Empty-capture regressions fail fast with explicit error semantics.
- Regression class is directly guarded by tests and documentation.

### Negative

- Per-app routing behavior is no longer available on default path.
- Maintaining two backends increases internal maintenance burden.
- Some advanced investigations require explicit env configuration.

### Neutral

- Existing conversion robustness tests remain valuable for engine path.
- Public user-facing settings remain unchanged (policy is internal/env-driven).

## Alternatives Considered

### Alternative 1: Keep `AVAudioEngine` as default and patch edge cases

Rejected because reliability risk remains high: edge-case patching still keeps highest-complexity path as default blast radius.

### Alternative 2: Remove `AVAudioEngine` entirely

Rejected because it would eliminate useful experimentation and future routing capabilities.

### Alternative 3: Keep backend policy implicit in code comments only

Rejected because the decision is costly to reverse and needs explicit architectural memory (ADR + tests + guardrails).
