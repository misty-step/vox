# Verification and Safety

## LLM-first policy
- Meaning preservation is non-negotiable
- Prompt and model selection carry the burden

## Fallback ladder
- If rewrite fails or times out: raw transcript
- If STT fails: insert nothing + error flash

## Telemetry
- Count rewrite failures
- Count raw-transcript fallbacks
- Capture latency buckets (no raw text in logs)
