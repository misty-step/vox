#!/usr/bin/env python3
"""
Format Vox perf JSON into a PR comment report.

Supports:
- Provider lane (live network timing)
- Codepath lane (deterministic mock timing)
- Legacy v2 runs (single fixture, provider-only)
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

LEVELS = ["raw", "clean", "polish"]


@dataclass(frozen=True)
class Dist:
    p50: float
    p95: float
    min: float
    max: float


@dataclass(frozen=True)
class LevelStats:
    level: str
    iterations: int
    providers: dict[str, Any]
    generation: Dist
    stt: Dist
    rewrite: Dist
    encode: Dist


@dataclass(frozen=True)
class FixtureStats:
    fixture_id: str
    audio_file: str
    audio_bytes: int
    levels: dict[str, LevelStats]


@dataclass(frozen=True)
class LaneSnapshot:
    lane: str
    run: dict[str, Any]
    levels: dict[str, LevelStats]
    fixtures: list[FixtureStats]
    iterations_per_fixture: int
    warmup_per_fixture: int
    stt_mode: str
    stt_policy: str
    stt_forced: Optional[str]
    stt_chain: list[dict[str, Any]]
    rewrite_routing: str


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def parse_generated_at(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    text = value.strip()
    if text.endswith("Z"):
        text = f"{text[:-1]}+00:00"
    try:
        parsed = datetime.fromisoformat(text)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    except ValueError:
        return None


def short_sha(sha: Optional[str]) -> str:
    if not sha:
        return "—"
    return sha[:8]


def fmt_ms(x: float) -> str:
    return f"{int(round(x))}ms"


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


def fmt_points(values: list[float]) -> str:
    if not values:
        return "—"
    return " -> ".join(fmt_ms(value) for value in values)


def fmt_chain(chain: list[dict[str, Any]]) -> str:
    parts: list[str] = []
    for entry in chain:
        provider = str(entry.get("provider") or "—")
        model = str(entry.get("model") or "")
        parts.append(f"{provider}({model})" if model else provider)
    return " -> ".join(parts) if parts else "—"


def fmt_usage(items: list[dict[str, Any]], max_items: int = 2) -> str:
    if not items:
        return "—"
    items_sorted = sorted(
        items,
        key=lambda x: (
            int(x.get("count", 0)),
            str(x.get("provider", x.get("path", ""))),
            str(x.get("model", "")),
        ),
        reverse=True,
    )
    rendered: list[str] = []
    for item in items_sorted[:max_items]:
        provider = str(item.get("provider") or item.get("path") or "—")
        model = str(item.get("model") or "—")
        count = int(item.get("count", 0))
        rendered.append(f"{provider}({model}) x{count}")
    if len(items_sorted) > max_items:
        rendered.append(f"+{len(items_sorted) - max_items} more")
    return ", ".join(rendered)


def variability(dist: Dist) -> float:
    return max(0.0, dist.p95 - dist.p50)


def dominant_stage(generation: Dist, stt: Dist, rewrite: Dist, encode: Dist) -> str:
    candidates = [("STT", stt.p95), ("Rewrite", rewrite.p95), ("Encode", encode.p95)]
    name, value = max(candidates, key=lambda item: item[1])
    share = (value / generation.p95 * 100) if generation.p95 > 0 else 0.0
    return f"{name} ({fmt_ms(value)}, {share:.0f}%)"


def change_status(latest: float, previous: float) -> str:
    if previous <= 0:
        return "neutral"
    delta = latest - previous
    pct = abs(delta) / previous
    if delta > 200 and pct > 0.10:
        return "regressed"
    if delta < -200 and pct > 0.10:
        return "improved"
    return "neutral"


def confidence_label(samples: int, spread: float, p95: float) -> str:
    if p95 <= 0:
        return "low"
    spread_ratio = spread / p95
    if samples >= 10 and spread_ratio <= 0.20:
        return "high"
    if samples >= 6 and spread_ratio <= 0.40:
        return "medium"
    return "low"


def lane_name_for_run(run: dict[str, Any]) -> str:
    lane = str(run.get("lane") or "").strip().lower()
    if lane in {"provider", "codepath"}:
        return lane
    return "provider"


def dist_from_level(level_entry: dict[str, Any], key: str) -> Dist:
    d = level_entry.get("distributions", {}).get(key) or {}
    return Dist(
        p50=float(d.get("p50", 0.0)),
        p95=float(d.get("p95", 0.0)),
        min=float(d.get("min", 0.0)),
        max=float(d.get("max", 0.0)),
    )


def level_stats_from_entry(level_entry: dict[str, Any]) -> LevelStats:
    return LevelStats(
        level=str(level_entry.get("level", "")),
        iterations=int(level_entry.get("iterations", 0)),
        providers=level_entry.get("providers") or {},
        generation=dist_from_level(level_entry, "generationMs"),
        stt=dist_from_level(level_entry, "sttMs"),
        rewrite=dist_from_level(level_entry, "rewriteMs"),
        encode=dist_from_level(level_entry, "encodeMs"),
    )


def weighted_avg(values: list[float], weights: list[float]) -> float:
    if not values:
        return 0.0
    total_weight = sum(weights)
    if total_weight <= 0:
        return sum(values) / len(values)
    return sum(value * weight for value, weight in zip(values, weights)) / total_weight


def weighted_dist(dists: list[Dist], weights: list[float]) -> Dist:
    if not dists:
        return Dist(0.0, 0.0, 0.0, 0.0)
    return Dist(
        p50=weighted_avg([d.p50 for d in dists], weights),
        p95=weighted_avg([d.p95 for d in dists], weights),
        min=min(d.min for d in dists),
        max=max(d.max for d in dists),
    )


def build_snapshot(run: dict[str, Any]) -> Optional[LaneSnapshot]:
    if not isinstance(run, dict):
        return None

    lane = lane_name_for_run(run)
    top_levels_raw = run.get("levels")
    if not isinstance(top_levels_raw, list):
        return None

    top_level_map: dict[str, LevelStats] = {}
    for entry in top_levels_raw:
        if not isinstance(entry, dict):
            continue
        stats = level_stats_from_entry(entry)
        if stats.level:
            top_level_map[stats.level] = stats

    fixture_results_raw = run.get("fixtureResults")
    fixtures: list[FixtureStats] = []
    if isinstance(fixture_results_raw, list) and fixture_results_raw:
        for index, fixture in enumerate(fixture_results_raw):
            if not isinstance(fixture, dict):
                continue
            fixture_levels_raw = fixture.get("levels")
            if not isinstance(fixture_levels_raw, list):
                continue
            level_map: dict[str, LevelStats] = {}
            for entry in fixture_levels_raw:
                if not isinstance(entry, dict):
                    continue
                stats = level_stats_from_entry(entry)
                if stats.level:
                    level_map[stats.level] = stats

            fixture_id = str(fixture.get("fixtureID") or f"fixture-{index + 1}")
            audio_file = str(fixture.get("audioFile") or fixture_id)
            audio_bytes = int(fixture.get("audioBytes") or 0)
            fixtures.append(
                FixtureStats(
                    fixture_id=fixture_id,
                    audio_file=audio_file,
                    audio_bytes=audio_bytes,
                    levels=level_map,
                )
            )
    else:
        audio_file = str(run.get("audioFile") or "fixture")
        audio_bytes = int(run.get("audioBytes") or 0)
        fixtures.append(
            FixtureStats(
                fixture_id=audio_file,
                audio_file=audio_file,
                audio_bytes=audio_bytes,
                levels=top_level_map,
            )
        )

    # Weighted aggregate for v3 runs; fallback to top-level for legacy runs.
    aggregated_levels: dict[str, LevelStats] = {}
    if fixtures and isinstance(fixture_results_raw, list) and fixture_results_raw:
        for level in LEVELS:
            level_rows = [fixture.levels[level] for fixture in fixtures if level in fixture.levels]
            if not level_rows:
                continue
            weights = [float(max(1, fixture.audio_bytes)) for fixture in fixtures if level in fixture.levels]
            providers = top_level_map.get(level).providers if level in top_level_map else level_rows[0].providers
            aggregated_levels[level] = LevelStats(
                level=level,
                iterations=sum(row.iterations for row in level_rows),
                providers=providers,
                generation=weighted_dist([row.generation for row in level_rows], weights),
                stt=weighted_dist([row.stt for row in level_rows], weights),
                rewrite=weighted_dist([row.rewrite for row in level_rows], weights),
                encode=weighted_dist([row.encode for row in level_rows], weights),
            )
    else:
        aggregated_levels = top_level_map

    return LaneSnapshot(
        lane=lane,
        run=run,
        levels=aggregated_levels,
        fixtures=fixtures,
        iterations_per_fixture=int(run.get("iterationsPerLevel") or 0),
        warmup_per_fixture=int(run.get("warmupIterationsPerLevel") or 0),
        stt_mode=str(run.get("sttMode") or "—"),
        stt_policy=str(run.get("sttSelectionPolicy") or "—"),
        stt_forced=run.get("sttForcedProvider"),
        stt_chain=run.get("sttChain") or [],
        rewrite_routing=str(run.get("rewriteRouting") or run.get("rewriteProvider") or "—"),
    )


def load_history_runs(history_dir: Optional[Path]) -> list[dict[str, Any]]:
    if history_dir is None or not history_dir.exists() or not history_dir.is_dir():
        return []
    runs: list[dict[str, Any]] = []
    for path in sorted(history_dir.glob("*.json")):
        try:
            run = load_json(path)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"[perf-report] skipped history file {path}: {exc}", file=sys.stderr)
            continue
        if isinstance(run, dict):
            runs.append(run)
    return runs


def dedupe_and_sort_runs(runs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    unique: dict[tuple[str, str, str], dict[str, Any]] = {}
    for run in runs:
        key = (
            str(run.get("commitSHA") or ""),
            str(run.get("generatedAt") or ""),
            lane_name_for_run(run),
        )
        unique[key] = run
    ordered = list(unique.values())
    ordered.sort(
        key=lambda run: (
            parse_generated_at(run.get("generatedAt")) or datetime.min.replace(tzinfo=timezone.utc),
            str(run.get("commitSHA") or ""),
            lane_name_for_run(run),
        )
    )
    return ordered


def trend_series(
    snapshots: list[LaneSnapshot],
    lane: str,
    level: str,
    metric: str,
    max_points: int,
) -> list[float]:
    values: list[float] = []
    for snapshot in snapshots:
        if snapshot.lane != lane:
            continue
        row = snapshot.levels.get(level)
        if row is None:
            continue
        if metric == "generation":
            values.append(row.generation.p95)
        elif metric == "stt":
            values.append(row.stt.p95)
        elif metric == "rewrite":
            values.append(row.rewrite.p95)
        elif metric == "encode":
            values.append(row.encode.p95)
    return values[-max_points:]


def render_fixture_table(lines: list[str], snapshot: LaneSnapshot) -> None:
    if not snapshot.fixtures:
        return
    total_bytes = sum(max(0, fixture.audio_bytes) for fixture in snapshot.fixtures)
    lines.append("#### Fixture Breakdown")
    lines.append("")
    lines.append("| Fixture | Bytes | Weight | raw p95 | clean p95 | polish p95 |")
    lines.append("| --- | ---: | ---: | ---: | ---: | ---: |")
    for fixture in snapshot.fixtures:
        weight = (fixture.audio_bytes / total_bytes * 100) if total_bytes > 0 else 0.0
        raw = fixture.levels.get("raw")
        clean = fixture.levels.get("clean")
        polish = fixture.levels.get("polish")
        lines.append(
            f"| {fixture.audio_file} | {fixture.audio_bytes} | {weight:.1f}% | "
            f"{fmt_ms(raw.generation.p95) if raw else '—'} | "
            f"{fmt_ms(clean.generation.p95) if clean else '—'} | "
            f"{fmt_ms(polish.generation.p95) if polish else '—'} |"
        )
    lines.append("")


def render_lane_section(
    lines: list[str],
    title: str,
    snapshot: LaneSnapshot,
    history_snapshots: list[LaneSnapshot],
    history_max: int,
    base_snapshot: Optional[LaneSnapshot] = None,
) -> None:
    lines.append(f"### {title}")
    lines.append("")
    fixture_count = len(snapshot.fixtures)
    lines.append(
        f"Weighted aggregate across {fixture_count} fixture(s) by audio bytes; "
        f"{snapshot.iterations_per_fixture} measured + {snapshot.warmup_per_fixture} warmup iteration(s) per level+fixture."
    )
    lines.append("")

    lines.append("| Level | Latest p95 | Status vs prev | Change vs prev | Confidence |")
    lines.append("| --- | ---: | --- | --- | --- |")
    for level in LEVELS:
        row = snapshot.levels.get(level)
        if row is None:
            lines.append(f"| {level} | — | n/a | n/a | low |")
            continue
        series = trend_series(history_snapshots, snapshot.lane, level, "generation", history_max)
        if len(series) >= 2:
            prev = series[-2]
            status = change_status(series[-1], prev)
            change = fmt_change(series[-1], prev)
        else:
            status = "n/a"
            change = "n/a"
        confidence = confidence_label(row.iterations, variability(row.generation), row.generation.p95)
        lines.append(f"| {level} | {fmt_ms(row.generation.p95)} | {status} | {change} | {confidence} |")
    lines.append("")

    lines.append("| Level | Gen p50 | Gen p95 | Gen var (p95-p50) | STT p95 (var) | Rewrite p95 (var) | Encode p95 (var) | Dominant stage |")
    lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |")
    for level in LEVELS:
        row = snapshot.levels.get(level)
        if row is None:
            lines.append(f"| {level} | — | — | — | — | — | — | — |")
            continue
        lines.append(
            f"| {level} | {fmt_ms(row.generation.p50)} | {fmt_ms(row.generation.p95)} | {fmt_ms(variability(row.generation))} | "
            f"{fmt_ms(row.stt.p95)} ({fmt_ms(variability(row.stt))}) | "
            f"{fmt_ms(row.rewrite.p95)} ({fmt_ms(variability(row.rewrite))}) | "
            f"{fmt_ms(row.encode.p95)} ({fmt_ms(variability(row.encode))}) | "
            f"{dominant_stage(row.generation, row.stt, row.rewrite, row.encode)} |"
        )
    lines.append("")

    lines.append("| Level | Runs | Latest | Vs mean | Vs best | Vs worst |")
    lines.append("| --- | ---: | ---: | --- | --- | --- |")
    for level in LEVELS:
        series = trend_series(history_snapshots, snapshot.lane, level, "generation", history_max)
        if not series:
            lines.append(f"| {level} | 0 | — | n/a | n/a | n/a |")
            continue
        latest = series[-1]
        mean = sum(series) / len(series)
        best = min(series)
        worst = max(series)
        vs_best = "best in window" if int(round(latest - best)) == 0 else fmt_change(latest, best)
        vs_worst = "worst in window" if int(round(latest - worst)) == 0 else fmt_change(latest, worst)
        lines.append(
            f"| {level} | {len(series)} | {fmt_ms(latest)} | {fmt_change(latest, mean)} | {vs_best} | {vs_worst} |"
        )
    lines.append("")

    lines.append("<details>")
    lines.append(f"<summary>{title}: trend points (generation p95, oldest to newest)</summary>")
    lines.append("")
    lines.append("| Level | Points |")
    lines.append("| --- | --- |")
    for level in LEVELS:
        series = trend_series(history_snapshots, snapshot.lane, level, "generation", history_max)
        lines.append(f"| {level} | {fmt_points(series)} |")
    lines.append("")
    lines.append("</details>")
    lines.append("")

    render_fixture_table(lines, snapshot)

    if base_snapshot and base_snapshot.lane == snapshot.lane:
        lines.append("#### Base Branch Comparison (weighted)")
        lines.append("")
        lines.append("| Level | p50 change | p95 change | Status |")
        lines.append("| --- | --- | --- | --- |")
        for level in LEVELS:
            current_row = snapshot.levels.get(level)
            base_row = base_snapshot.levels.get(level)
            if not current_row or not base_row:
                lines.append(f"| {level} | n/a | n/a | n/a |")
                continue
            status = change_status(current_row.generation.p95, base_row.generation.p95)
            lines.append(
                f"| {level} | {fmt_change(current_row.generation.p50, base_row.generation.p50)} | "
                f"{fmt_change(current_row.generation.p95, base_row.generation.p95)} | {status} |"
            )
        lines.append("")

    lines.append("<details>")
    lines.append(f"<summary>{title}: routing + provider observations</summary>")
    lines.append("")
    lines.append("| Field | Value |")
    lines.append("| --- | --- |")
    lines.append(f"| Lane | {snapshot.lane} |")
    lines.append(f"| STT routing | mode={snapshot.stt_mode}, policy={snapshot.stt_policy}" + (f", forced={snapshot.stt_forced}" if snapshot.stt_forced else "") + f", chain={fmt_chain(snapshot.stt_chain)} |")
    lines.append(f"| Rewrite routing | {snapshot.rewrite_routing} |")
    lines.append("")
    lines.append("| Level | STT observed | Rewrite observed |")
    lines.append("| --- | --- | --- |")
    for level in LEVELS:
        row = snapshot.levels.get(level)
        providers = row.providers if row else {}
        stt_obs = providers.get("sttObserved") if isinstance(providers, dict) else []
        rw_obs = providers.get("rewriteObserved") if isinstance(providers, dict) else []
        lines.append(f"| {level} | {fmt_usage(stt_obs or [])} | {'—' if level == 'raw' else fmt_usage(rw_obs or [])} |")
    lines.append("")
    lines.append("</details>")
    lines.append("")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--head", required=True, help="Primary head perf JSON path")
    ap.add_argument("--codepath-head", required=False, help="Optional codepath lane perf JSON path")
    ap.add_argument("--base", required=False, help="Base perf JSON path (optional)")
    ap.add_argument("--out", required=False, help="Output markdown path (optional; else stdout)")
    ap.add_argument("--base-sha", required=False, help="Resolved base SHA")
    ap.add_argument("--requested-base-sha", required=False, help="Requested base SHA")
    ap.add_argument("--base-mode", required=False, default="missing", help="exact|nearest_ancestor|missing")
    ap.add_argument("--head-sha", required=False, help="Head SHA display override")
    ap.add_argument("--history-dir", required=False, help="Directory containing prior PR perf JSON files")
    ap.add_argument("--history-max", required=False, type=int, default=10, help="Max points per trend series")
    args = ap.parse_args()

    head = load_json(Path(args.head))
    codepath_head = load_json(Path(args.codepath_head)) if args.codepath_head else None
    base = load_json(Path(args.base)) if args.base else None

    head_sha = args.head_sha or head.get("commitSHA")
    requested_base_sha = args.requested_base_sha or args.base_sha
    resolved_base_sha = args.base_sha or (base.get("commitSHA") if base else None)
    base_mode = str(args.base_mode or "missing")

    snapshots: dict[str, LaneSnapshot] = {}
    head_snapshot = build_snapshot(head)
    if head_snapshot:
        snapshots[head_snapshot.lane] = head_snapshot

    if codepath_head:
        cp_snapshot = build_snapshot(codepath_head)
        if cp_snapshot:
            snapshots[cp_snapshot.lane] = cp_snapshot

    if not snapshots:
        raise SystemExit("no valid lane snapshots found")

    base_snapshot = build_snapshot(base) if base else None

    history_runs = load_history_runs(Path(args.history_dir)) if args.history_dir else []
    current_runs: list[dict[str, Any]] = [head]
    if codepath_head:
        current_runs.append(codepath_head)
    trend_runs = dedupe_and_sort_runs(history_runs + current_runs)
    history_snapshots = [snapshot for run in trend_runs if (snapshot := build_snapshot(run)) is not None]
    history_max = max(2, args.history_max)

    lines: list[str] = []
    lines.append("<!-- vox-perf-audit -->")
    lines.append("## Performance Report")
    lines.append("")
    lines.append("> Lower latency is better for every metric in this report.")
    lines.append("> Generation = encode + STT + rewrite (paste is excluded from decisions in CI).")
    lines.append("> Regression status rule: `regressed` means slower by both >200ms and >10% vs previous run.")
    lines.append("")
    lines.append(f"- Head: `{short_sha(head_sha)}`")
    if base:
        base_detail = f"`{short_sha(resolved_base_sha)}`"
        if base_mode == "nearest_ancestor" and requested_base_sha and resolved_base_sha:
            base_detail += f" (nearest ancestor of requested `{short_sha(requested_base_sha)}`)"
        lines.append(f"- Base: {base_detail}")
    elif requested_base_sha:
        lines.append(f"- Base: `{short_sha(requested_base_sha)}` (not available in baseline store)")
    lines.append("")

    provider_snapshot = snapshots.get("provider")
    codepath_snapshot = snapshots.get("codepath")

    if provider_snapshot:
        render_lane_section(
            lines,
            "Provider Perf (Live Network)",
            provider_snapshot,
            history_snapshots,
            history_max,
            base_snapshot=base_snapshot,
        )
    else:
        lines.append("### Provider Perf (Live Network)")
        lines.append("")
        lines.append("Provider lane unavailable in this run (likely missing CI secrets).")
        lines.append("")

    if codepath_snapshot:
        render_lane_section(
            lines,
            "Codepath Perf (Deterministic)",
            codepath_snapshot,
            history_snapshots,
            history_max,
            base_snapshot=None,
        )
    else:
        lines.append("### Codepath Perf (Deterministic)")
        lines.append("")
        lines.append("Codepath lane unavailable in this run.")
        lines.append("")

    lines.append("<details>")
    lines.append("<summary>Head JSON (primary lane)</summary>")
    lines.append("")
    lines.append("```json")
    lines.append(json.dumps(head, indent=2, sort_keys=True))
    lines.append("```")
    lines.append("</details>")
    lines.append("")

    if codepath_head:
        lines.append("<details>")
        lines.append("<summary>Head JSON (codepath lane)</summary>")
        lines.append("")
        lines.append("```json")
        lines.append(json.dumps(codepath_head, indent=2, sort_keys=True))
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
