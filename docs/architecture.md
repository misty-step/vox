# Architecture

## Goal
- Hotkey → record → transcribe → rewrite → paste
- Few moving parts, deep modules, clear seams

## Module map
- `VoxApp`: app wiring + orchestration
  - `SessionController`: hotkey toggle, state, UI signals
  - `DictationPipeline`: STT → rewrite, returns final text
  - `VoxGateway`: deep module for gateway API calls + auth header injection
  - `Auth/`
    - `AuthManager`: token state, deep link handling, sign-out
    - `KeychainHelper`: secure storage for tokens and cache
  - `Entitlement/`
    - `EntitlementManager`: state machine with optimistic caching
    - `EntitlementCache`: Codable cache with TTL (4h soft, 24h hard)
    - `PaywallView`: SwiftUI paywall for unauthenticated/expired states
    - `PaywallWindowController`: AppKit host + polling for auth/payment
- `VoxMac`: macOS integration
  - `AudioRecorder`: mic → file
  - `ClipboardPaster`: copy + paste + restore
  - `HUDController`/`HUDView`: feedback UI
  - `HotkeyMonitor`, `PermissionManager`
- `VoxProviders`: provider adapters
  - `ElevenLabsSTTProvider`
  - `GeminiRewriteProvider`
  - `OpenRouterRewriteProvider`
- `VoxCore`: contracts + errors + utilities

## Data flow
1. Hotkey tap: start recording, capture target app
2. Hotkey tap: stop recording, run pipeline
3. STT returns raw transcript
4. LLM rewrites transcript (fallback to raw on failure)
5. Paste into target app, keep clipboard for manual paste
6. Persist session artifacts (raw/rewrite/final + metadata)

## State model

### Session state
- `idle` → `recording` → `processing` → `idle`
- UI is driven by state + status messages

### Entitlement state
- `unknown` → initial, optimistic if authenticated
- `entitled(cache)` → valid subscription, cache fresh
- `gracePeriod(cache)` → cache stale (4h+), background refresh
- `expired` → subscription ended, paywall shown
- `unauthenticated` → no token, sign-in required
- `error(message)` → network failure with no valid cache

## Core contracts
- `TranscriptionRequest` → `Transcript`
- `RewriteRequest` → `RewriteResponse`
- Providers are pure adapters with no UI logic

## Clipboard policy
- Always write to pasteboard
- Attempt Cmd+V paste
- Keep clipboard for `VOX_CLIPBOARD_HOLD_MS` (default 120s)

## Failure policy
- STT fail: stop, log, no paste
- Rewrite fail: use raw transcript
- Paste fail: keep clipboard + show message
- Always write session history artifacts for recovery

## Config
- `.env.local` overrides, else `~/Documents/Vox/config.json`
- No UI config in prototype

## Auth flow
1. User clicks "Sign In" in paywall → opens `/auth/desktop` in browser
2. Web app authenticates via Clerk, redirects to `vox://auth?token=...`
3. `AuthManager.handleDeepLink()` saves token to Keychain
4. `EntitlementManager` observes auth change, fetches entitlements
5. If entitled, paywall closes automatically (polling)

## Entitlement enforcement
- `SessionController.toggle()` checks `EntitlementManager.isAllowed`
- If blocked, shows paywall via `entitlementBlocked` callback
- Gateway also enforces entitlements on STT and rewrite endpoints

## Security
- Auth tokens stored in macOS Keychain (`com.vox.auth`)
- Entitlement cache also in Keychain (prevents tampering)
- Gateway validates tokens via Clerk JWT verification
- Production uses gateway for all API calls (no local keys)
