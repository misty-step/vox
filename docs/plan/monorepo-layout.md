# Monorepo Layout

Goal: single repo, clear seams, minimal coupling.

```
.
├── Sources/                # Swift package (macOS app)
├── Tests/                  # Swift tests
├── apps/
│   ├── web/                # Marketing + download + checkout UI (Next.js)
│   └── gateway/            # API gateway + webhooks (Next.js, Node runtime)
├── packages/
│   └── shared/             # Shared TS types/utilities (future)
└── docs/
    ├── adr/                # Architecture decisions
    └── plan/               # Planning packet
```

Routing boundaries:
- macOS app talks only to gateway.
- gateway talks to providers, Convex, Stripe, Clerk.
- web talks to gateway for checkout + activation.

Data boundaries:
- Audio never stored by default.
- Entitlements + usage live in Convex.
