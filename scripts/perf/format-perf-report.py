#!/usr/bin/env python3
"""
Format a VoxPerfAudit JSON run (optionally diffed vs a baseline) into a PR-comment markdown report.

No deps. Avoids transcript content by design (inputs are timing-only JSON).
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Optional


@dataclass(frozen=True)
class Dist:
    p50: float
    p95: float
    min: float
    max: float


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def get_level(run: dict[str, Any], level: str) -> dict[str, Any]:
    for entry in run.get("levels", []):
        if entry.get("level") == level:
            return entry
    raise KeyError(f"missing level '{level}'")


def dist(level_entry: dict[str, Any], key: str) -> Dist:
    d = level_entry["distributions"][key]
    return Dist(p50=float(d["p50"]), p95=float(d["p95"]), min=float(d["min"]), max=float(d["max"]))


def fmt_ms(x: float) -> str:
    # Stable, easy-to-scan formatting. Round to nearest ms.
    return f"{int(round(x))}ms"


def short_sha(sha: Optional[str]) -> str:
    if not sha:
        return "—"
    return sha[:8]


def parse_generated_at(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    text = value.strip()
    if text.endswith("Z"):
        text = f"{text[:-1]}+00:00"
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def load_history_runs(history_dir: Optional[Path]) -> list[dict[str, Any]]:
    if history_dir is None:
        return []
    if not history_dir.exists() or not history_dir.is_dir():
        return []

    runs: list[dict[str, Any]] = []
    for path in sorted(history_dir.glob("*.json")):
        try:
            run = load_json(path)
        except Exception:
            continue
        if not isinstance(run, dict):
            continue
        if not isinstance(run.get("levels"), list):
            continue
        runs.append(run)
    return runs


def dedupe_and_sort_runs(runs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    unique: dict[tuple[str, str], dict[str, Any]] = {}
    for run in runs:
        key = (
            str(run.get("commitSHA") or ""),
            str(run.get("generatedAt") or ""),
        )
        unique[key] = run
    ordered = list(unique.values())
    ordered.sort(
        key=lambda run: (
            parse_generated_at(run.get("generatedAt")) or datetime.min,
            str(run.get("commitSHA") or ""),
        )
    )
    return ordered


def fmt_change(current: float, reference: float) -> str:
    delta = current - reference
    ms = int(round(abs(delta)))
    if ms == 0:
        return "no change"

    direction = "slower" if delta > 0 else "faster"
    if reference > 0:
        pct = abs(delta) / reference * 100
        return f"{ms}ms {direction} ({pct:.1f}%)"
    return f"{ms}ms {direction}"


def fmt_rank(current: float, values: list[float]) -> str:
    better = sum(1 for value in values if value < current)
    return f"{better + 1}/{len(values)}"


def fmt_points(values: list[float]) -> str:
    if not values:
        return "—"
    return " -> ".join(fmt_ms(value) for value in values)


def dominant_stage(stt_p95: float, rewrite_p95: float, encode_p95: float, generation_p95: float) -> str:
    candidates = [
        ("STT", stt_p95),
        ("Rewrite", rewrite_p95),
        ("Encode", encode_p95),
    ]
    name, value = max(candidates, key=lambda item: item[1])
    share = (value / generation_p95 * 100) if generation_p95 > 0 else 0.0
    return f"{name} ({fmt_ms(value)}, {share:.0f}%)"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--head", required=True, help="Head perf JSON path")
    ap.add_argument("--base", required=False, help="Base perf JSON path (optional)")
    ap.add_argument("--out", required=False, help="Output markdown path (optional; else stdout)")
    ap.add_argument("--base-sha", required=False, help="Base SHA display override")
    ap.add_argument("--head-sha", required=False, help="Head SHA display override")
    ap.add_argument("--history-dir", required=False, help="Directory containing prior PR perf JSON files")
    ap.add_argument("--history-max", required=False, type=int, default=10, help="Max points per trend series")
    args = ap.parse_args()

    head_path = Path(args.head)
    head = load_json(head_path)
    base = load_json(Path(args.base)) if args.base else None

    base_sha = args.base_sha or (base.get("commitSHA") if base else None)
    head_sha = args.head_sha or head.get("commitSHA")

    iters = head.get("iterationsPerLevel", "?")
    audio_file = head.get("audioFile", "—")
    audio_bytes = head.get("audioBytes", 0)
    stt_mode = head.get("sttMode") or "—"
    stt_policy = head.get("sttSelectionPolicy") or "—"
    stt_forced = head.get("sttForcedProvider")
    stt_chain = head.get("sttChain") or []
    rewrite_routing = head.get("rewriteRouting") or head.get("rewriteProvider") or "—"

    def fmt_chain(chain: list[dict[str, Any]]) -> str:
        parts: list[str] = []
        for entry in chain:
            provider = str(entry.get("provider") or "—")
            model = str(entry.get("model") or "")
            if model:
                parts.append(f"{provider}({model})")
            else:
                parts.append(provider)
        return " -> ".join(parts) if parts else "—"

    def fmt_usage(items: list[dict[str, Any]], max_items: int = 2) -> str:
        if not items:
            return "—"
        # Prefer highest-count entries.
        items_sorted = sorted(items, key=lambda x: (int(x.get("count", 0)), str(x.get("provider", "")), str(x.get("model", ""))), reverse=True)
        rendered: list[str] = []
        for it in items_sorted[:max_items]:
            provider = str(it.get("provider") or it.get("path") or "—")
            model = str(it.get("model") or "—")
            count = int(it.get("count", 0))
            rendered.append(f"{provider}({model}) x{count}")
        if len(items_sorted) > max_items:
            rendered.append(f"+{len(items_sorted) - max_items} more")
        return ", ".join(rendered)

    levels = ["raw", "clean", "polish"]
    head_rows: dict[str, dict[str, Any]] = {}
    provider_rows: dict[str, tuple[str, str]] = {}
    for lvl in levels:
        level_entry = get_level(head, lvl)
        providers = level_entry.get("providers") or {}
        stt_obs = providers.get("sttObserved") or []
        rw_obs = providers.get("rewriteObserved") or []

        if not providers:
            # schema v1 back-compat
            stt_text = head.get("sttProvider", "—")
            rw_text = "—" if lvl == "raw" else head.get("rewriteProvider", "—")
        else:
            stt_text = fmt_usage(stt_obs)
            rw_text = "—" if lvl == "raw" else fmt_usage(rw_obs)

        gen = dist(level_entry, "generationMs")
        stt = dist(level_entry, "sttMs")
        rw = dist(level_entry, "rewriteMs")
        enc = dist(level_entry, "encodeMs")

        head_rows[lvl] = {
            "gen": gen,
            "stt": stt,
            "rw": rw,
            "enc": enc,
            "dominant": dominant_stage(stt.p95, rw.p95, enc.p95, gen.p95),
        }
        provider_rows[lvl] = (stt_text, rw_text)

    history_dir = Path(args.history_dir) if args.history_dir else None
    history_runs = load_history_runs(history_dir)
    trend_runs = dedupe_and_sort_runs(history_runs + [head])
    history_max = max(2, args.history_max)

    metric_keys = {
        "generation": "generationMs",
        "stt": "sttMs",
        "rewrite": "rewriteMs",
        "encode": "encodeMs",
    }
    trend_metrics: dict[str, dict[str, list[float]]] = {}
    for lvl in levels:
        metric_series: dict[str, list[float]] = {key: [] for key in metric_keys}
        for run in trend_runs:
            try:
                entry = get_level(run, lvl)
            except KeyError:
                continue
            for metric, metric_key in metric_keys.items():
                metric_series[metric].append(dist(entry, metric_key).p95)
        trend_metrics[lvl] = {metric: values[-history_max:] for metric, values in metric_series.items()}

    lines: list[str] = []
    lines.append("<!-- vox-perf-audit -->")
    lines.append("## Performance Report")
    lines.append("")
    lines.append("> Lower latency is better for every number in this report.")
    lines.append("> Generation = encode + STT + rewrite. Raw level intentionally has no rewrite stage.")
    lines.append("> CI paste timings are no-op and excluded from decision-making.")
    lines.append("")

    lines.append("### Executive Summary (Generation p95)")
    lines.append("")
    lines.append("| Level | Latest | Vs previous run | Vs best run | Rank in PR window |")
    lines.append("| --- | ---: | --- | --- | ---: |")
    for lvl in levels:
        series = trend_metrics.get(lvl, {}).get("generation", [])
        latest = head_rows[lvl]["gen"].p95

        if len(series) >= 2:
            prev = series[-2]
            best = min(series)
            vs_prev = fmt_change(latest, prev)
            best_delta = int(round(latest - best))
            vs_best = "best in window" if best_delta == 0 else fmt_change(latest, best)
            rank = fmt_rank(latest, series)
        else:
            vs_prev = "n/a (first run)"
            vs_best = "n/a (first run)"
            rank = f"1/{max(1, len(series))}"

        lines.append(f"| {lvl} | {fmt_ms(latest)} | {vs_prev} | {vs_best} | {rank} |")
    lines.append("")

    lines.append("### Current Run Snapshot")
    lines.append("")
    lines.append("| Level | Generation p50 | Generation p95 | STT p95 | Rewrite p95 | Encode p95 | Dominant stage |")
    lines.append("| --- | ---: | ---: | ---: | ---: | ---: | --- |")
    for lvl in levels:
        gen = head_rows[lvl]["gen"]
        stt = head_rows[lvl]["stt"]
        rw = head_rows[lvl]["rw"]
        enc = head_rows[lvl]["enc"]
        dominant = head_rows[lvl]["dominant"]
        lines.append(
            f"| {lvl} | {fmt_ms(gen.p50)} | {fmt_ms(gen.p95)} | {fmt_ms(stt.p95)} | {fmt_ms(rw.p95)} | {fmt_ms(enc.p95)} | {dominant} |"
        )
    lines.append("")

    lines.append("### Stage Changes Vs Previous Run (p95)")
    lines.append("")
    lines.append("| Level | STT | Rewrite | Encode |")
    lines.append("| --- | --- | --- | --- |")
    for lvl in levels:
        stt_series = trend_metrics.get(lvl, {}).get("stt", [])
        rewrite_series = trend_metrics.get(lvl, {}).get("rewrite", [])
        encode_series = trend_metrics.get(lvl, {}).get("encode", [])
        if len(stt_series) < 2:
            lines.append(f"| {lvl} | n/a | n/a | n/a |")
            continue

        stt_change = fmt_change(stt_series[-1], stt_series[-2])
        rewrite_change = "n/a (raw level)" if lvl == "raw" else fmt_change(rewrite_series[-1], rewrite_series[-2])
        encode_change = fmt_change(encode_series[-1], encode_series[-2])
        lines.append(f"| {lvl} | {stt_change} | {rewrite_change} | {encode_change} |")
    lines.append("")

    lines.append("### PR Trend Window (Generation p95)")
    lines.append("")
    lines.append(f"Window includes persisted runs for this PR plus current head (max {history_max} points per level).")
    lines.append("")
    lines.append("| Level | Runs | Latest | Change vs previous | Vs mean | Vs best | Vs worst |")
    lines.append("| --- | ---: | ---: | --- | --- | --- | --- |")
    for lvl in levels:
        series = trend_metrics.get(lvl, {}).get("generation", [])
        if len(series) < 2:
            latest = head_rows[lvl]["gen"].p95
            lines.append(f"| {lvl} | {len(series)} | {fmt_ms(latest)} | n/a | n/a | n/a | n/a |")
            continue

        latest = series[-1]
        prev = series[-2]
        mean = sum(series) / len(series)
        best = min(series)
        worst = max(series)

        best_delta = int(round(latest - best))
        worst_delta = int(round(latest - worst))
        vs_best = "best in window" if best_delta == 0 else fmt_change(latest, best)
        vs_worst = "worst in window" if worst_delta == 0 else fmt_change(latest, worst)

        lines.append(
            f"| {lvl} | {len(series)} | {fmt_ms(latest)} | {fmt_change(latest, prev)} | {fmt_change(latest, mean)} | {vs_best} | {vs_worst} |"
        )
    lines.append("")

    lines.append("<details>")
    lines.append("<summary>Trend points (generation p95, oldest to newest)</summary>")
    lines.append("")
    lines.append("| Level | Points |")
    lines.append("| --- | --- |")
    for lvl in levels:
        lines.append(f"| {lvl} | {fmt_points(trend_metrics.get(lvl, {}).get('generation', []))} |")
    lines.append("")
    lines.append("</details>")
    lines.append("")

    if base:
        lines.append("### Base Branch Comparison (Generation)")
        lines.append("")
        lines.append("| Level | p50 change | p95 change |")
        lines.append("| --- | --- | --- |")
        for lvl in levels:
            b = get_level(base, lvl)
            bgen = dist(b, "generationMs")
            hgen = head_rows[lvl]["gen"]
            lines.append(f"| {lvl} | {fmt_change(hgen.p50, bgen.p50)} | {fmt_change(hgen.p95, bgen.p95)} |")
        lines.append("")
    elif base_sha:
        lines.append("### Base Branch Comparison (Generation)")
        lines.append("")
        lines.append(f"Unavailable for this run: base commit `{short_sha(base_sha)}` is not in the perf baseline store.")
        lines.append("")

    lines.append("<details>")
    lines.append("<summary>Run context and provider observations</summary>")
    lines.append("")
    lines.append("| Field | Value |")
    lines.append("| --- | --- |")
    lines.append(f"| Head | `{short_sha(head_sha)}` |")
    if base:
        lines.append(f"| Base | `{short_sha(base_sha)}` |")
    elif base_sha:
        lines.append(f"| Base | `{short_sha(base_sha)}` (missing in baseline store) |")
    if stt_chain:
        forced = f", forced={stt_forced}" if stt_forced else ""
        lines.append(f"| STT routing | mode={stt_mode}, policy={stt_policy}{forced}, chain={fmt_chain(stt_chain)} |")
    else:
        # Back-compat for schema v1.
        lines.append(f"| STT routing | {head.get('sttProvider', '—')} |")
    lines.append(f"| Rewrite routing | {rewrite_routing} |")
    lines.append(f"| Fixture | `{audio_file}` ({audio_bytes} bytes) |")
    lines.append(f"| Iterations | {iters} per level |")
    lines.append("")
    lines.append("| Level | STT observed | Rewrite observed |")
    lines.append("| --- | --- | --- |")
    for lvl in levels:
        stt_text, rw_text = provider_rows[lvl]
        lines.append(f"| {lvl} | {stt_text} | {rw_text} |")
    lines.append("")
    lines.append("</details>")
    lines.append("")

    # Durable JSON artifact, stored right in the PR comment.
    head_json = json.dumps(head, indent=2, sort_keys=True)
    lines.append("<details>")
    lines.append("<summary>Head JSON</summary>")
    lines.append("")
    lines.append("```json")
    lines.append(head_json)
    lines.append("```")
    lines.append("</details>")
    lines.append("")

    out = "\n".join(lines)
    if args.out:
        Path(args.out).write_text(out, encoding="utf-8")
    else:
        print(out)


if __name__ == "__main__":
    main()
