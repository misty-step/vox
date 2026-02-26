# Rewrite Model Bakeoff

- Generated: 2026-02-26T03:37:47Z
- Iterations per sample: 2
- Corpus entries: 20
- Candidate models: apple/foundation-models, inception/mercury

## Methodology
- Uses production rewrite prompts from `RewritePrompts` per processing level.
- Evaluates quality with `RewriteQualityGate` pass/fail and ratio checks.
- Measures wall-clock request latency and OpenRouter-reported request cost.
- Decision rule: filter by quality target, pick lowest p95 latency, tie-break by mean cost.

## Clean Results

| Model | Quality pass | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Cost p95 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `inception/mercury` | 100.0% | 0.0% | 100.0% | 0.530s | 0.778s | $0.000171 | $0.000178 |
| `apple/foundation-models` | 70.0% | 0.0% | 100.0% | 1.016s | 7.738s | n/a | n/a |

- Recommendation: `inception/mercury`
- Rationale: passed quality target 95%; best p95 latency 0.778s; mean cost $0.000171
- Quality target: 95%

## Polish Results

| Model | Quality pass | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Cost p95 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `inception/mercury` | 100.0% | 0.0% | 100.0% | 0.595s | 0.695s | $0.000159 | $0.000183 |
| `apple/foundation-models` | 50.0% | 0.0% | 100.0% | 1.669s | 9.483s | n/a | n/a |

- Recommendation: `inception/mercury`
- Rationale: passed quality target 90%; best p95 latency 0.695s; mean cost $0.000159
- Quality target: 90%

## Manual Spot Checks

### Clean (`inception/mercury` / sample `clean-01`)

- Transcript:

```
okay so um today i want to talk about the release plan for vox like what we ship first and what we cut
```

- Rewritten:

```
Okay, today I want to talk about the release plan for Vox: what we ship first and what we cut.
```

### Polish (`inception/mercury` / sample `polish-01`)

- Transcript:

```
so ive been thinking about how the app feels slow and i think its not the stt anymore its the rewrite step because it waits for the llm and that can take like two seconds sometimes
```

- Rewritten:

```
**Performance Observation**

- The app feels sluggish.
- The slowdown is not due to the speech‑to‑text (STT) component.
- Instead, the delay occurs during the rewrite step.
- The rewrite step waits for the large‑language model (LLM) to respond.
- The LLM latency can be around two seconds, causing the perceived lag.
```

## Rollback Plan

- Trigger: rewrite quality complaints increase or quality-gate fallback rate regresses after rollout.
- Immediate rollback: restore prior defaults in `Sources/VoxCore/ProcessingLevel.swift`.
- Validation after rollback: run strict build/tests and compare rewrite latency logs against baseline.

## Raw Artifact

- `/Users/phaedrus/Development/vox-mono/vox/docs/performance/rewrite-corpus.json`
- JSON results committed separately in `docs/performance/` for reproducibility.