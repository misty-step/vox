# Rewrite Model Bakeoff

- Generated: 2026-02-23T15:18:46Z
- Iterations per sample: 2
- Corpus entries: 20
- Candidate models: google/gemini-2.5-flash-lite, x-ai/grok-4.1-fast, inception/mercury-coder, amazon/nova-micro-v1:nitro

## Methodology
- Uses production rewrite prompts from `RewritePrompts` per processing level.
- All models called via OpenRouter with `provider.sort: latency` and `reasoning.enabled: false`.
- Measures wall-clock request latency (includes network overhead).
- Quality metrics: char ratio, normalized Levenshtein similarity, content word overlap.
- Decision rule: pick lowest p95 latency among models with acceptable quality metrics.

## Clean Results

| Model | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Lev mean | Lev p5 | Overlap mean |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite` | 0% | 100% | 0.635s | 0.989s | $0.000000 | 0.907 | 0.766 | 0.964 |
| `amazon/nova-micro-v1:nitro` | 0% | 100% | 0.618s | 1.386s | $0.000000 | 0.841 | 0.504 | 0.963 |
| `inception/mercury-coder` | 0% | 100% | 1.092s | 1.616s | $0.000000 | 0.844 | 0.198 | 0.888 |
| `x-ai/grok-4.1-fast` | 0% | 100% | 3.459s | 6.426s | $0.000000 | 0.931 | 0.833 | 0.977 |

- **Recommendation**: `google/gemini-2.5-flash-lite`
- Rationale: lowest p95 latency (0.989s) among viable models; mean cost $0.000000

## Polish Results

| Model | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Lev mean | Lev p5 | Overlap mean |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite` | 0% | 100% | 0.703s | 1.252s | $0.000000 | 0.435 | 0.225 | 0.524 |
| `inception/mercury-coder` | 0% | 100% | 1.072s | 1.500s | $0.000000 | 0.411 | 0.249 | 0.631 |
| `amazon/nova-micro-v1:nitro` | 0% | 100% | 1.509s | 2.439s | $0.000000 | 0.137 | 0.081 | 0.565 |
| `x-ai/grok-4.1-fast` | 0% | 100% | 3.842s | 8.342s | $0.000000 | 0.777 | 0.523 | 0.865 |

- **Recommendation**: `google/gemini-2.5-flash-lite`
- Rationale: lowest p95 latency (1.252s) among viable models; mean cost $0.000000
