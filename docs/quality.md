# Quality Controls

## Local hooks
- `pre-commit`: `swift build` (skips if no staged Swift/Package changes)
- `pre-push`: `swift test` (skips if no Swift/Package changes since upstream)
- SLA: pre-commit <5s, pre-push <15s
- Hooks live in `.githooks/` and are set via `core.hooksPath`
  - `git config core.hooksPath .githooks`

## CI
- GitHub Actions on `push` and `pull_request`
- macOS runner
- Cache: `.build`, `~/.swiftpm`, `~/Library/Caches/org.swift.swiftpm`
- Secrets scan: Gitleaks (requires `GITLEAKS_LICENSE` secret; otherwise skipped)
- `swift build`, `swift test`

## Testing scope
- Unit tests for parsing and normalization
- Provider adapters tested via pure functions only
- Network calls are not mocked yet

## Gaps / follow-ups
- Coverage reporting + delta thresholds
- Lint/format automation (SwiftFormat/SwiftLint)
- Release automation + changelog
