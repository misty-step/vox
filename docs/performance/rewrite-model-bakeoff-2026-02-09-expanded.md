# Rewrite Model Bakeoff

- Generated: 2026-02-09T22:00:29Z
- Iterations per sample: 2
- Corpus entries: 30
- Candidate models: google/gemini-2.5-flash-lite, google/gemini-2.5-flash, google/gemini-2.0-flash-lite-001, google/gemini-2.0-flash-001, openai/gpt-4o-mini, openai/gpt-4.1-nano, anthropic/claude-haiku-4.5, mistralai/ministral-8b-2512, mistralai/ministral-3b-2512, meta-llama/llama-3.1-8b-instruct, xiaomi/mimo-v2-flash, nvidia/nemotron-nano-9b-v2, inception/mercury

## Methodology
- Uses production rewrite prompts from `RewritePrompts` per processing level.
- Evaluates quality with `RewriteQualityGate` pass/fail and ratio checks.
- Measures wall-clock request latency and OpenRouter-reported request cost.
- Decision rule: filter by quality target, pick lowest p95 latency, tie-break by mean cost.

## Light Results

| Model | Quality pass | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Cost p95 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite` | 100.0% | 0.0% | 100.0% | 0.551s | 0.711s | $0.000024 | $0.000027 |
| `google/gemini-2.5-flash` | 100.0% | 0.0% | 100.0% | 0.745s | 0.896s | $0.000100 | $0.000122 |
| `google/gemini-2.0-flash-001` | 100.0% | 0.0% | 100.0% | 0.646s | 0.928s | $0.000024 | $0.000028 |
| `openai/gpt-4o-mini` | 100.0% | 0.0% | 100.0% | 1.096s | 1.450s | $0.000000 | $0.000000 |
| `xiaomi/mimo-v2-flash` | 95.0% | 0.0% | 100.0% | 1.192s | 39.305s | $0.000086 | $0.000098 |
| `inception/mercury` | 90.0% | 0.0% | 100.0% | 0.763s | 1.297s | $0.000096 | $0.000103 |
| `google/gemini-2.0-flash-lite-001` | 90.0% | 0.0% | 100.0% | 0.987s | 2.177s | $0.000037 | $0.000065 |
| `openai/gpt-4.1-nano` | 90.0% | 0.0% | 100.0% | 1.458s | 4.384s | $0.000000 | $0.000000 |
| `anthropic/claude-haiku-4.5` | 90.0% | 0.0% | 100.0% | 0.857s | 10.088s | $0.000000 | $0.000000 |
| `mistralai/ministral-3b-2512` | 80.0% | 0.0% | 100.0% | 0.368s | 1.237s | $0.000021 | $0.000045 |
| `mistralai/ministral-8b-2512` | 80.0% | 0.0% | 100.0% | 0.386s | 1.770s | $0.000034 | $0.000066 |
| `nvidia/nemotron-nano-9b-v2` | 65.0% | 0.0% | 100.0% | 0.477s | 7.324s | $0.000066 | $0.000227 |
| `meta-llama/llama-3.1-8b-instruct` | 60.0% | 0.0% | 100.0% | 0.952s | 10.384s | $0.000012 | $0.000043 |

- Recommendation: `google/gemini-2.5-flash-lite`
- Rationale: passed quality target 95%; best p95 latency 0.711s; mean cost $0.000024
- Quality target: 95%

## Aggressive Results

| Model | Quality pass | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Cost p95 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite` | 100.0% | 0.0% | 100.0% | 0.541s | 0.669s | $0.000028 | $0.000034 |
| `openai/gpt-4.1-nano` | 100.0% | 0.0% | 100.0% | 0.619s | 0.932s | $0.000000 | $0.000000 |
| `mistralai/ministral-3b-2512` | 100.0% | 0.0% | 100.0% | 0.388s | 0.955s | $0.000025 | $0.000040 |
| `google/gemini-2.5-flash` | 100.0% | 0.0% | 100.0% | 0.829s | 1.077s | $0.000112 | $0.000149 |
| `google/gemini-2.0-flash-lite-001` | 100.0% | 0.0% | 100.0% | 0.653s | 1.169s | $0.000021 | $0.000025 |
| `mistralai/ministral-8b-2512` | 100.0% | 0.0% | 100.0% | 0.481s | 1.252s | $0.000032 | $0.000035 |
| `xiaomi/mimo-v2-flash` | 100.0% | 0.0% | 100.0% | 0.776s | 1.271s | $0.000012 | $0.000017 |
| `openai/gpt-4o-mini` | 100.0% | 0.0% | 100.0% | 1.231s | 2.082s | $0.000000 | $0.000000 |
| `anthropic/claude-haiku-4.5` | 100.0% | 0.0% | 100.0% | 1.181s | 3.700s | $0.000000 | $0.000000 |
| `nvidia/nemotron-nano-9b-v2` | 100.0% | 0.0% | 100.0% | 0.562s | 7.021s | $0.000069 | $0.000228 |
| `inception/mercury` | 95.0% | 0.0% | 100.0% | 0.898s | 1.186s | $0.000073 | $0.000093 |
| `meta-llama/llama-3.1-8b-instruct` | 95.0% | 0.0% | 100.0% | 0.903s | 2.480s | $0.000010 | $0.000024 |
| `google/gemini-2.0-flash-001` | 90.0% | 0.0% | 100.0% | 0.680s | 1.739s | $0.000027 | $0.000033 |

