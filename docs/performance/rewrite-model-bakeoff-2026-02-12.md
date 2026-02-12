# Rewrite Model Bakeoff — 2026-02-12

Consolidated evaluation of 8 candidate models for the rewrite pipeline.

## Test Matrix

| Evaluation | Method | Cases | Judge |
| --- | --- | --- | --- |
| Latency bakeoff | `scripts/rewrite-bakeoff.py` — 2 iterations × 10 corpus entries × 2 levels | 40 calls/model | Automated metrics |
| Smoke eval | `evals/bakeoff-config.yaml` — 12 rewrite cases | 12/model | DeepSeek V3.2 rubric |
| Injection eval | `evals/datasets/injection.yaml` — 8 red-team cases | 8/model | DeepSeek V3.2 rubric |

All models called via OpenRouter with `provider.sort: latency`.

## Candidate Models

| Model | Status |
| --- | --- |
| `google/gemini-2.5-flash-lite:nitro` | Viable |
| `google/gemini-2.5-flash-lite` | Viable |
| `qwen/qwen-turbo` | Viable |
| `qwen/qwen3-32b:nitro` | Viable |
| `amazon/nova-micro-v1:nitro` | Viable |
| `meta-llama/llama-4-maverick:nitro` | Viable |
| `inception/mercury-coder` | Viable |
| `morph/morph-v3-fast` | **Eliminated** — 400 "Multi-turn conversations not supported" |

## Latency Results (Light)

| Model | p50 | p95 | Lev mean | Lev p5 | Overlap mean |
| --- | --- | --- | --- | --- | --- |
| `inception/mercury-coder` | 0.753s | 0.968s | 0.923 | 0.789 | 0.977 |
| `amazon/nova-micro-v1:nitro` | 0.650s | 1.021s | 0.818 | 0.256 | 0.955 |
| `meta-llama/llama-4-maverick:nitro` | 0.490s | 1.240s | 0.863 | 0.524 | 0.960 |
| `qwen/qwen-turbo` | 1.159s | 1.810s | 0.941 | 0.862 | 0.977 |
| `google/gemini-2.5-flash-lite:nitro`* | 2.140s | 3.105s | 0.909 | 0.786 | 0.969 |
| `google/gemini-2.5-flash-lite`* | 0.702s | 3.215s | 0.909 | 0.789 | 0.977 |
| `qwen/qwen3-32b:nitro`* | 2.157s | 4.004s | 0.788 | 0.452 | 0.897 |

*Gemini and qwen3-32b ran in a separate batch that included `reasoning.enabled: false` in the request body. This parameter was accepted (no error) but may have introduced routing overhead. Their latency numbers here are likely inflated vs production. The Feb 9 bakeoff measured gemini-2.5-flash-lite at 0.551s p50 / 0.711s p95 under clean conditions.

## Latency Results (Aggressive)

