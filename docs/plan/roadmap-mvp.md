# Roadmap — MVP

## Phase 0: Contracts and scaffolding
- Define core contracts + error taxonomy
- ADR candidates listed

## Phase 1: macOS capture + hotkey
- Toggle hotkey loop
- Mic capture to file
- Menu bar state feedback

## Phase 2: STT batch
- Submit recorded file to STT
- Receive raw transcript

## Phase 3: Rewrite + insert
- Rewrite integration
- Pasteboard restore insertion

## Phase 4: Reliability + metrics
- Timeout budgets enforced
- Telemetry counters
- Error UX polish

## Exit criteria
- End-to-end loop works in 5 target apps
- Long dictation (5+ min) succeeds without drops
- p95 release→insert within acceptable “seconds” range
- No crashes in a 30-minute session

## Risks + mitigations
- Latency spikes → raw transcript fallback
- Paste blocked apps → AX fallback + typing

## ADR candidates
- Provider abstraction contract v1
- Clipboard vs AX insertion priority
