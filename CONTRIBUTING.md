# Contributing to Vox

Thanks for your interest in Vox. This guide covers everything you need to get started.

## Prerequisites

- macOS 14 (Sonoma) or later
- Swift 5.9+ (included with Xcode 15+)
- Git

## Setup

```bash
git clone https://github.com/misty-step/vox.git
cd vox
git config core.hooksPath .githooks
swift build
```

The pre-push hook enforces warnings-as-errors builds — same check CI runs.

## Building and Testing

```bash
swift build                                    # Debug build
swift build -c release                         # Release build
swift build -Xswiftc -warnings-as-errors       # Strict build (matches CI)
swift test                                     # Run all tests
swift test --filter VoxCoreTests               # Run one test target
swift test --filter RetryingSTTProviderTests    # Run one test class
```

To run the app locally with API keys:

```bash
cp .env.example .env.local  # Add your keys
./scripts/run.sh
```

## Project Structure

Five SwiftPM targets with a strict dependency hierarchy:

```
VoxCore       → Protocols, errors, decorators (no dependencies)
VoxProviders  → STT clients + OpenRouter rewriting (depends: VoxCore)
VoxMac        → macOS integrations: audio, keychain, HUD, hotkeys (depends: VoxCore)
VoxAppKit     → Session, pipeline, settings, UI controllers (depends: all above)
VoxApp        → Executable entry point — just main.swift (depends: VoxAppKit)
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full architecture overview.

## Code Style

- Idiomatic Swift, 4-space indentation
- `UpperCamelCase` types, `lowerCamelCase` methods/properties/enum cases
- Composition and decorators over special-case branches
- Bracket-prefixed log tags: `[ElevenLabs]`, `[STT]`, `[Pipeline]`, `[Vox]`
- No transcript content in logs — character counts only

## Testing

XCTest with async tests. Test method naming: `test_methodName_behaviorWhenCondition`.

Cover happy path plus retry/fallback/error paths. Add tests in the corresponding module test target:

- `Tests/VoxCoreTests/` — decorators, error classification, quality gate
- `Tests/VoxProvidersTests/` — client request format, file size limits
- `Tests/VoxAppTests/` — DI contract verification

## Commits

[Conventional Commits](https://www.conventionalcommits.org/) format:

```
feat(scope): add new capability
fix(security): resolve vulnerability
refactor(di): improve dependency injection
docs: update architecture overview
```

Keep commits focused. Reference issues when applicable: `feat(stt): add Opus compression (#137)`.

## Pull Requests

1. Fork the repository
2. Create a feature branch (`feat/`, `fix/`, `refactor/`, `docs/`)
3. Make your changes
4. Verify: `swift build -Xswiftc -warnings-as-errors && swift test -Xswiftc -warnings-as-errors`
5. Submit a pull request

PRs should include:
- Clear problem/solution summary
- Linked issue(s)
- Evidence that build and tests pass
- Screenshots or GIFs for UI changes (HUD, menu bar, settings)

### Simplicity Checklist

Before submitting, verify your PR passes the simplicity gate (see [ADR-0001](docs/adr/0001-simplicity-first-design.md)):

- [ ] No new user-visible settings without explicit justification
- [ ] No "Advanced" UI, threshold tuning, or model selection exposed to users
- [ ] New behavior uses sensible defaults rather than asking users to configure
- [ ] No dark features (stored preferences without a UI path)

## Filing Issues

Check existing issues first. When filing:
- Bug reports: steps to reproduce, expected vs actual behavior, macOS version
- Feature requests: describe the problem you're solving, not just the solution
- Every new feature must justify its complexity cost — Vox wins by being simple

## Architecture Decisions

Significant architectural changes should include an ADR (Architecture Decision Record). See [docs/adr/](docs/adr/) for the template and process.

## Security

- Never commit secrets — use `.env.local` for local runs
- Report security vulnerabilities privately via GitHub Security Advisories
