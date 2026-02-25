# Rewrite Model Bakeoff

- Generated: 2026-02-24T21:12:37Z
- Iterations per sample: 1
- Corpus entries: 20
- Candidate models: google/gemini-2.5-flash-lite, inception/mercury

## Methodology
- Uses production rewrite prompts from `RewritePrompts` per processing level.
- All models called via OpenRouter with `provider.sort: latency` and `reasoning.enabled: false`.
- Measures wall-clock request latency (includes network overhead).
- Quality metrics: char ratio, normalized Levenshtein similarity, content word overlap.
- Decision rule: pick lowest p95 latency among models with acceptable quality metrics.

## Clean Results

| Model | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Lev mean | Lev p5 | Overlap mean |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `inception/mercury` | 0% | 100% | 0.658s | 1.403s | $0.000000 | 0.934 | 0.827 | 0.977 |
| `google/gemini-2.5-flash-lite` | 0% | 100% | 1.431s | 3.804s | $0.000000 | 0.899 | 0.781 | 0.977 |

- **Recommendation**: `inception/mercury`
- Rationale: lowest p95 latency (1.403s) among viable models; mean cost $0.000000

## Polish Results

| Model | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Lev mean | Lev p5 | Overlap mean |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `inception/mercury` | 0% | 100% | 0.925s | 1.203s | $0.000000 | 0.344 | 0.238 | 0.568 |
| `google/gemini-2.5-flash-lite` | 0% | 100% | 2.160s | 2.715s | $0.000000 | 0.390 | 0.235 | 0.492 |

- **Recommendation**: `inception/mercury`
- Rationale: lowest p95 latency (1.203s) among viable models; mean cost $0.000000
