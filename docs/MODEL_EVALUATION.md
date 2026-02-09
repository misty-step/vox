# OpenRouter Model Evaluation for Vox

Last updated: February 2026

## Use Case Requirements
- Text rewriting/cleanup of voice transcripts
- **Priority: Low latency** (sub-second responses ideal)
- Simple task (no deep reasoning needed)
- Cost-effective for frequent use

## Model Comparison

| Model | Input $/M | Output $/M | Context | Latency | Reasoning | Notes |
|-------|-----------|------------|---------|---------|-----------|-------|
| Gemini 2.5 Flash Lite | $0.10 | $0.40 | 1M | Best in bakeoff | Off | **Best overall speed+stability** |
| Gemini 2.0 Flash | $0.10 | $0.40 | 1M | Best p95 on Enhance | Off | Strong Enhance choice |
| Gemini 2.0 Flash Lite | $0.075 | $0.30 | 1M | Good | Off | Can over-expand on Light (quality-gate rejects) |
| OpenAI GPT-4.1 Nano | $0.10 | $0.40 | ~1M | Slower than Gemini Flash Lite | Off | Solid fallback |
| OpenAI GPT-4o-mini | $0.15 | $0.60 | 128K | Slower | Off | Solid fallback |
| Anthropic Claude Haiku 4.5 | $1.00 | $5.00 | 200K | Unstable tails on Light | Off | Tends to over-expand Light in bakeoff |
| Mistral Ministral 3 8B | $0.15 | $0.15 | 256K | Medium | Off | Over-expands Light sometimes |
| Mistral Ministral 3 3B | $0.10 | $0.10 | 128K | Fast | Off | Over-expands Light often |
| Llama 3.1 8B Instruct | $0.02 | $0.05 | 16K | Unstable tails | Off | Not consistent enough for Light |
| NVIDIA Nemotron Nano 9B V2 | $0.04 | $0.16 | 128K | Unstable tails | On by default | Disable reasoning; still unstable for our use case |
| MiMo-V2-Flash | $0.09 | $0.29 | 256K | Unstable tails | Off | Cheap, but long tail risk |
| Gemini 3 Flash Preview | $0.50 | $3.00 | 1M | Variable | Min "minimal" | **Cannot disable reasoning**, avoid |

## Recommendation

**Primary: `google/gemini-2.5-flash-lite` (Light + Aggressive)**
- Fastest production model (392 tok/s, 0.29s time-to-first-token)
- Thinking disabled by default (no wasted reasoning tokens)
- 1M context window
- Very affordable

**Enhance candidate: `google/gemini-2.0-flash-001`**
- In expanded bakeoff it beat Flash Lite on Enhance p95 latency.

**Fallback options (if Gemini has issues):**
1. `openai/gpt-4.1-nano`
2. `openai/gpt-4o-mini`
3. `mistralai/ministral-8b-2512` (expect slower + Light over-expansion risk)

## Bakeoff (2026-02-09)

See `docs/performance/rewrite-model-bakeoff-2026-02-09.md` for measured p50/p95 latency, cost, and `RewriteQualityGate` pass-rate across candidate models.

Outcome: `ProcessingLevel` defaults now use `google/gemini-2.5-flash-lite` for light/aggressive/enhance.

Expanded bakeoff: `docs/performance/rewrite-model-bakeoff-2026-02-09-expanded.md`
- Light: `google/gemini-2.5-flash-lite`
- Aggressive: `google/gemini-2.5-flash-lite`
- Enhance: `google/gemini-2.0-flash-001`

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
```

## Sources

- [OpenRouter Models](https://openrouter.ai/models)
- [OpenRouter Reasoning Tokens](https://openrouter.ai/docs/guides/best-practices/reasoning-tokens)
- [Gemini 2.5 Flash Lite](https://openrouter.ai/google/gemini-2.5-flash-lite)
- [Gemini 2.0 Flash](https://openrouter.ai/google/gemini-2.0-flash-001)
- [GPT-4.1 Nano](https://openrouter.ai/openai/gpt-4.1-nano)
- [Claude Haiku 4.5](https://openrouter.ai/anthropic/claude-haiku-4.5)
- [MiMo-V2-Flash](https://openrouter.ai/xiaomi/mimo-v2-flash)
