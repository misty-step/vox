# Rewrite Model Bakeoff

- Generated: 2026-02-09T18:30:19Z
- Iterations per sample: 2
- Corpus entries: 30
- Candidate models: google/gemini-2.5-flash-lite, google/gemini-2.5-flash, deepseek/deepseek-v3.2, xiaomi/mimo-v2-flash, inception/mercury

## Methodology
- Uses production rewrite prompts from `RewritePrompts` per processing level.
- Evaluates quality with `RewriteQualityGate` pass/fail and ratio checks.
- Measures wall-clock request latency and OpenRouter-reported request cost.
- Decision rule: filter by quality target, pick lowest p95 latency, tie-break by mean cost.

## Light Results

| Model | Quality pass | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Cost p95 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite` | 100.0% | 0.0% | 100.0% | 0.554s | 1.016s | $0.000046 | $0.000050 |
| `google/gemini-2.5-flash` | 100.0% | 0.0% | 100.0% | 0.641s | 1.021s | $0.000100 | $0.000125 |
| `inception/mercury` | 100.0% | 0.0% | 100.0% | 0.984s | 2.374s | $0.000154 | $0.000963 |
| `xiaomi/mimo-v2-flash` | 100.0% | 0.0% | 100.0% | 0.982s | 3.745s | $0.000064 | $0.000098 |
| `deepseek/deepseek-v3.2` | 100.0% | 0.0% | 100.0% | 1.710s | 16.353s | $0.000057 | $0.000263 |

- Recommendation: `google/gemini-2.5-flash-lite`
- Rationale: passed quality target 95%; best p95 latency 1.016s; mean cost $0.000046
- Quality target: 95%

## Aggressive Results

| Model | Quality pass | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Cost p95 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite` | 100.0% | 0.0% | 100.0% | 0.547s | 0.754s | $0.000028 | $0.000034 |
| `google/gemini-2.5-flash` | 100.0% | 0.0% | 100.0% | 0.678s | 0.771s | $0.000115 | $0.000151 |
| `xiaomi/mimo-v2-flash` | 100.0% | 0.0% | 100.0% | 0.973s | 1.324s | $0.000012 | $0.000016 |
| `deepseek/deepseek-v3.2` | 100.0% | 0.0% | 100.0% | 1.710s | 2.272s | $0.000040 | $0.000053 |
| `inception/mercury` | 95.0% | 0.0% | 100.0% | 0.882s | 1.279s | $0.000073 | $0.000086 |

- Recommendation: `google/gemini-2.5-flash-lite`
- Rationale: passed quality target 90%; best p95 latency 0.754s; mean cost $0.000028
- Quality target: 90%

## Enhance Results

| Model | Quality pass | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Cost p95 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite` | 100.0% | 0.0% | 100.0% | 0.568s | 0.799s | $0.000025 | $0.000040 |
| `google/gemini-2.5-flash` | 100.0% | 0.0% | 100.0% | 0.690s | 0.945s | $0.000110 | $0.000198 |
| `inception/mercury` | 100.0% | 0.0% | 100.0% | 0.948s | 1.311s | $0.000078 | $0.000097 |
| `xiaomi/mimo-v2-flash` | 100.0% | 0.0% | 100.0% | 1.976s | 2.436s | $0.000033 | $0.000050 |
| `deepseek/deepseek-v3.2` | 100.0% | 0.0% | 100.0% | 3.339s | 6.238s | $0.000051 | $0.000073 |

- Recommendation: `google/gemini-2.5-flash-lite`
- Rationale: passed quality target 90%; best p95 latency 0.799s; mean cost $0.000025
- Quality target: 90%

## Manual Spot Checks

### Light (`google/gemini-2.5-flash-lite` / sample `light-01`)

- Transcript:

```
okay so um today i want to talk about the release plan for vox like what we ship first and what we cut
```

- Rewritten:

```
Okay, so today I want to talk about the release plan for Vox. What we ship first and what we cut.
```

### Aggressive (`google/gemini-2.5-flash-lite` / sample `aggressive-01`)

- Transcript:

```
so ive been thinking about how the app feels slow and i think its not the stt anymore its the rewrite step because it waits for the llm and that can take like two seconds sometimes
```

- Rewritten:

```
The app feels slow. It's not the speech-to-text. It's the rewrite step. This step waits for the LLM. That can take two seconds. Sometimes.
```

### Enhance (`google/gemini-2.5-flash-lite` / sample `enhance-01`)

- Transcript:

```
i need you to review a swift file and point out bugs and missing tests and then suggest a safe refactor plan
```

- Rewritten:

```
Act as a Senior Swift Engineer. Review the provided Swift file for bugs and missing test coverage. Suggest a plan for safely refactoring the code.
```

## Rollback Plan

- Trigger: rewrite quality complaints increase or quality-gate fallback rate regresses after rollout.
- Immediate rollback: restore prior defaults in `Sources/VoxCore/ProcessingLevel.swift`.
- Validation after rollback: run strict build/tests and compare rewrite latency logs against baseline.

## Raw Artifact

- `/Users/phaedrus/Development/vox/docs/performance/rewrite-corpus.json`
- JSON results committed separately in `docs/performance/` for reproducibility.