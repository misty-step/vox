## Summary

- Problem:
- Solution:

## Verification

- [ ] `swift build -Xswiftc -warnings-as-errors`
- [ ] `swift test -Xswiftc -warnings-as-errors`

## Guardrails

- [ ] Docs updated for behavior/interface changes (`README`, `docs/ARCHITECTURE.md`, ADRs, or postmortem when relevant)
- [ ] If audio capture/conversion changed, `AudioRecorderConversionTests` were updated/validated (16k/24k/44.1k/48k coverage + underflow guard behavior)
- [ ] Simplicity gate checked ([ADR-0001](docs/adr/0001-simplicity-first-design.md)): no unnecessary user-facing settings
