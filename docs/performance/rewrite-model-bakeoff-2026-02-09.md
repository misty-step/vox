# Rewrite Model Bakeoff

- Generated: 2026-02-09T18:46:51Z
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
| `google/gemini-2.5-flash-lite` | 100.0% | 0.0% | 100.0% | 0.509s | 0.853s | $0.000023 | $0.000027 |
| `google/gemini-2.5-flash` | 100.0% | 0.0% | 100.0% | 0.782s | 0.883s | $0.000101 | $0.000127 |
| `inception/mercury` | 95.0% | 0.0% | 100.0% | 0.837s | 1.961s | $0.000060 | $0.000066 |
| `xiaomi/mimo-v2-flash` | 90.0% | 0.0% | 100.0% | 0.944s | 6.821s | $0.000047 | $0.000205 |
| `deepseek/deepseek-v3.2` | 90.0% | 0.0% | 100.0% | 1.562s | 48.831s | $0.000060 | $0.000138 |

- Recommendation: `google/gemini-2.5-flash-lite`
- Rationale: passed quality target 95%; best p95 latency 0.853s; mean cost $0.000023
- Quality target: 95%

## Aggressive Results

| Model | Quality pass | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Cost p95 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite` | 100.0% | 0.0% | 100.0% | 0.522s | 0.843s | $0.000029 | $0.000034 |
| `xiaomi/mimo-v2-flash` | 100.0% | 0.0% | 100.0% | 0.891s | 1.152s | $0.000010 | $0.000014 |
| `inception/mercury` | 100.0% | 0.0% | 100.0% | 0.970s | 1.563s | $0.000073 | $0.000088 |
| `google/gemini-2.5-flash` | 100.0% | 0.0% | 100.0% | 0.828s | 1.688s | $0.000111 | $0.000150 |
| `deepseek/deepseek-v3.2` | 100.0% | 0.0% | 100.0% | 2.330s | 4.647s | $0.000044 | $0.000055 |

- Recommendation: `google/gemini-2.5-flash-lite`
- Rationale: passed quality target 90%; best p95 latency 0.843s; mean cost $0.000029
- Quality target: 90%

## Enhance Results

| Model | Quality pass | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Cost p95 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `google/gemini-2.5-flash-lite` | 100.0% | 0.0% | 100.0% | 0.614s | 1.006s | $0.000025 | $0.000038 |
| `google/gemini-2.5-flash` | 100.0% | 0.0% | 100.0% | 0.875s | 1.029s | $0.000107 | $0.000174 |
| `inception/mercury` | 100.0% | 0.0% | 100.0% | 0.863s | 1.464s | $0.000073 | $0.000097 |
| `xiaomi/mimo-v2-flash` | 100.0% | 0.0% | 100.0% | 1.669s | 2.396s | $0.000035 | $0.000054 |
| `deepseek/deepseek-v3.2` | 100.0% | 0.0% | 100.0% | 4.181s | 11.030s | $0.000055 | $0.000089 |

- Recommendation: `google/gemini-2.5-flash-lite`
- Rationale: passed quality target 90%; best p95 latency 1.006s; mean cost $0.000025
- Quality target: 90%

## Manual Spot Checks

### Light (`google/gemini-2.5-flash-lite` / sample `light-01`)

- Transcript:

```
okay so um today i want to talk about the release plan for vox like what we ship first and what we cut
```

- Rewritten:

```
Okay, so today I want to talk about the release plan for Vox. Like, what we ship first and what we cut.
```

### Aggressive (`google/gemini-2.5-flash-lite` / sample `aggressive-01`)

- Transcript:

```
so ive been thinking about how the app feels slow and i think its not the stt anymore its the rewrite step because it waits for the llm and that can take like two seconds sometimes
```

- Rewritten:

```
The app feels slow. It's not the speech-to-text anymore. It's the rewrite step. It waits for the large language model. That takes two seconds sometimes.
```

### Enhance (`google/gemini-2.5-flash-lite` / sample `enhance-01`)

- Transcript:

```
i need you to review a swift file and point out bugs and missing tests and then suggest a safe refactor plan
```

- Rewritten:

```
Review the provided Swift file for bugs and missing tests. Suggest a safe refactoring plan.
```

## Rollback Plan

- Trigger: rewrite quality complaints increase or quality-gate fallback rate regresses after rollout.
- Immediate rollback: restore prior defaults in `Sources/VoxCore/ProcessingLevel.swift`.
- Validation after rollback: run strict build/tests and compare rewrite latency logs against baseline.

## Raw Artifact

- `/Users/phaedrus/Development/vox/docs/performance/rewrite-corpus.json`
- JSON results committed separately in `docs/performance/` for reproducibility.