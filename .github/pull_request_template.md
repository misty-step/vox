## Summary

- Problem:
- Solution:

## Verification

- [ ] `swift build -Xswiftc -warnings-as-errors`
- [ ] `swift test -Xswiftc -warnings-as-errors`

## Guardrails

- [ ] Docs updated for behavior/interface changes (`README`, `docs/ARCHITECTURE.md`, ADRs, or postmortem when relevant)
- [ ] If audio capture/conversion changed, `AudioRecorderBackendSelectionTests`, `AudioRecorderConversionTests`, `CapturedAudioInspectorTests`, and `VoxError.emptyCapture` fast-fail coverage in `DictationPipelineTests` were updated/validated
- [ ] Simplicity gate checked ([ADR-0001](docs/adr/0001-simplicity-first-design.md)): no unnecessary user-facing settings
