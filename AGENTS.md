# Repository Guidelines

## Project Structure & Module Organization
`Vox` is a Swift Package Manager macOS app (`swift-tools-version: 5.9`, macOS 14+).

- `Sources/VoxCore`: core protocols, errors, decorators, shared utilities.
- `Sources/VoxProviders`: STT + rewrite providers (ElevenLabs, Deepgram, Whisper, Apple Speech, OpenRouter).
- `Sources/VoxMac`: macOS integrations (audio, keychain, permissions, hotkeys, paste, HUD).
- `Sources/VoxAppKit`: app orchestration and UI controllers (`VoxSession`, `DictationPipeline`, settings).
- `Sources/VoxApp`: executable entrypoint.
- `Tests/VoxCoreTests`, `Tests/VoxProvidersTests`, `Tests/VoxAppTests`: XCTest suites.
- `docs/`: architecture and ADRs (`docs/ARCHITECTURE.md`, `docs/adr/`).

## Build, Test, and Development Commands
- `swift build`: debug build.
- `swift build -c release`: optimized release build.
- `swift run Vox`: run app from package.
- `swift test`: run all tests.
- `swift build -Xswiftc -warnings-as-errors`: strict build (matches pre-push and CI).
- `swift test -Xswiftc -warnings-as-errors`: strict test run (matches CI).
- `./scripts/test-audio-guardrails.sh`: audio capture regression contract tests.
- `./scripts/run.sh`: launch debug binary with keys from `.env.local`.

## Coding Style & Naming Conventions
- Use idiomatic Swift with 4-space indentation and small focused types.
- Naming: `UpperCamelCase` for types, `lowerCamelCase` for methods/properties, enum cases in `lowerCamelCase`.
- Keep module boundaries clean: contracts in `VoxCore`, platform/network details in edge modules.
- Prefer composition/decorators over special-case branches for provider behavior.
- Keep logs consistent with existing bracket tags (example: `[Pipeline]`, `[STT]`, `[Vox]`).

## Testing Guidelines
- Framework: XCTest (`async` tests are standard where relevant).
- Test files end in `Tests.swift`; test methods follow behavior naming like `test_transcribe_retriesOnThrottledError`.
- Add/adjust tests in the corresponding module test target.
- Cover happy path plus retry/fallback/error paths for pipeline and provider changes.

## Commit & Pull Request Guidelines
- Follow existing Conventional Commit style seen in history: `feat(scope): ...`, `fix(security): ...`, `refactor(di): ...`, `docs: ...`.
- Keep commits focused; include issue/PR refs when available (example: `(#150)`).
- PRs should include:
- Clear problem/solution summary.
- Linked issue(s).
- Evidence of verification (`swift build -Xswiftc -warnings-as-errors` and `swift test -Xswiftc -warnings-as-errors`).
- Screenshots/GIFs for UI changes (HUD, menu bar, settings).

## Security & Configuration Tips
- Never commit secrets. Use `.env.local` for local runs and Keychain-backed settings for persisted keys.
- Expected env vars: `ELEVENLABS_API_KEY`, `OPENROUTER_API_KEY`, optional `DEEPGRAM_API_KEY`, `OPENAI_API_KEY`.
