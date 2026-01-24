# Gateway (Next.js)

API gateway for Vox: auth, entitlements, STT proxy, billing.

## Endpoints

### Health & Config
- `GET /v1/health` — liveness check
- `GET /v1/config` — client configuration

### Auth-Protected (requires `Bearer` token)
- `GET /v1/entitlements` — fetch user plan, status, features
- `POST /v1/stt/token` — get short-lived STT provider token
- `POST /v1/rewrite` — proxy rewrite request to LLM

### Stripe Billing
- `GET /api/stripe/checkout` — redirect to Stripe Checkout
- `GET /api/stripe/portal` — redirect to Stripe Customer Portal
- `POST /api/stripe/webhook` — handle Stripe events (subscription updates)

## Env
- `CLERK_SECRET_KEY` — Clerk JWT verification
- `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` — Clerk frontend key
- `STRIPE_SECRET_KEY` — Stripe API key
- `STRIPE_WEBHOOK_SECRET` — Stripe webhook signature verification
- `CONVEX_URL` — Convex database URL
- `VOX_STT_PROVIDER_TOKEN` — ElevenLabs API key for STT proxy
- `VOX_TEST_TOKEN` — dev-only test token (bypasses Clerk in dev)

## Auth Flow
1. Desktop app opens `/auth/desktop` on web app
2. Web app authenticates via Clerk
3. On success, redirects to `vox://auth?token=<jwt>`
4. Gateway validates JWT on protected endpoints via Clerk
