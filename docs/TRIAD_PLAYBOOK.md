# Triad Playbook

`Vox` optimizes a three-way balance:

- `quality`: output correctness, readability, reliability
- `simplicity`: low user complexity and low config burden
- `speed`: low latency and fast perceived response

Every issue and PR must explicitly state intended impact across all three.

## Label Contract

Use exactly one label from each axis:

- `quality:+` or `quality:0` or `quality:-`
- `simplicity:+` or `simplicity:0` or `simplicity:-`
- `speed:+` or `speed:0` or `speed:-`

Use exactly one class label:

- `triad:no-brainer`: positive or neutral net effect with no meaningful downside
- `triad:tradeoff`: intentional downside on at least one axis

## Issue Body Contract

Every issue includes:

1. `Triad Hypothesis`
2. `Tradeoff Justification` (required when `triad:tradeoff`)
3. `Latency Budget` (required when critical path might be touched)

## Decision Rules

1. If two options have similar quality, pick the faster one.
2. If two options have similar speed, pick the simpler one.
3. Never add user-facing config unless it removes more complexity than it introduces.
4. Expensive context work must run off critical path or degrade gracefully.
5. Local-first storage is default for transcripts, rewrites, and correction memory.

## Local History Guardrails

1. Keep history bounded by hard byte limits.
2. Evict old raw entries via LRU/ring buffer.
3. Summarize stale history into compact artifacts.
4. Keep correction-memory retrieval non-blocking for rewrite execution.

## Privacy Defaults

1. Transcript and correction data stay local by default.
2. No remote transcript persistence without explicit opt-in.
3. Provide clear controls: enable/disable history, retention period, clear-all.
