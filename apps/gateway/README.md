# Gateway (Next.js)

Tracer‑bullet API for Vox gateway.

## Endpoints
- `GET /v1/health`
- `GET /v1/config`
- `GET /v1/entitlements` (requires `Bearer` token)
- `POST /v1/stt/token` (requires `Bearer` token)
- `POST /v1/rewrite` (stub)
- `POST /api/stripe/webhook` (stub)

## Env
- `VOX_TEST_TOKEN` — shared test token for auth guard
- `VOX_STT_PROVIDER_TOKEN` — placeholder STT token
- `STRIPE_WEBHOOK_SECRET` — used when webhook verification is added
