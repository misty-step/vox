# Quality Controls

## Local hooks
- `pre-commit`: `swift build`
- `pre-push`: `swift test`
- Hooks live in `.githooks/` and are set via `core.hooksPath`
  - `git config core.hooksPath .githooks`

## CI
- GitHub Actions on `push` and `pull_request`
- macOS runner
- `swift build`, `swift test`

## Testing scope
- Unit tests for parsing and normalization
- Provider adapters tested via pure functions only
- Network calls are not mocked yet
