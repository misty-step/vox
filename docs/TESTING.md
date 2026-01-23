# Vox Testing & QA Guide

## Automated Tests

### Running All Tests

```bash
# Swift tests (32 unit tests)
swift test

# Gateway API tests (18 tests)
pnpm test:gateway

# All TypeScript tests
pnpm test

# Full CI simulation
swift build && swift test && pnpm build && pnpm test && pnpm lint
```

### Test Coverage

| Component | Tests | Coverage |
|-----------|-------|----------|
| Swift App | 32 unit tests | Core business logic, model policies, provider selection |
| Gateway | 18 API tests | All endpoints, auth, error handling |
| Web | 0 | Static marketing site (visual QA only) |

### CI Quality Gates

The GitHub Actions CI runs on every push/PR:

1. **secrets** - TruffleHog scans for leaked credentials
2. **swift** - Build and test the macOS app
3. **gateway** - Typecheck, lint, test, and build the API
4. **web** - Lint and build the marketing site

All jobs must pass before merging.

---

## Manual QA Procedures

### Prerequisites

```bash
# Ensure you're on the correct branch
git checkout chore/monorepo-tracer

# Install dependencies
pnpm install

# Create local env files (copy from examples)
cp apps/gateway/.env.example apps/gateway/.env.local
# Edit .env.local with your API keys
```

### 1. Gateway Health Check

```bash
# Start gateway in one terminal
cd apps/gateway && pnpm dev

# In another terminal, run smoke tests
./scripts/smoke-test.sh
```

Expected output:
```
🔍 Vox Gateway Smoke Tests
==========================
Testing Health (no auth)...                ✓ 200
Testing Config...                          ✓ 200
Testing Entitlements (no auth)...          ✓ 401 (correctly rejected)
Testing Entitlements (authed)...           ✓ 200
Testing STT Token...                       ✓ 200
Testing Rewrite (light)...                 ✓ 200
==========================
✓ All smoke tests passed!
```

### 2. Marketing Site Visual QA

```bash
cd apps/web && pnpm dev
# Open http://localhost:3001
```

**Checklist:**
- [ ] Hero section displays correctly
- [ ] "Download for macOS" button visible
- [ ] "Join the private beta" button visible
- [ ] Feature grid (4 panels) renders
- [ ] Footer with macOS 13+ notice visible
- [ ] Responsive: Test at 375px, 768px, 1024px, 1440px widths
- [ ] Dark mode: Check system preference is respected (if implemented)

### 3. Gateway API Manual Testing

**Health endpoint:**
```bash
curl http://localhost:3000/v1/health | jq
# Expected: {"ok":true,"service":"vox-gateway","time":"..."}
```

**Config endpoint:**
```bash
curl http://localhost:3000/v1/config | jq
# Expected: {stt: {provider: "elevenlabs", directUpload: true}, ...}
```

**Entitlements (requires auth):**
```bash
curl -H "Authorization: Bearer $VOX_TEST_TOKEN" \
  http://localhost:3000/v1/entitlements | jq
# Expected: {subject, plan, status, features, currentPeriodEnd}
```

**STT Token:**
```bash
curl -X POST -H "Authorization: Bearer $VOX_TEST_TOKEN" \
  http://localhost:3000/v1/stt/token | jq
# Expected: {token: "...", provider: "elevenlabs", expiresAt: "..."}
```

**Rewrite (light mode):**
```bash
curl -X POST http://localhost:3000/v1/rewrite \
  -H "Authorization: Bearer $VOX_TEST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "manual-test",
    "locale": "en",
    "transcript": {"text": "um so I was thinking like maybe we should uh add a button"},
    "context": "",
    "processingLevel": "light"
  }' | jq
# Expected: {finalText: "I was thinking maybe we should add a button", ...}
```

**Rewrite (aggressive mode):**
```bash
curl -X POST http://localhost:3000/v1/rewrite \
  -H "Authorization: Bearer $VOX_TEST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "manual-test-2",
    "locale": "en",
    "transcript": {"text": "okay so basically what I want is for the user to be able to like click a button and then it saves their data you know"},
    "context": "Building a save feature",
    "processingLevel": "aggressive"
  }' | jq
# Expected: Concise, polished text that preserves intent
```

### 4. Desktop App + Gateway Integration

**Setup:**
```bash
# In apps/gateway
pnpm dev

# In project root, set env vars
export VOX_GATEWAY_URL=http://localhost:3000
export VOX_GATEWAY_TOKEN=$VOX_TEST_TOKEN

# Build and run the app
swift build
.build/debug/VoxApp
```

**Test flow:**
1. Open VoxApp
2. Trigger a recording (hotkey)
3. Speak: "Hello this is a test of the gateway integration"
4. Verify:
   - Audio is transcribed via gateway STT token
   - Text is rewritten via gateway rewrite endpoint
   - Final text appears at cursor

### 5. Stripe Checkout Flow (Staging)

**Prerequisites:**
- Stripe test mode enabled
- Webhook configured to gateway URL
- Products created (`prod_Tq7SJRsTTdXb4c`)

**Test:**
1. Go to marketing site checkout page (when implemented)
2. Click "Subscribe to Pro"
3. Complete Stripe Checkout with test card: `4242 4242 4242 4242`
4. Verify webhook received at `/api/stripe/webhook`
5. Check Convex dashboard for updated entitlement

---

## Environment Variables Checklist

### Gateway (`apps/gateway/.env.local`)

| Variable | Required | Description |
|----------|----------|-------------|
| `VOX_TEST_TOKEN` | Dev only | Static token for local testing |
| `CLERK_SECRET_KEY` | Yes | Clerk backend secret |
| `CLERK_PUBLISHABLE_KEY` | Yes | Clerk frontend key |
| `CONVEX_URL` | Yes | Convex deployment URL |
| `STRIPE_SECRET_KEY` | Yes | Stripe API key |
| `STRIPE_WEBHOOK_SECRET` | Yes | Webhook signing secret |
| `ELEVENLABS_API_KEY` | Yes | ElevenLabs STT key |
| `GEMINI_API_KEY` | Yes | Google Gemini key |
| `GEMINI_MODEL_ID` | No | Default: gemini-2.0-flash |

### Desktop App (environment or .env.local)

| Variable | Required | Description |
|----------|----------|-------------|
| `VOX_GATEWAY_URL` | For gateway mode | Gateway base URL |
| `VOX_GATEWAY_TOKEN` | For gateway mode | Auth token |

---

## Troubleshooting

### Gateway returns 401 Unauthorized
- Check `Authorization: Bearer <token>` header is present
- Verify `VOX_TEST_TOKEN` is set in gateway .env.local
- For production: Ensure Clerk JWT is valid

### Gateway returns 502 Bad Gateway
- Check API keys are set (GEMINI_API_KEY, ELEVENLABS_API_KEY)
- Verify external services are reachable
- Check gateway logs for detailed error

### Swift build fails
- Run `swift package resolve` to update dependencies
- Delete `.build` folder and rebuild

### Desktop app not using gateway
- Verify `VOX_GATEWAY_URL` is set and not empty
- Check URL includes scheme (`http://` or `https://`)
- Verify `VOX_GATEWAY_TOKEN` is set
