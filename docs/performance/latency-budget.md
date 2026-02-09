# Latency Budget

Vox dictation pipeline latency SLOs and measurement methodology.

## SLOs

Targets for short clips (< 30s recording):

| Stage | p50 | p95 |
|-------|-----|-----|
| **Total** (stage sum: encode + stt + rewrite + paste) | ≤ 1.2s | ≤ 2.5s |
| Paste | — | ≤ 80ms |
| Rewrite (light) | — | ≤ 900ms |
| Rewrite (aggressive) | — | ≤ 1.5s |

These are end-to-end targets including real provider latency. The benchmark harness uses mock providers with configurable delays to measure pipeline framework overhead separately.

## Pipeline Overhead Budget

Framework overhead (everything except provider network latency):

| Metric | Target |
|--------|--------|
| Pipeline overhead p95 | ≤ 50ms |

## Measurement

### Benchmark Harness

```bash
./scripts/benchmark.sh
```

The benchmark runs `PipelineBenchmarkTests` which:
1. Creates a `DictationPipeline` with mock STT/rewrite providers at configurable delays
2. Runs 20 iterations per test, collecting `PipelineTiming` via `timingHandler`
3. Computes p50/p95/min/max per stage (encode, stt, rewrite, paste, total)
4. Asserts overhead and paste budgets via Swift Testing `#expect`

### Stages Measured

| Stage | What it includes |
|-------|-----------------|
| `encode` | Opus compression (CAF → OGG) |
| `stt` | Provider call including hedging/retry/timeout overhead |
| `rewrite` | LLM rewrite including quality gate evaluation |
| `paste` | Clipboard insertion via accessibility API |
| `total` | Sum of `encode + stt + rewrite + paste` |

### Reproducibility

With deterministic mock provider delays, two consecutive runs should produce p50 within 30% variance on CI hosts. Remaining variance is scheduler jitter.
