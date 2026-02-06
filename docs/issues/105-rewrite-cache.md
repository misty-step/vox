# Issue #105: Rewrite Latency Optimization

## Product Spec

### Problem
Rewrite adds a full network round-trip after STT. Repeated short phrases from the same user session pay the same rewrite latency each time.

### Goal
Reduce end-to-end dictation latency for repeated transcripts without changing user-visible settings.

### Non-Goals
- No new UI controls.
- No persistent on-disk transcript cache.
- No change to STT fallback logic.

### Scope
- Cache accepted rewrite outputs in memory, keyed by transcript + processing level + model.
- Use bounded size + TTL eviction to limit memory growth.
- Keep cache internal and automatic.

### Success Criteria
- Second processing of identical transcript (same level/model) avoids rewrite provider call.
- Existing rewrite fallback behavior stays unchanged.
- Strict build/tests pass.

## Technical Design

### Design Summary
- Add `RewriteResultCache` actor in `VoxAppKit`.
- `DictationPipeline` consults cache before calling `RewriteProvider`.
- Cache only stores quality-gate-accepted rewrite output.
- Cache enabled explicitly by `VoxSession` (`enableRewriteCache: true`).

### Module Boundaries
- `RewriteResultCache`: internal cache policy and eviction details.
- `DictationPipeline`: orchestration only (lookup/store around existing rewrite path).
- `VoxSession`: feature toggle point for app runtime behavior.

### Cache Policy
- Max entries: 128.
- TTL: 600 seconds.
- Max transcript/result length: 1,024 chars (long transcripts bypass cache).
- Eviction: remove oldest entry when at capacity.

### Risk Controls
- Cache disabled by default in `DictationPipeline` initializer, enabled only in app wiring.
- No transcript content logged.
- Non-acceptable rewrite candidates are never cached.
- Rewrite failures continue to fall back to raw transcript.

### Test Plan
- `process_rewriteCacheHit_skipsSecondRewriteCall`
- `process_rewriteCache_levelChange_missesCache`
- Full strict build/test run to guard regressions.
