# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Vox?

macOS dictation app: hotkey → record → STT (ElevenLabs) → LLM rewrite (Gemini/OpenRouter) → paste. Invisible editor that sits in menu bar.

## Commands

```bash
# Swift app
swift build                    # compile all targets
swift test                     # run unit tests
swift run VoxApp               # build + run app

# Single test
swift test --filter VoxAppTests.RewriteQualityGateTests/testMinimumRatioForLight

# Web apps (pnpm required)
pnpm install                   # install all workspace deps
pnpm dev:web                   # run marketing site (apps/web)
pnpm dev:gateway               # run API gateway (apps/gateway)
```

## Architecture

### Swift Package Structure

```
Sources/
├── VoxApp/          # App wiring + orchestration
│   ├── SessionController    # Hotkey toggle, state machine, UI signals
│   ├── DictationPipeline    # STT → rewrite, returns final text
│   ├── ProviderFactory      # Creates STT/rewrite providers from config
│   ├── GatewayClient        # HTTP client for gateway API
│   ├── Auth/
│   │   ├── AuthManager      # Token state, deep link, sign-out
│   │   └── KeychainHelper   # Secure storage (tokens + cache)
│   ├── Entitlement/
│   │   ├── EntitlementManager    # State machine + caching
│   │   ├── EntitlementCache      # Codable with TTL (4h/24h)
│   │   ├── PaywallView           # SwiftUI paywall UI
│   │   └── PaywallWindowController # AppKit host + polling
│   └── AppConfig/GeminiModelPolicy/OpenRouterModelPolicy
├── VoxCore/         # Contracts, errors, utilities
│   ├── Contracts    # STTProvider, RewriteProvider protocols
│   ├── ProcessingLevel (off|light|aggressive)
│   └── Errors (VoxError, RewriteError, STTError)
├── VoxMac/          # macOS integration
│   ├── AudioRecorder, ClipboardPaster, HUDController
│   └── HotkeyMonitor, PermissionManager, SecureInput
└── VoxProviders/    # Provider adapters (pure, no UI)
    ├── ElevenLabsSTTProvider
    ├── GeminiRewriteProvider
    └── OpenRouterRewriteProvider
```

### Monorepo Apps

- `apps/web` — Next.js marketing site
- `apps/gateway` — Next.js API gateway (Clerk auth, Stripe, Convex)

### Data Flow

1. Hotkey tap → start recording, capture target app
2. Hotkey tap → stop recording, run pipeline
3. STT returns raw transcript
4. LLM rewrites (or falls back to raw on failure)
5. Paste into target app via Cmd+V
6. Persist history artifacts (raw/rewrite/final + metadata)

### State Machines

**Session:** `idle` → `recording` → `processing` → `idle`

**Entitlement:** `unknown` | `entitled` | `gracePeriod` | `expired` | `unauthenticated` | `error`
- Optimistic caching: 4h soft TTL (background refresh), 24h hard TTL (block)
- `isAllowed` = O(1) check, never blocks hotkey

### Core Contracts

```swift
protocol STTProvider: Sendable {
    func transcribe(_ request: TranscriptionRequest) async throws -> Transcript
}

protocol RewriteProvider: Sendable {
    func rewrite(_ request: RewriteRequest) async throws -> RewriteResponse
}
```

Providers are pure adapters—no UI logic, no state.

### Processing Levels

| Level | Behavior |
|-------|----------|
| `off` | STT only, no LLM call |
| `light` | Punctuation, capitalization, remove obvious filler |
| `aggressive` | Clarify intent, can reorder, executive tone |

### Failure Policy

- STT fail → stop, no paste
- Rewrite fail → use raw transcript
- Paste fail → keep clipboard + show message
- Quality gate: if rewrite too short (ratio check), use raw

## Configuration

Precedence: `.env.local` > `~/Documents/Vox/config.json`

**Local mode** (no gateway):
- `ELEVENLABS_API_KEY`
- `GEMINI_API_KEY` (when `VOX_REWRITE_PROVIDER=gemini`)
- `OPENROUTER_API_KEY` + `OPENROUTER_MODEL_ID` (when `VOX_REWRITE_PROVIDER=openrouter`)

**Gateway mode** (production):
- `VOX_GATEWAY_URL` — gateway base URL (enables auth + entitlements)

## Quality Gates

Git hooks (auto-skip when no Swift changes):
```bash
git config core.hooksPath .githooks
```
- `pre-commit`: `swift build` (<5s)
- `pre-push`: `swift test` (<15s)

CI: GitHub Actions runs `swift build` + `swift test` on macOS runner.

Releases: Release Please on master, conventional commits drive SemVer.

## Conventions

- Swift 5.9, 4-space indent, no trailing whitespace
- Prefer typed errors (`VoxError`, `RewriteError`, `STTError`)
- Test naming: `testWhatItDoes`
- Commit prefixes: `feat:`, `fix:`, `docs:`, `test:`, `chore:`, `tune:`

### Swift Error Handling

**Avoid silent `try?` for observable failures.** When an operation fails, log before returning so failures are debuggable.

```swift
// BAD: Silent failure - impossible to debug
guard let result = try? riskyOperation() else { return }

// GOOD: Log error before early return
do {
    let result = try riskyOperation()
    // use result...
} catch {
    Diagnostics.error("Operation failed: \(String(describing: error))")
    return
}
```

**When `try?` is acceptable:**
- Truly optional operations (e.g., cache reads where fallback is fine)
- Cleanup code in defer blocks
- When you immediately handle the nil case with equivalent fallback

**Rule:** If a `try?` failure would make production debugging harder, use do-catch with `Diagnostics.error()` instead.
