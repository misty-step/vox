# 0001 — Core Module Boundaries

Date: 2026-01-20

Status: accepted

## Context
We need deep modules, simple interfaces, and easy provider swaps.

## Decision
Split into four modules:
- `VoxCore`: contracts + errors + small utilities
- `VoxProviders`: STT + LLM adapters
- `VoxMac`: macOS integrations
- `VoxApp`: app wiring + orchestration

## Consequences
- Providers stay swappable
- OS details stay out of core logic
- App code stays thin and readable
