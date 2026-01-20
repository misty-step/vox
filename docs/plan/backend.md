# Backend Plan (Later)

## Scope
- Not in prototype
- Auth/entitlement (thin, MVP can be device token)
- STT single-use token broker
- Rewrite proxy (Gemini)
- Remote config + provider routing
- Rate limiting + abuse prevention
- Metrics with redaction

## Endpoints
- POST /v1/stt/elevenlabs/token
  - returns token + expires_at
- POST /v1/rewrite
  - validates request
  - calls LLM provider
  - returns structured response
- GET /v1/config
  - provider routing + flags

## Provider adapters (server)
- Rewrite adapter: Gemini API → core rewrite response
- STT token adapter: ElevenLabs token minting
- Keep adapters thin, no policy logic

## Ops
- Keep connections warm (HTTP/2)
- Set hard timeouts and budgets
- Redact transcripts in logs by default
- Per-user rate limits to control cost
