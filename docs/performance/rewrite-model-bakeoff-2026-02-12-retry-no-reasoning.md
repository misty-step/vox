# Rewrite Model Bakeoff

- Generated: 2026-02-12T15:35:18Z
- Iterations per sample: 2
- Corpus entries: 30
- Candidate models: qwen/qwen-turbo, amazon/nova-micro-v1:nitro, meta-llama/llama-4-maverick:nitro, morph/morph-v3-fast, inception/mercury-coder

## Methodology
- Uses production rewrite prompts from `RewritePrompts` per processing level.
- All models called via OpenRouter with `provider.sort: latency` and `reasoning.enabled: false`.
- Measures wall-clock request latency (includes network overhead).
- Quality metrics: char ratio, normalized Levenshtein similarity, content word overlap.
- Decision rule: pick lowest p95 latency among models with acceptable quality metrics.

## Light Results

| Model | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Lev mean | Lev p5 | Overlap mean |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `inception/mercury-coder` | 0% | 100% | 0.753s | 0.968s | $0.000000 | 0.923 | 0.789 | 0.977 |
| `amazon/nova-micro-v1:nitro` | 0% | 100% | 0.650s | 1.021s | $0.000000 | 0.818 | 0.256 | 0.955 |
| `meta-llama/llama-4-maverick:nitro` | 0% | 100% | 0.490s | 1.240s | $0.000000 | 0.863 | 0.524 | 0.960 |
| `qwen/qwen-turbo` | 0% | 100% | 1.159s | 1.810s | $0.000000 | 0.941 | 0.862 | 0.977 |
| `morph/morph-v3-fast` | 20/20 | — | — | — | — | — | — | — |

- **Recommendation**: `inception/mercury-coder`
- Rationale: lowest p95 latency (0.968s) among viable models; mean cost $0.000000

## Aggressive Results

| Model | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Lev mean | Lev p5 | Overlap mean |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `amazon/nova-micro-v1:nitro` | 0% | 100% | 0.669s | 1.278s | $0.000000 | 0.601 | 0.493 | 0.654 |
| `inception/mercury-coder` | 0% | 100% | 0.759s | 1.297s | $0.000000 | 0.588 | 0.367 | 0.670 |
| `meta-llama/llama-4-maverick:nitro` | 0% | 100% | 0.425s | 1.409s | $0.000000 | 0.536 | 0.278 | 0.551 |
| `qwen/qwen-turbo` | 0% | 100% | 1.097s | 1.567s | $0.000000 | 0.729 | 0.516 | 0.861 |
| `morph/morph-v3-fast` | 20/20 | — | — | — | — | — | — | — |

- **Recommendation**: `amazon/nova-micro-v1:nitro`
- Rationale: lowest p95 latency (1.278s) among viable models; mean cost $0.000000
