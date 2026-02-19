# Performance

Two complementary lanes:

1. **Pipeline overhead** (mock providers, deterministic): `./scripts/benchmark.sh`
2. **Live provider latency** (real STT + rewrite): `swift run VoxPerfAudit ...`

## Live Perf Audit (Local)

Notes:
- Measures **batch STT** (file upload), not streaming STT.
- To force the batch STT provider in a run: `VOX_PERF_STT_PROVIDER=auto|elevenlabs|deepgram`.

```bash
bash scripts/perf/make-fixture-audio.sh /tmp/vox-perf-fixture.caf
swift run VoxPerfAudit --audio /tmp/vox-perf-fixture.caf --output /tmp/vox-perf.json --iterations 2
python3 scripts/perf/format-perf-report.py --head /tmp/vox-perf.json
```

## CI

Workflow: `.github/workflows/perf-audit.yml`

- Posts a PR comment report on every PR (skips cleanly if secrets are unavailable).
- On `master` pushes, writes a durable JSON artifact to `perf-audit` branch: `audit/<commit>.json`.
- On PR runs, persists `head.json` to `perf-audit` via `.github/workflows/perf-audit-persist.yml`: `audit/pr/<pr>/<commit>.json`.

## Runtime Perf Upload (Opt-In)

Set `VOX_PERF_INGEST_URL` to POST `pipeline_timing` events as NDJSON.

- Disabled by default.
- Payload is privacy-safe (no transcript text, no API keys).
