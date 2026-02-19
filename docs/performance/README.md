# Performance

Two complementary lanes:

1. **Pipeline overhead** (mock providers, deterministic): `./scripts/benchmark.sh`
2. **Live provider latency** (real STT + rewrite): `swift run VoxPerfAudit ...`

## Live Perf Audit (Local)

Notes:
- Measures **batch STT** (file upload), not streaming STT.
- To force the batch STT provider in a run: `VOX_PERF_STT_PROVIDER=auto|elevenlabs|deepgram`.
- `auto` keeps preference order (`ElevenLabs -> Deepgram`); forcing sets `sttSelectionPolicy=forced` in the JSON output.

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

Each NDJSON line is:

```json
{
  "schemaVersion": 1,
  "appVersion": "0.4.0",
  "appBuild": "123",
  "osVersion": "macOS ...",
  "event": {
    "timestamp": "2026-02-19T02:00:00Z",
    "name": "pipeline_timing",
    "sessionID": "uuid",
    "fields": {
      "processing_level": "clean",
      "total_ms": 1234,
      "total_stage_ms": 1180,
      "encode_ms": 20,
      "stt_ms": 680,
      "rewrite_ms": 430,
      "paste_ms": 50,
      "original_bytes": 160000,
      "encoded_bytes": 42000
    }
  }
}
```
