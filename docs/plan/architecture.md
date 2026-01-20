# Architecture

## Components
- macOS app
  - Hotkey listener
  - Mic capture to file
  - STT adapter
  - Context loader (optional)
  - Rewrite client
  - Text insertion
- Direct provider calls (prototype)

## Data flow (submit path)
- Stop recording
- Send audio file to STT
- Receive raw transcript
- Send transcript to LLM rewrite
- Paste rewritten text

## Core contracts (stable)

### Canonical transcript
- session id
- text
- language (optional)

### Rewrite request
- session id
- locale
- transcript (canonical)
- context snapshot (raw string)

### Rewrite response
- final text only

### Error taxonomy
- transport: network, timeout
- provider: auth, quota, throttled, invalid request
- user: permission denied, no mic, no focus

## Provider modularity
- Providers map to core contracts
- Business logic lives outside adapters
- Swap providers by instantiating a different adapter
