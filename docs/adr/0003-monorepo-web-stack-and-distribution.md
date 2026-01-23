# 0003 — Monorepo, Web Stack, and Distribution

Date: 2026-01-21

Status: accepted

## Context
We need a backend gateway, billing, and a marketing site. Team already ships on Vercel with Next.js, Convex, Clerk, Stripe. Audio payloads are large and should not be proxied through serverless limits. Distribution path is undecided.

## Decision
- Keep a single monorepo. Swift package stays at repo root; web apps live under `apps/`.
- Use Vercel + Next.js (Node runtime) for gateway + marketing.
- Use Convex for entitlements/usage/config storage.
- Use Clerk for auth, Stripe for billing.
- Gateway mints short‑lived provider tokens; audio uploads go direct to provider.
- Distribute outside the Mac App Store first: DMG + activation token. Revisit App Store later.

## Consequences
- CI must be path‑aware (macOS vs web). Vercel projects per app.
- Backend stays thin; policy in gateway, data in Convex.
- Direct distribution needs notarization, auto‑update, and license activation UX.
- App Store path later adds sandbox/IAP constraints and review overhead.