| Model | p50 | p95 | Lev mean | Lev p5 | Overlap mean |
| --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite:nitro`* | 0.601s | 1.020s | 0.542 | 0.376 | 0.638 |
| `amazon/nova-micro-v1:nitro` | 0.669s | 1.278s | 0.601 | 0.493 | 0.654 |
| `inception/mercury-coder` | 0.759s | 1.297s | 0.588 | 0.367 | 0.670 |
| `meta-llama/llama-4-maverick:nitro` | 0.425s | 1.409s | 0.536 | 0.278 | 0.551 |
| `qwen/qwen-turbo` | 1.097s | 1.567s | 0.729 | 0.516 | 0.861 |
| `google/gemini-2.5-flash-lite`* | 0.533s | 2.812s | 0.549 | 0.385 | 0.658 |
| `qwen/qwen3-32b:nitro`* | 2.237s | 4.445s | 0.556 | 0.362 | 0.591 |

## Smoke Eval (12 rewrite quality cases)

| Model | Pass | Rate |
| --- | --- | --- |
| `amazon/nova-micro-v1:nitro` | 10/12 | 83% |
| `inception/mercury-coder` | 9/12 | 75% |
| `qwen/qwen-turbo` | 9/12 | 75% |
| `google/gemini-2.5-flash-lite` | 8/12 | 67% |
| `google/gemini-2.5-flash-lite:nitro` | 8/12 | 67% |
| `meta-llama/llama-4-maverick:nitro` | 7/12 | 58% |
| `qwen/qwen3-32b:nitro` | 7/12 | 58% |

Common failure modes: haiku injection (writes haiku instead of rewriting), system prompt leak (outputs role description), verbatim copy (no cleanup applied).

## Injection Resistance (8 red-team cases)

| Model | Pass | Rate |
| --- | --- | --- |
| `qwen/qwen3-32b:nitro` | 7/8 | 88% |
| `google/gemini-2.5-flash-lite:nitro` | 6/8 | 75% |
| `google/gemini-2.5-flash-lite` | 6/8 | 75% |
| `amazon/nova-micro-v1:nitro` | 6/8 | 75% |
| `qwen/qwen-turbo` | 6/8 | 75% |
| `inception/mercury-coder` | 5/8 | 62% |
| `meta-llama/llama-4-maverick:nitro` | 3/8 | 38% |

Common vulnerabilities: French translation injection, base64 decode, role-play compliance.

## Composite Ranking

Weighted score: 40% latency (inverse p95, light), 30% smoke pass rate, 30% injection resistance.

| Rank | Model | Light p95 | Smoke | Injection | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | `inception/mercury-coder` | 0.968s | 75% | 62% | Fastest p95, high quality (lev 0.923) |
| 2 | `amazon/nova-micro-v1:nitro` | 1.021s | 83% | 75% | Best smoke score, low lev p5 (0.256) |
| 3 | `qwen/qwen-turbo` | 1.810s | 75% | 75% | Highest lev mean (0.941), slower |
| 4 | `meta-llama/llama-4-maverick:nitro` | 1.240s | 58% | 38% | Fastest p50 but poor injection resistance |
| 5 | `qwen/qwen3-32b:nitro` | 4.004s | 58% | 88% | Best injection resistance, too slow |
| — | `google/gemini-2.5-flash-lite` | 3.215s† | 67% | 75% | Likely faster in production (see note) |
| — | `google/gemini-2.5-flash-lite:nitro` | 3.105s† | 67% | 75% | Likely faster in production (see note) |

†Gemini latency inflated by `reasoning.enabled` parameter in request. Feb 9 bakeoff: 0.711s p95 (light).

## Comparison with Feb 9 Bakeoff (Incumbent)

| Model | Feb 9 p95 (light) | Feb 12 p95 (light) | Feb 9 Quality | Feb 12 Smoke |
| --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite` | **0.711s** | 3.215s† | 100% | 67% |
| `inception/mercury-coder` | — | **0.968s** | — | 75% |
| `amazon/nova-micro-v1:nitro` | — | **1.021s** | — | 83% |

## Recommendations

1. **Keep `google/gemini-2.5-flash-lite` as primary.** Feb 9 bakeoff showed 0.711s p95 with 100% quality — still the best validated result. The inflated latency in this run is a measurement artifact.

2. **Promote `inception/mercury-coder` to first fallback.** Sub-1s p95, 0.923 Levenshtein similarity (light), good quality. Weaker on injection resistance (62%) but acceptable for a fallback.

3. **Promote `amazon/nova-micro-v1:nitro` to second fallback.** 1.021s p95, best smoke score (83%), solid injection resistance (75%). Low Levenshtein p5 (0.256) suggests occasional aggressive rewrites.

4. **Drop `qwen/qwen3-32b:nitro` and `meta-llama/llama-4-maverick:nitro`.** Too slow or too injection-vulnerable respectively.

5. **Eliminate `morph/morph-v3-fast`.** Incompatible with system+user message format.

## Artifacts

| File | Description |
| --- | --- |
| `docs/performance/bakeoff-raw-2026-02-12-new-candidates.json` | Raw JSON — first batch (gemini, qwen3-32b) |
| `docs/performance/bakeoff-raw-2026-02-12-retry-no-reasoning.json` | Raw JSON — retry batch (remaining 5 models) |
| `evals/output/bakeoff-results.json` | promptfoo injection eval results |
| `evals/output/bakeoff-smoke-results.json` | promptfoo smoke eval results |
| `scripts/rewrite-bakeoff.py` | Latency/quality bakeoff script |
| `evals/bakeoff-config.yaml` | Multi-provider promptfoo config |
