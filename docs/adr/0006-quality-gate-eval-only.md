# ADR-0006: Quality Gate Restricted to Evaluation and Benchmarks

## Status

Accepted

## Context

`RewriteQualityGate` scores rewrite quality by comparing the candidate output against the raw transcript using Levenshtein distance and content overlap ratios. It was originally enforced in the production pipeline to reject low-quality rewrites and fall back to raw transcript.

Production enforcement caused problems:

1. False rejections — legitimate rewrites that significantly restructured text (e.g., polish level) scored below thresholds despite being correct.
2. User confusion — dictated text would sometimes appear unprocessed with no clear reason.
3. Threshold tuning was fragile — different prompt styles and transcript lengths required different thresholds.

The gate went through three phases:
- **Enforced**: rejected rewrites below threshold, fell back to raw transcript.
- **Diagnostic-only** (#231): logged scores but never rejected, allowing observability without user impact.
- **Removed from production** (#284): gate code retained for eval/benchmark pipelines only.

## Decision

Restrict `RewriteQualityGate` to evaluation and benchmark contexts. Remove all quality gate checks from the production `DictationPipeline`. The gate remains available for:

- `VoxBenchmarks` rewrite model bakeoff CLI
- promptfoo eval framework (smoke, injection, polish datasets)
- Pipeline latency benchmark assertions

## Consequences

### Positive

- No false rejections in production — user always gets the LLM rewrite if one was requested.
- Simpler production pipeline with fewer failure modes.
- Gate still provides value in eval/CI where controlled inputs make threshold comparison meaningful.

### Negative

- Low-quality rewrites can reach the user without automated guardrails.
- Quality regression detection shifts entirely to eval suite and manual observation.