- Recommendation: `google/gemini-2.5-flash-lite`
- Rationale: passed quality target 90%; best p95 latency 0.669s; mean cost $0.000028
- Quality target: 90%

## Enhance Results

| Model | Quality pass | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Cost p95 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `google/gemini-2.0-flash-001` | 100.0% | 0.0% | 100.0% | 0.647s | 0.777s | $0.000021 | $0.000024 |
| `google/gemini-2.5-flash-lite` | 100.0% | 0.0% | 100.0% | 0.537s | 0.888s | $0.000025 | $0.000043 |
| `inception/mercury` | 100.0% | 0.0% | 100.0% | 0.817s | 1.099s | $0.000076 | $0.000091 |
| `google/gemini-2.0-flash-lite-001` | 100.0% | 0.0% | 100.0% | 0.687s | 1.203s | $0.000015 | $0.000021 |
| `openai/gpt-4.1-nano` | 100.0% | 0.0% | 100.0% | 0.719s | 1.396s | $0.000000 | $0.000000 |
| `google/gemini-2.5-flash` | 100.0% | 0.0% | 100.0% | 0.809s | 1.502s | $0.000105 | $0.000170 |
| `openai/gpt-4o-mini` | 100.0% | 0.0% | 100.0% | 1.282s | 1.772s | $0.000000 | $0.000000 |
| `mistralai/ministral-8b-2512` | 100.0% | 0.0% | 100.0% | 1.513s | 2.315s | $0.000054 | $0.000076 |
| `meta-llama/llama-3.1-8b-instruct` | 100.0% | 0.0% | 100.0% | 0.825s | 2.414s | $0.000009 | $0.000027 |
| `xiaomi/mimo-v2-flash` | 100.0% | 0.0% | 100.0% | 1.606s | 2.824s | $0.000040 | $0.000074 |
| `anthropic/claude-haiku-4.5` | 100.0% | 0.0% | 100.0% | 1.453s | 4.073s | $0.000000 | $0.000000 |
| `mistralai/ministral-3b-2512` | 95.0% | 0.0% | 100.0% | 0.837s | 1.991s | $0.000030 | $0.000060 |
| `nvidia/nemotron-nano-9b-v2` | 85.0% | 0.0% | 100.0% | 0.539s | 5.177s | $0.000029 | $0.000121 |

- Recommendation: `google/gemini-2.0-flash-001`
- Rationale: passed quality target 90%; best p95 latency 0.777s; mean cost $0.000021
- Quality target: 90%

## Manual Spot Checks

### Light (`google/gemini-2.5-flash-lite` / sample `light-01`)

- Transcript:

```
okay so um today i want to talk about the release plan for vox like what we ship first and what we cut
```

- Rewritten:

```
Okay, so today I want to talk about the release plan for Vox, like what we ship first and what we cut.
```

### Aggressive (`google/gemini-2.5-flash-lite` / sample `aggressive-01`)

- Transcript:

```
so ive been thinking about how the app feels slow and i think its not the stt anymore its the rewrite step because it waits for the llm and that can take like two seconds sometimes
```

- Rewritten:

```
The app feels slow. It's not the speech-to-text anymore. The rewrite step causes the delay. It waits for the LLM. That takes two seconds sometimes.
```

### Enhance (`google/gemini-2.0-flash-001` / sample `enhance-01`)

- Transcript:

```
i need you to review a swift file and point out bugs and missing tests and then suggest a safe refactor plan
```

- Rewritten:

```
Swift code reviewer: Identify bugs, missing tests, and propose a safe refactoring plan.

```

## Rollback Plan

- Trigger: rewrite quality complaints increase or quality-gate fallback rate regresses after rollout.
- Immediate rollback: restore prior defaults in `Sources/VoxCore/ProcessingLevel.swift`.
- Validation after rollback: run strict build/tests and compare rewrite latency logs against baseline.

## Raw Artifact

- `/Users/phaedrus/Development/vox/docs/performance/rewrite-corpus.json`
- JSON results committed separately in `docs/performance/` for reproducibility.