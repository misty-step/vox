# Performance

Two complementary lanes:

1. **Pipeline overhead** (mock providers, deterministic): `./scripts/benchmark.sh`
2. **Live + deterministic lane audit** (real provider lane + deterministic codepath lane): `swift run VoxPerfAudit ...`

## Live Perf Audit (Local)

Notes:
- Measures **batch STT** (file upload), not streaming STT.
- To force the batch STT provider in a run: `VOX_PERF_STT_PROVIDER=auto|elevenlabs|deepgram`.
- `auto` keeps preference order (`ElevenLabs -> Deepgram`); forcing sets `sttSelectionPolicy=forced` in the JSON output.

```bash
bash scripts/perf/make-fixture-audio.sh --variant short /tmp/vox-perf-short.caf
bash scripts/perf/make-fixture-audio.sh --variant medium /tmp/vox-perf-medium.caf
swift run VoxPerfAudit \
  --lane provider \
  --audio /tmp/vox-perf-short.caf \
  --audio /tmp/vox-perf-medium.caf \
  --output /tmp/vox-perf-provider.json \
  --iterations 5 \
  --warmup 1
swift run VoxPerfAudit \
  --lane codepath \
  --audio /tmp/vox-perf-short.caf \
  --audio /tmp/vox-perf-medium.caf \
  --output /tmp/vox-perf-codepath.json \
  --iterations 5 \
  --warmup 1
python3 scripts/perf/format-perf-report.py \
  --head /tmp/vox-perf-provider.json \
  --codepath-head /tmp/vox-perf-codepath.json
```

## CI

Workflow: `.github/workflows/perf-audit.yml`

- Posts a PR comment report on every PR.
- Runs both lanes per PR with two fixtures (`short`, `medium`) and warmup exclusion.
- Uses weighted fixture aggregation (by audio bytes) with per-fixture breakdown.
- Includes plain-language trend + status semantics (`improved|neutral|regressed`) and confidence labels.
- Falls back to nearest persisted master ancestor when exact base SHA is unavailable.
- On `master` pushes, writes a durable JSON artifact to [`misty-step/vox-perf-audit`](https://github.com/misty-step/vox-perf-audit): `audit/<commit>.json`.
- On PR runs, persists `head.json` to [`misty-step/vox-perf-audit`](https://github.com/misty-step/vox-perf-audit) via `.github/workflows/perf-audit-persist.yml`: `audit/pr/<pr>/<commit>.json`.
- PR artifact routing (`<pr>`, `<commit>`) is derived from trusted `workflow_run` event metadata, not from artifact JSON fields.

## Perf Audit Store

Artifacts live at **[misty-step/vox-perf-audit](https://github.com/misty-step/vox-perf-audit)** — a dedicated append-only repo.

```text
audit/
  <commit-sha>.json              # master push (provider lane)
  pr/
    <pr-number>/
      <commit-sha>.json          # PR run (provider lane)
      <commit-sha>-codepath.json # PR run (deterministic lane)
```

Retention policy: never rewrite, only append. Artifacts are permanent.

Requires `PERF_AUDIT_TOKEN` secret in this repo (a PAT with `contents: write` on `vox-perf-audit`).
If `PERF_AUDIT_TOKEN` is missing, persist steps log a skip message and exit 0.

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
