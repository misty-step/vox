# Repository Guidelines

## Project Structure & Module Organization
- `Sources/` contains Swift package modules:
  - `VoxApp` (app wiring + orchestration)
  - `VoxCore` (contracts, errors, utilities)
  - `VoxMac` (macOS integration: audio, hotkeys, HUD, clipboard)
  - `VoxProviders` (STT/LLM provider adapters)
- `Tests/` holds `XCTest` suites per module (e.g., `Tests/VoxCoreTests`).
- `docs/` holds product/architecture notes and ADRs.

## Build, Test, and Development Commands
- `swift run VoxApp` — build + run the macOS app.
- `swift build` — compile all targets.
- `swift test` — run unit tests.
- Optional hooks: `git config core.hooksPath .githooks` (see README).

## Coding Style & Naming Conventions
- Swift 5.9, 4‑space indentation, no trailing whitespace.
- Prefer small, deep modules with narrow interfaces.
- Types: `UpperCamelCase`, methods/vars: `lowerCamelCase`.
- Errors: prefer typed errors (`VoxError`, `RewriteError`, `STTError`).
- Avoid “Manager/Helper/Util” names unless unavoidable.

## Testing Guidelines
- Framework: `XCTest`.
- New logic should include focused unit tests.
- Naming: `testWhatItDoes` (e.g., `testRewriteDefaultsToLight`).
- Run with `swift test` before PR.

## Commit & Pull Request Guidelines
- Commit prefixes seen in repo: `feat:`, `fix:`, `docs:`, `test:`, `chore:`, `tune:`.
- Keep commits scoped and meaningful.
- PRs should include: summary, tests run, and any config changes.
- Link related issues when applicable.

## Security & Configuration
- **Do not commit secrets.**
- Local config: `.env.local` (preferred) or `~/Documents/Vox/config.json`.
- Processing level defaults to `light`. Legacy env var: `VOX_REWRITE_LEVEL`.
- Use `VOX_DEBUG_ALERTS=1` for alert-based debugging.

## Architecture References
- `docs/architecture.md` and `docs/plan/` are source‑of‑truth for design intent.
