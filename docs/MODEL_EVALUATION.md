# OpenRouter Model Evaluation for Vox

Last updated: February 2026

## Use Case Requirements
- Voice transcript rewriting
- `Clean`: **Priority: low latency** (sub-second ideal), low variance, cost-effective
- `Polish`: **Priority: quality** (can be slower/more expensive), but must preserve intent and avoid hallucination

## Model Comparison

| Model | Input $/M | Output $/M | Context | Latency | Reasoning | Notes |
|-------|-----------|------------|---------|---------|-----------|-------|
| Gemini 2.5 Flash Lite | $0.10 | $0.40 | 1M | Best in bakeoff | Off | **Best overall speed+stability** |
| Gemini 2.0 Flash | $0.10 | $0.40 | 1M | Good | Off | Solid fallback |
| Gemini 2.0 Flash Lite | $0.075 | $0.30 | 1M | Good | Off | Can over-expand on Clean (quality-gate flags; benchmarks reject) |
| OpenAI GPT-4.1 Nano | $0.10 | $0.40 | ~1M | Slower than Gemini Flash Lite | Off | Solid fallback |
| OpenAI GPT-4o-mini | $0.15 | $0.60 | 128K | Slower | Off | Solid fallback |
| Anthropic Claude Haiku 4.5 | $1.00 | $5.00 | 200K | Unstable tails on Clean | Off | Tends to over-expand Clean in bakeoff |
| Mistral Ministral 3 8B | $0.15 | $0.15 | 256K | Medium | Off | Over-expands Clean sometimes |
| Mistral Ministral 3 3B | $0.10 | $0.10 | 128K | Fast | Off | Over-expands Clean often |
| Llama 3.1 8B Instruct | $0.02 | $0.05 | 16K | Unstable tails | Off | Not consistent enough for Clean |
| NVIDIA Nemotron Nano 9B V2 | $0.04 | $0.16 | 128K | Unstable tails | On by default | Disable reasoning; still unstable for our use case |
| MiMo-V2-Flash | $0.09 | $0.29 | 256K | Unstable tails | Off | Cheap, but long tail risk |
| Gemini 3 Flash Preview | $0.50 | $3.00 | 1M | Variable | Min "minimal" | **Cannot disable reasoning**, avoid |

## Recommendation

**Primary (Clean): `inception/mercury` (OpenRouter)**
- Lowest p95 latency in the latest in-repo bakeoff (`rewrite-model-bakeoff-2026-02-24-gemini-vs-mercury-20260224.md`)
- Stable non-empty outputs across clean samples in that run

**Primary (Polish): `inception/mercury` (OpenRouter)**
- Lowest p95 latency in the same bakeoff
- Fewer malformed outputs than `gemini-2.5-flash-lite` in that run

Implementation note: rewriting is model-routed via `ModelRoutedRewriteProvider`:
- Gemini models go to Gemini direct when configured
- Non-Google models (with provider prefix) go to OpenRouter
- If OpenRouter is unavailable, best-effort fallback uses Gemini (`gemini-2.5-flash-lite`) so UX still works

**Fallback options (if Gemini has issues):**
1. `openai/gpt-4.1-nano`
2. `openai/gpt-4o-mini`
3. `mistralai/ministral-8b-2512` (expect slower + Clean over-expansion risk)

## Bakeoff (2026-02-09)

See `docs/performance/rewrite-model-bakeoff-2026-02-09.md` for measured p50/p95 latency, cost, and `RewriteQualityGate` pass-rate across candidate models.

Outcome:
- `clean` default: `inception/mercury`
- `polish` default: `inception/mercury`

Expanded bakeoff: `docs/performance/rewrite-model-bakeoff-2026-02-09-expanded.md`
- Legacy naming: `Light` → `Clean`, `Aggressive` → `Polish`, `Enhance` → removed (legacy `enhance` maps to `clean`).

## Polish Bakeoff (Promptfoo)

Polish is allowed to trade speed for quality. Use `evals/polish-bakeoff.yaml` and:

```bash
./evals/scripts/eval-polish-smoke.sh
./evals/scripts/eval-polish.sh
./evals/scripts/format-polish-report.js < evals/output/polish-bakeoff-results.json > evals/output/polish-bakeoff-report.md
```

## Reasoning Control

OpenRouter supports a unified `reasoning` parameter:

```json
{
  "reasoning": {
    "effort": "none",     // xhigh, high, medium, low, minimal, none
    "max_tokens": 0,      // specific token limit
    "exclude": true,      // hide reasoning from response
    "enabled": false      // disable completely
  }
}
```

**Important limitations:**
- Gemini 3 models: Cannot fully disable reasoning (minimum is "minimal")
- Gemini 2.5 models: Can disable with `effort: "none"` 
- Most models: `enabled: false` works; if a model still “thinks”, don’t use it for Vox rewrite

## Model IDs for OpenRouter

```
google/gemini-2.5-flash-lite
google/gemini-2.0-flash-001
google/gemini-2.0-flash-lite-001
openai/gpt-4.1-nano
openai/gpt-4o-mini
anthropic/claude-haiku-4.5
mistralai/ministral-8b-2512
mistralai/ministral-3b-2512
meta-llama/llama-3.1-8b-instruct
nvidia/nemotron-nano-9b-v2
xiaomi/mimo-v2-flash
google/gemini-2.5-flash
google/gemini-3-flash-preview
x-ai/grok-4.1-fast
```

## Sources

- [OpenRouter Models](https://openrouter.ai/models)
- [OpenRouter Reasoning Tokens](https://openrouter.ai/docs/guides/best-practices/reasoning-tokens)
- [Gemini 2.5 Flash Lite](https://openrouter.ai/google/gemini-2.5-flash-lite)
- [Gemini 2.0 Flash](https://openrouter.ai/google/gemini-2.0-flash-001)
- [GPT-4.1 Nano](https://openrouter.ai/openai/gpt-4.1-nano)
- [Claude Haiku 4.5](https://openrouter.ai/anthropic/claude-haiku-4.5)
- [MiMo-V2-Flash](https://openrouter.ai/xiaomi/mimo-v2-flash)
