# Rewrite Model Bakeoff

- Generated: 2026-02-12T15:29:51Z
- Iterations per sample: 2
- Corpus entries: 30
- Candidate models: google/gemini-2.5-flash-lite:nitro, google/gemini-2.5-flash-lite, qwen/qwen-turbo, qwen/qwen3-32b:nitro, amazon/nova-micro-v1:nitro, meta-llama/llama-4-maverick:nitro, morph/morph-v3-fast, inception/mercury-coder

## Methodology
- Uses production rewrite prompts from `RewritePrompts` per processing level.
- All models called via OpenRouter with `provider.sort: latency` and `reasoning.enabled: false`.
- Measures wall-clock request latency (includes network overhead).
- Quality metrics: char ratio, normalized Levenshtein similarity, content word overlap.
- Decision rule: pick lowest p95 latency among models with acceptable quality metrics.

## Light Results

| Model | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Lev mean | Lev p5 | Overlap mean |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite:nitro` | 0% | 100% | 2.140s | 3.105s | $0.000000 | 0.909 | 0.786 | 0.969 |
| `google/gemini-2.5-flash-lite` | 0% | 100% | 0.702s | 3.215s | $0.000000 | 0.909 | 0.789 | 0.977 |
| `qwen/qwen3-32b:nitro` | 0% | 100% | 2.157s | 4.004s | $0.000000 | 0.788 | 0.452 | 0.897 |
| `qwen/qwen-turbo` | 20/20 | — | — | — | — | — | — | — |
| `amazon/nova-micro-v1:nitro` | 20/20 | — | — | — | — | — | — | — |
| `meta-llama/llama-4-maverick:nitro` | 20/20 | — | — | — | — | — | — | — |
| `morph/morph-v3-fast` | 20/20 | — | — | — | — | — | — | — |
| `inception/mercury-coder` | 20/20 | — | — | — | — | — | — | — |

- **Recommendation**: `google/gemini-2.5-flash-lite:nitro`
- Rationale: lowest p95 latency (3.105s) among viable models; mean cost $0.000000

## Aggressive Results

| Model | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Lev mean | Lev p5 | Overlap mean |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite:nitro` | 0% | 100% | 0.601s | 1.020s | $0.000000 | 0.542 | 0.376 | 0.638 |
| `google/gemini-2.5-flash-lite` | 0% | 100% | 0.533s | 2.812s | $0.000000 | 0.549 | 0.385 | 0.658 |
| `qwen/qwen3-32b:nitro` | 0% | 100% | 2.237s | 4.445s | $0.000000 | 0.556 | 0.362 | 0.591 |
| `qwen/qwen-turbo` | 20/20 | — | — | — | — | — | — | — |
| `amazon/nova-micro-v1:nitro` | 20/20 | — | — | — | — | — | — | — |
| `meta-llama/llama-4-maverick:nitro` | 20/20 | — | — | — | — | — | — | — |
| `morph/morph-v3-fast` | 20/20 | — | — | — | — | — | — | — |
| `inception/mercury-coder` | 20/20 | — | — | — | — | — | — | — |

- **Recommendation**: `google/gemini-2.5-flash-lite:nitro`
- Rationale: lowest p95 latency (1.020s) among viable models; mean cost $0.000000
