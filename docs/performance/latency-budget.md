# Latency Budget

Vox dictation pipeline latency SLOs and measurement methodology.

## SLOs

Targets for short clips (< 30s recording):

| Stage | p50 | p95 |
|-------|-----|-----|
| **Total** (stage sum: encode + stt + rewrite + paste) | ≤ 1.2s | ≤ 2.5s |
| Paste | — | ≤ 80ms |
| Rewrite (clean) | — | ≤ 900ms |
| Rewrite (polish) | — | ≤ 1.5s |

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

`PipelineBenchmarkTests` are opt-in and are skipped during normal `swift test` runs.
`./scripts/benchmark.sh` enables them by setting `VOX_RUN_BENCHMARK_TESTS=1`.

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

CI does not gate on run-to-run variance because hosted runner scheduler jitter can dominate deterministic mock delays.

## Rewrite Model Bakeoff (Manual)

Rewrite p95 latency is often dominated by the selected OpenRouter model. For data-backed defaults, run:

```bash
swift run VoxBenchmarks
```

Inputs:
- `docs/performance/rewrite-corpus.json`

Outputs (dated):
- `docs/performance/rewrite-benchmark-results-YYYY-MM-DD.json`
- `docs/performance/rewrite-model-bakeoff-YYYY-MM-DD.md`

## Live Perf Audit

CI runs a live perf audit (real STT + rewrite) and posts a PR comment report.

Durable JSON artifacts are persisted in `misty-step/vox-perf-audit`:
- Baselines for `master`: `audit/<commit>.json`
- PR heads: `audit/pr/<pr-number>/<commit>.json`

Quick fetch example:

```bash
gh api -H "Accept: application/vnd.github.raw" repos/misty-step/vox-perf-audit/contents/audit/<commit>.json
```

See `docs/performance/README.md` and `.github/workflows/perf-audit.yml`.
