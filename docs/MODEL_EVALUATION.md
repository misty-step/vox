# OpenRouter Model Evaluation for Vox

Last updated: January 2026

## Use Case Requirements
- Text rewriting/cleanup of voice transcripts
- **Priority: Low latency** (sub-second responses ideal)
- Simple task (no deep reasoning needed)
- Cost-effective for frequent use

## Model Comparison

| Model | Input $/M | Output $/M | Context | Latency | Reasoning | Notes |
|-------|-----------|------------|---------|---------|-----------|-------|
| Gemini 2.5 Flash Lite | $0.10 | $0.40 | 1M | **392 tok/s, 0.29s TTFT** | Off by default | **Best for speed** |
| MiMo-V2-Flash | $0.09 | $0.29 | 256K | Fast (15B active) | Off by default | Cheapest, may struggle with instructions |
| DeepSeek V3.2 | $0.25 | $0.38 | 163K | Good | Toggleable | Best value/intelligence ratio |
| Gemini 2.5 Flash | $0.30 | $2.50 | 1M | Good | On by default | More capable but slower |
| Kimi K2.5 | $0.50 | $2.50 | 256K | Good | On by default | Multimodal, agent-focused |
| Gemini 3 Flash Preview | $0.15 | $0.60 | 1M | Variable | Min "minimal" | **Cannot disable reasoning**, unstable |

## Recommendation

**Primary: `google/gemini-2.5-flash-lite`**
- Fastest production model (392 tok/s, 0.29s time-to-first-token)
- Thinking disabled by default (no wasted reasoning tokens)
- 1M context window
- Very affordable

**Fallback options:**
1. `xiaomi/mimo-v2-flash` - Cheapest, but may have instruction-following issues
2. `deepseek/deepseek-v3.2` - Best intelligence when speed is less critical

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
- DeepSeek/MiMo: Use `enabled: false` or omit parameter

## Model IDs for OpenRouter

```
google/gemini-2.5-flash-lite
xiaomi/mimo-v2-flash
deepseek/deepseek-v3.2
google/gemini-2.5-flash
moonshotai/kimi-k2.5
google/gemini-3-flash-preview
```

## Sources

- [OpenRouter Models](https://openrouter.ai/models)
- [OpenRouter Reasoning Tokens](https://openrouter.ai/docs/guides/best-practices/reasoning-tokens)
- [Gemini 2.5 Flash Lite](https://openrouter.ai/google/gemini-2.5-flash-lite)
- [MiMo-V2-Flash](https://openrouter.ai/xiaomi/mimo-v2-flash)
- [DeepSeek V3.2](https://openrouter.ai/deepseek/deepseek-v3.2)
