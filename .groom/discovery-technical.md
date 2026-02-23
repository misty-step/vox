# Technical Archaeology — 2026-02-23

## Hotspots

### VoxSession (1130 LOC)
- StreamingAudioBridge (@unchecked Sendable, NSLock, 100+ LOC) — embedded at EOF
- StreamingSessionPump (actor, 100+ LOC) — embedded at EOF
- Provider assembly logic duplicates ProviderAssembly.swift

### AudioRecorder (685 LOC)
- Both AVAudioEngine and AVAudioRecorder paths in one class
- 3 NSLocks guarding independent concerns

## Silent Error Swallowing
- SecureFileDeleter: swallows all failures except ENOENT with a print()
  - Used 8x across pipeline — if delete fails, plaintext audio leaks
- PerformanceIngestClient: fire-and-forget, no retry/backoff

## Under-Tested Critical Paths
- DictationPipeline: 3 test methods for 502 LOC implementation
  - Missing: stage timeouts, cache hit/miss/eviction, concurrent calls
- VoxSession: 19 tests vs 1130 LOC
  - Missing: streaming bridge cancellation during drain, teardown edge cases

## Leaky Abstractions
- macOS 26+ availability gating leaks into VoxSession call sites — should be in ProviderAssembly factory
- PreferencesStore.shared used directly in AppDelegate, DiagnosticsStore, DictationPipeline — bypasses DI

## Priority Fixes (by severity)
1. SecureFileDeleter: add throwing variant, propagate errors (Medium, security-adjacent)
2. Extract StreamingAudioBridge + StreamingSessionPump to separate files (Medium, maintenance)
3. DictationPipeline test coverage: stage timeouts, cache, concurrency (Medium)
4. Availability gating abstraction in ProviderAssembly (Low)
5. PreferencesStore.shared audit (Low)
