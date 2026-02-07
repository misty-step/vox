# ADR-0002: Session Extension Seam for Wrappers

## Status

Accepted

## Context

`VoxSession` owns the recording lifecycle and currently hard-codes all side effects in one flow. External wrappers need to add authorization, metering, and sync behavior without forking this orchestration code.

Without an explicit seam, wrappers must either:
- patch `VoxSession` directly (high drift risk), or
- duplicate the session flow (behavior divergence risk).

We need a small interface that keeps session internals private while allowing wrapper-specific policies.

## Decision

Introduce a session-level extension contract in `VoxCore`:
- `SessionExtension` protocol with three async hooks:
  - `authorizeRecordingStart()`
  - `didCompleteDictation(event:)`
  - `didFailDictation(reason:)`
- `DictationUsageEvent` payload with only stable metadata:
  - recording duration
  - output character count
  - processing level
- `NoopSessionExtension` default implementation.

`VoxSession` now accepts an optional `sessionExtension` dependency and invokes hooks from the existing lifecycle.

## Consequences

### Positive

- Wrappers can add auth/billing/sync behavior without replacing `VoxSession`.
- Session internals stay hidden behind one small interface.
- Open source default behavior remains unchanged.

### Negative

- `VoxSession` has one more injected dependency.
- Hook ordering is now a contract that must remain stable across refactors.

### Neutral

- No user-visible settings or UI changes.
- No changes to STT provider chaining or rewrite behavior.

## Alternatives Considered

### Alternative 1: Subclass `VoxSession`

Rejected because lifecycle logic is not designed for inheritance; override points would leak internals and increase coupling.

### Alternative 2: Add dedicated auth/billing/sync modules now

Rejected because it introduces product-specific surface area into OSS before concrete requirements exist.
