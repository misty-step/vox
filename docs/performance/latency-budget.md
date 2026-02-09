# Latency Budget

Vox dictation pipeline latency SLOs and measurement methodology.

## SLOs

Targets for short clips (< 30s recording):

| Stage | p50 | p95 |
|-------|-----|-----|
| **Total** (stop → paste) | ≤ 1.2s | ≤ 2.5s |
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
./scripts/benchmark.sh                 # Run benchmark, print summary
./scripts/benchmark.sh --compare       # Compare against committed baseline
./scripts/benchmark.sh --json          # Raw JSON output
./scripts/benchmark.sh --update-baseline  # Overwrite baseline.json
```

The benchmark runs `PipelineBenchmarkTests` which:
1. Creates a `DictationPipeline` with mock STT/rewrite providers at configurable delays
2. Runs 20 iterations per test, collecting `PipelineTiming` via `timingHandler`
3. Computes p50/p95/min/max per stage (encode, stt, rewrite, paste, total)
4. Writes JSON artifact to `BENCHMARK_OUTPUT_PATH`

### Stages Measured

| Stage | What it includes |
|-------|-----------------|
| `encode` | Opus compression (CAF → OGG) |
| `stt` | Provider call including hedging/retry/timeout overhead |
| `rewrite` | LLM rewrite including quality gate evaluation |
| `paste` | Clipboard insertion via accessibility API |
| `total` | Sum of all stages |

### Regression Detection

CI compares current run against `docs/performance/baseline.json`:

| Threshold | Action |
|-----------|--------|
| > 20% regression | Warning in CI output |
| > 50% regression | CI step fails |

### Reproducibility

With mock providers at fixed delays, two consecutive runs produce p50 within 15% variance. Variance comes from scheduling jitter only.

## Baseline

Current baseline captured with mock providers (50ms STT + 50ms rewrite delays):

See `baseline.json` in this directory for raw numbers.

## Updating the Baseline

After landing an optimization or changing pipeline structure:

```bash
./scripts/benchmark.sh --update-baseline
git add docs/performance/baseline.json
git commit -m "perf: update latency baseline"
```
