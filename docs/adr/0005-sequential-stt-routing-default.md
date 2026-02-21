# ADR-0005: Sequential STT Routing Default

## Status

Accepted

## Context

Vox supports two STT routing strategies:

- **Hedged (parallel)**: races multiple providers simultaneously with stagger delays, returning the first successful result. Lower worst-case latency but higher API cost and complexity.
- **Sequential (fallback)**: tries providers in order, falling back only on failure. Simpler, cheaper, but worst-case latency is the sum of all provider timeouts.

The hedged strategy was implemented first (#138) as a latency optimization. However, production experience showed:

1. ElevenLabs and Deepgram rarely both fail — sequential fallback covers the common case.
2. Hedged routing doubles API costs for every transcription (both providers always called).
3. The stagger delay tuning is sensitive to network conditions and hard to get right.
4. Sequential routing is easier to reason about in logs and diagnostics.

## Decision

Make sequential fallback the default STT routing strategy. Retain hedged routing as an opt-in via `VOX_STT_ROUTING=hedged` for users who prefer latency over cost.

Default chain: ElevenLabs(Timeout+Retry) -> Deepgram(Timeout+Retry) -> Apple Speech (on-device).

## Consequences

### Positive

- Halved API costs for typical transcriptions (only one cloud provider called).
- Simpler debugging — provider execution order is deterministic.
- Apple Speech fallback provides offline resilience at the end of the chain.

### Negative

- Worst-case latency is higher when the primary provider times out before fallback.
- Users must opt in to hedged routing to get parallel-race latency benefits.

### Neutral

- `HedgedSTTProvider` and `HealthAwareSTTProvider` remain in the codebase for opt-in use.
- `ConcurrencyLimitedSTTProvider` wraps the entire chain regardless of routing strategy.
