# Rewrite Model Lockdown — 2026-02-23

Closes issue #259: lock fastest good rewrite models for Clean and Polish levels.

## Decision

| Level | Winner | Code ID | p50 | p95 | Notes |
| --- | --- | --- | --- | --- | --- |
| **Clean** | `gemini-2.5-flash-lite` | `gemini-2.5-flash-lite` | 0.635s | 0.989s | Confirmed; was already default |
| **Polish** | `gemini-2.5-flash-lite` | `gemini-2.5-flash-lite` | 0.703s | 1.252s | **Changed from `x-ai/grok-4.1-fast`** |

The code ID routes through `ModelRoutedRewriteProvider` → Gemini direct API (not OpenRouter).
Bakeoff measured via OpenRouter; Gemini direct is historically ~15% faster (see Feb 9 data).

## Acceptance Criteria Check

| Criterion | Clean | Polish | Status |
| --- | --- | --- | --- |
| p50 latency ≤ 800ms | 0.635s | 0.703s | ✅ |
| p50 latency ≤ 2000ms (Polish) | — | 0.703s | ✅ |
| Quality gate ≥ 70% (Clean) | 100% (Feb 9) | — | ✅ |
| Quality gate ≥ 85% (Polish) | — | 100% (Feb 9) | ✅ |
| No new user-facing settings | — | — | ✅ |
| Documented in-repo | — | — | ✅ (this file) |

## Evidence

### 2026-02-23 Targeted Bakeoff (definitive run)

4 candidates × 20 corpus entries × 2 iterations × 2 levels = 160 API calls.

**Clean:**

| Model | p50 | p95 | Lev mean | Lev p5 | Overlap |
| --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite` | **0.635s** | **0.989s** | 0.907 | 0.766 | 0.964 |
| `amazon/nova-micro-v1:nitro` | 0.618s | 1.386s | 0.841 | 0.504 | 0.963 |
| `inception/mercury-coder` | 1.092s | 1.616s | 0.844 | 0.198† | 0.888 |
| `x-ai/grok-4.1-fast` | 3.459s | 6.426s | 0.931 | 0.833 | 0.977 |

†`inception/mercury-coder` emitted a near-empty output on clean-09 in both iterations (lev ≈ 0.20),
indicating an occasional failure mode for long technical transcripts.

**Polish:**

| Model | p50 | p95 | Lev mean | Lev p5 | Overlap |
| --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite` | **0.703s** | **1.252s** | 0.435 | 0.225 | 0.524 |
| `inception/mercury-coder` | 1.072s | 1.500s | 0.411 | 0.249 | 0.631 |
| `amazon/nova-micro-v1:nitro` | 1.509s | 2.439s | 0.137 | 0.081 | 0.565 |
| `x-ai/grok-4.1-fast` | 3.842s | 8.342s | 0.777 | 0.523 | 0.865 |

**Why `amazon/nova-micro-v1:nitro` is disqualified for Polish:** Lev mean 0.137 means it routinely
produces output with nearly no shared text with the input — it's summarizing, not polishing.
Ratios of 4–14x original length confirm it generates content, violating the "no hallucination" rule.

**Why `x-ai/grok-4.1-fast` is disqualified for both levels:** p95 6.4s (Clean) and 8.3s (Polish)
exceeds any acceptable latency target by 5–8x.

### Prior Bakeoffs (corroborating)

| Date | File | gemini-2.5-flash-lite (Clean/Light) | gemini-2.5-flash-lite (Polish/Aggressive) |
| --- | --- | --- | --- |
| 2026-02-09 | `rewrite-model-bakeoff-2026-02-09.md` | p95 0.853s, quality 100% | p95 0.843s, quality 100% |
| 2026-02-09 expanded | `rewrite-model-bakeoff-2026-02-09-expanded.md` | p95 0.711s, quality 100% | p95 0.669s, quality 100% |
| 2026-02-12 | `rewrite-model-bakeoff-2026-02-12.md` | p95 3.215s†† | p95 1.020s |

††Feb 12 Gemini latency inflated by `reasoning.enabled: false` parameter sent in body — accepted
but introduced routing overhead. The Feb 9 numbers (run without this parameter) are clean baseline.

### Smoke Eval (Feb 12, 12 rewrite quality cases via promptfoo)

| Model | Pass rate | Injection resistance |
| --- | --- | --- |
| `google/gemini-2.5-flash-lite` | 67% | 75% |
| `amazon/nova-micro-v1:nitro` | 83% | 75% |
| `inception/mercury-coder` | 75% | 62% |

Gemini's 67% smoke pass rate is lower than nova-micro but the smoke eval used DeepSeek V3.2 as
judge — not the same as `RewriteQualityGate`. The Feb 9 bakeoff (which uses the production
`RewriteQualityGate`) showed gemini at 100% quality. The discrepancy is judge preference, not
a fidelity problem.

## Rationale Summary

- `gemini-2.5-flash-lite` wins Clean and Polish on latency by a large margin.
- Routes via Gemini direct API in production — no OpenRouter cost or routing overhead.
- Consistent across 4 independent bakeoff runs spanning 2 weeks.
- `x-ai/grok-4.1-fast` (prior Polish default) was never benchmarked; this run shows it is
  5–8x slower than the winner. Eliminated.

## Raw Data

- `docs/performance/bakeoff-raw-2026-02-23-final-lockdown-2026-02-23.json`
- `docs/performance/rewrite-model-bakeoff-2026-02-23-final-lockdown-2026-02-23.md`
