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
import os
import re
import sys
import urllib.error
import urllib.request
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
    paste: Dist


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
    return " → ".join(fmt_ms(value) for value in values)


def fmt_chain(chain: list[dict[str, Any]]) -> str:
    parts: list[str] = []
    for entry in chain:
        provider = str(entry.get("provider") or "—")
        model = str(entry.get("model") or "")
        parts.append(f"{provider}({model})" if model else provider)
    return " → ".join(parts) if parts else "—"


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


def load_changed_files(path: Optional[str]) -> list[str]:
    if not path:
        return []
    try:
        lines = Path(path).read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        print(f"[perf-report] failed to read changed files ({path}): {exc}", file=sys.stderr)
        return []
    return [line.strip() for line in lines if line.strip()]


def stage_related_files(changed_files: list[str], stage: str, limit: int = 4) -> list[str]:
    stage_patterns: dict[str, tuple[str, ...]] = {
        "stt": (
            r"sources/voxproviders/.*(stt|deepgram|elevenlabs|speechtranscriber|applespeech|providerassembly)",
            r"sources/voxcore/.*(stt|fallbackstt|retryingstt|timeoutstt|hedgedstt|healthawarestt|concurrencylimitedstt)",
            r"sources/voxappkit/dictationpipeline\.swift",
        ),
        "rewrite": (
            r"sources/voxproviders/.*(rewrite|openrouter|gemini|foundationmodels|modelrouted)",
            r"sources/voxcore/.*(rewrite|modelroutedrewrite)",
            r"sources/voxappkit/dictationpipeline\.swift",
        ),
        "encode": (
            r"sources/voxproviders/.*(audioconverter|opus|encode)",
            r"sources/voxmac/.*(audioencoder|audiorecorder|capturedaudioinspector)",
            r"sources/voxappkit/dictationpipeline\.swift",
        ),
        "paste": (
            r"sources/voxmac/.*(clipboardpaster|hud)",
            r"sources/voxappkit/.*(dictationpipeline|voxsession)",
        ),
    }
    patterns = stage_patterns.get(stage, ())
    if not patterns:
        return []

    hits: list[str] = []
    for path in changed_files:
        lower = path.lower()
        if any(re.search(pattern, lower) for pattern in patterns):
            hits.append(path)
        if len(hits) >= limit:
            break
    return hits


def variability(dist: Dist) -> float:
    return max(0.0, dist.p95 - dist.p50)


def dominant_stage(generation: Dist, stt: Dist, rewrite: Dist, encode: Dist, paste: Dist) -> str:
    candidates = [("STT", stt.p95), ("Rewrite", rewrite.p95), ("Encode", encode.p95), ("Paste", paste.p95)]
    name, value = max(candidates, key=lambda item: item[1])
    share = (value / generation.p95 * 100) if generation.p95 > 0 else 0.0
    return f"{name} ({fmt_ms(value)}, {share:.0f}%)"


def change_status(latest: float, previous: float, noise: float = 0.0) -> str:
    if previous <= 0:
        return "neutral"
    delta = latest - previous
    pct = abs(delta) / previous
    # Suppress verdict when delta is within the within-run measurement spread.
    # A between-run change smaller than within-run noise is indistinguishable from variance.
    if noise > 0 and abs(delta) <= noise:
        return "neutral"
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


def median(values: list[float]) -> Optional[float]:
    if not values:
        return None
    ordered = sorted(values)
    mid = len(ordered) // 2
    if len(ordered) % 2 == 1:
        return ordered[mid]
    return (ordered[mid - 1] + ordered[mid]) / 2


def pct_delta(current: float, reference: float) -> Optional[float]:
    if reference <= 0:
        return None
    return (current - reference) / reference * 100


def fmt_signed_ms(delta: float) -> str:
    rounded = int(round(delta))
    if rounded == 0:
        return "0ms"
    sign = "+" if rounded > 0 else "-"
    return f"{sign}{abs(rounded)}ms"


def snapshot_identity(snapshot: LaneSnapshot) -> tuple[str, str, str]:
    return (
        str(snapshot.run.get("commitSHA") or ""),
        str(snapshot.run.get("generatedAt") or ""),
        snapshot.lane,
    )


def trend_series_filtered(
    snapshots: list[LaneSnapshot],
    lane: str,
    level: str,
    metric: str,
    max_points: int,
    source: Optional[str] = None,
    exclude_snapshot: Optional[LaneSnapshot] = None,
) -> list[float]:
    values: list[float] = []
    exclude_identity = snapshot_identity(exclude_snapshot) if exclude_snapshot else None

    for snapshot in snapshots:
        if snapshot.lane != lane:
            continue
        if source == "master" and run_source_label(snapshot) != "master":
            continue
        if source == "pr" and run_source_label(snapshot) == "master":
            continue
        if exclude_identity and snapshot_identity(snapshot) == exclude_identity:
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
        elif metric == "paste":
            values.append(row.paste.p95)

    return values[-max_points:]


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
        paste=dist_from_level(level_entry, "pasteMs"),
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
                paste=weighted_dist([row.paste for row in level_rows], weights),
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
    return trend_series_filtered(
        snapshots,
        lane=lane,
        level=level,
        metric=metric,
        max_points=max_points,
    )


def metric_value(row: LevelStats, metric: str) -> float:
    if metric == "generation":
        return row.generation.p95
    if metric == "stt":
        return row.stt.p95
    if metric == "rewrite":
        return row.rewrite.p95
    if metric == "encode":
        return row.encode.p95
    if metric == "paste":
        return row.paste.p95
    return 0.0


def lane_snapshots(history_snapshots: list[LaneSnapshot], lane: str) -> list[LaneSnapshot]:
    return [snapshot for snapshot in history_snapshots if snapshot.lane == lane]


def run_source_label(snapshot: LaneSnapshot) -> str:
    pr_number = snapshot.run.get("pullRequestNumber")
    if isinstance(pr_number, int) and pr_number > 0:
        return f"PR #{pr_number}"
    return "master"


def run_timestamp_label(snapshot: LaneSnapshot) -> str:
    parsed = parse_generated_at(snapshot.run.get("generatedAt"))
    if parsed is None:
        return "—"
    return parsed.strftime("%Y-%m-%d %H:%M")


def render_mermaid_trend_chart(lines: list[str], lane_history: list[LaneSnapshot], lane: str, max_points: int = 30) -> None:
    if len(lane_history) < 2:
        return

    series_runs = lane_history[-max_points:]

    def level_series(level: str) -> list[int]:
        values: list[int] = []
        for snapshot in series_runs:
            row = snapshot.levels.get(level)
            values.append(int(round(row.generation.p95)) if row else 0)
        return values

    raw_values = level_series("raw")
    clean_values = level_series("clean")
    polish_values = level_series("polish")
    all_values = raw_values + clean_values + polish_values
    y_max = max(all_values) if all_values else 0
    y_upper = max(1000, ((y_max + 499) // 500) * 500)
    x_axis = ", ".join(str(index + 1) for index in range(len(series_runs)))
    lane_title = "Provider" if lane == "provider" else "Codepath"

    lines.append("**Longitudinal chart (generation p95 by run order)**")
    lines.append("")
    lines.append("```mermaid")
    lines.append("xychart-beta")
    lines.append(f'    title "{lane_title} generation p95 trend (ms)"')
    lines.append(f"    x-axis \"Run\" [{x_axis}]")
    lines.append(f"    y-axis \"ms\" 0 --> {y_upper}")
    lines.append(f"    line \"raw\" [{', '.join(str(value) for value in raw_values)}]")
    lines.append(f"    line \"clean\" [{', '.join(str(value) for value in clean_values)}]")
    lines.append(f"    line \"polish\" [{', '.join(str(value) for value in polish_values)}]")
    lines.append("```")
    lines.append("")


def render_stage_metric_chart(
    lines: list[str],
    lane_history: list[LaneSnapshot],
    lane: str,
    metric: str,
    title: str,
    max_points: int = 30,
) -> None:
    if len(lane_history) < 2:
        return

    series_runs = lane_history[-max_points:]
    level_names = ["raw", "clean", "polish"]
    level_series: dict[str, list[int]] = {}
    has_signal = False
    for level in level_names:
        points: list[int] = []
        for snapshot in series_runs:
            row = snapshot.levels.get(level)
            value = int(round(metric_value(row, metric))) if row else 0
            points.append(value)
            if value > 0:
                has_signal = True
        level_series[level] = points

    if not has_signal:
        return

    all_values = [value for points in level_series.values() for value in points]
    y_max = max(all_values) if all_values else 0
    y_upper = max(200, ((y_max + 99) // 100) * 100)
    x_axis = ", ".join(str(index + 1) for index in range(len(series_runs)))
    lane_title = "Provider" if lane == "provider" else "Codepath"

    lines.append(f"**{title} (p95 by run order)**")
    lines.append("")
    lines.append("```mermaid")
    lines.append("xychart-beta")
    lines.append(f'    title "{lane_title} {title} p95 trend (ms)"')
    lines.append(f"    x-axis \"Run\" [{x_axis}]")
    lines.append(f"    y-axis \"ms\" 0 --> {y_upper}")
    for level in level_names:
        points = level_series[level]
        lines.append(f"    line \"{level}\" [{', '.join(str(value) for value in points)}]")
    lines.append("```")
    lines.append("")


def render_run_timeline(lines: list[str], lane_history: list[LaneSnapshot], max_rows: int = 60) -> None:
    if not lane_history:
        lines.append("**Run timeline**")
        lines.append("")
        lines.append("No historical runs available for this lane.")
        lines.append("")
        return

    start_label = run_timestamp_label(lane_history[0])
    end_label = run_timestamp_label(lane_history[-1])
    series_runs = lane_history[-max(1, max_rows):]
    start_index = len(lane_history) - len(series_runs) + 1
    lines.append("**Run timeline (oldest → newest)**")
    lines.append("")
    if len(series_runs) < len(lane_history):
        lines.append(
            f"{len(lane_history)} runs from {start_label} to {end_label} "
            f"(showing latest {len(series_runs)})."
        )
    else:
        lines.append(f"{len(lane_history)} runs from {start_label} to {end_label}.")
    lines.append("")
    lines.append("| idx | generatedAt (UTC) | source | commit | raw p95 | clean p95 | polish p95 | clean Δ vs prev |")
    lines.append("| ---: | --- | --- | --- | ---: | ---: | ---: | --- |")

    previous_clean: Optional[float] = None
    for index, snapshot in enumerate(series_runs, start=start_index):
        raw = snapshot.levels.get("raw")
        clean = snapshot.levels.get("clean")
        polish = snapshot.levels.get("polish")
        clean_value = clean.generation.p95 if clean else 0.0
        clean_delta = (
            fmt_change(clean_value, previous_clean) if previous_clean is not None and clean else "—"
        )
        previous_clean = clean_value if clean else previous_clean
        lines.append(
            f"| {index} | {run_timestamp_label(snapshot)} | {run_source_label(snapshot)} | "
            f"`{short_sha(snapshot.run.get('commitSHA'))}` | "
            f"{fmt_ms(raw.generation.p95) if raw else '—'} | "
            f"{fmt_ms(clean.generation.p95) if clean else '—'} | "
            f"{fmt_ms(polish.generation.p95) if polish else '—'} | "
            f"{clean_delta} |"
        )
    lines.append("")


def render_summary_section(
    lines: list[str],
    snapshot: LaneSnapshot,
    history_snapshots: list[LaneSnapshot],
    base_snapshot: Optional[LaneSnapshot],
    history_max: int,
    head_sha: Optional[str],
    base_sha: Optional[str],
    base_mode: str,
) -> None:
    """Compact always-visible summary: one table row per level, regressions flagged."""
    regressions: list[str] = []
    table_rows: list[str] = []

    for level in LEVELS:
        row = snapshot.levels.get(level)
        if row is None:
            table_rows.append(f"| {level} | — | — | — | — |")
            continue

        p95_str = fmt_ms(row.generation.p95)
        confidence = confidence_label(row.iterations, variability(row.generation), row.generation.p95)

        # vs base (master snapshot), noise-gated by within-run spread.
        base_row = (
            base_snapshot.levels.get(level)
            if base_snapshot and base_snapshot.lane == snapshot.lane
            else None
        )
        if base_row:
            base_noise = max(variability(row.generation), variability(base_row.generation))
            base_status = change_status(row.generation.p95, base_row.generation.p95, noise=base_noise)
            vs_base = fmt_change(row.generation.p95, base_row.generation.p95)
            if base_status == "neutral":
                vs_base = "neutral"
            elif base_status == "regressed":
                vs_base = f"**{vs_base}** ⚠️"
                regressions.append(f"{level} (vs base)")
        else:
            vs_base = "—"

        # vs deployed/reference median (noise-gated)
        reference_source = "master" if snapshot.lane == "provider" else None
        series = trend_series_filtered(
            history_snapshots,
            lane=snapshot.lane,
            level=level,
            metric="generation",
            max_points=history_max,
            source=reference_source,
            exclude_snapshot=snapshot,
        )
        reference_median = median(series)
        if reference_median is not None:
            spread = variability(row.generation)
            trend_status = change_status(row.generation.p95, reference_median, noise=spread)
            if trend_status == "neutral":
                vs_trend = "neutral"
            elif trend_status == "regressed":
                vs_trend = f"**{fmt_change(row.generation.p95, reference_median)}** ⚠️"
                regressions.append(f"{level} (deployed median)")
            else:
                vs_trend = fmt_change(row.generation.p95, reference_median)
        else:
            vs_trend = f"{len(series)} pt"

        table_rows.append(f"| {level} | {p95_str} | {vs_base} | {vs_trend} | {confidence} |")

    verdict = "no regressions" if not regressions else f"regression: {', '.join(regressions)}"
    lines.append(f"## ⚡ Perf — {verdict}")
    lines.append("")
    lines.append("| level | p95 | vs base | vs deployed median | confidence |")
    lines.append("| --- | ---: | --- | --- | --- |")
    lines.extend(table_rows)
    lines.append("")
    lines.append("> **vs base** = compared to persisted master baseline at PR base SHA (or nearest persisted ancestor).")
    lines.append("> **vs deployed median** = provider lane uses recent master-only median; codepath lane uses recent lane median. Both are noise-gated.")
    lines.append("")

    # One-line context footer
    base_ref = short_sha(base_sha) if base_sha else "—"
    base_note = "" if base_mode == "exact" else f" ({base_mode})" if base_mode != "missing" else " (no baseline)"
    lines.append(
        f"> `{snapshot.lane}` · {len(snapshot.fixtures)} fixture(s) · "
        f"{snapshot.iterations_per_fixture}+{snapshot.warmup_per_fixture} iter · "
        f"head `{short_sha(head_sha)}` · base `{base_ref}`{base_note}"
    )
    lane_history = lane_snapshots(history_snapshots, snapshot.lane)
    if lane_history:
        first_label = run_timestamp_label(lane_history[0])
        last_label = run_timestamp_label(lane_history[-1])
        lines.append(
            f"> trend coverage: {len(lane_history)} run(s) from {first_label} to {last_label}"
        )
    lines.append("")


def summarize_stage_delta(current: LevelStats, reference: LevelStats) -> tuple[str, float, float]:
    deltas = {
        "stt": current.stt.p95 - reference.stt.p95,
        "rewrite": current.rewrite.p95 - reference.rewrite.p95,
        "encode": current.encode.p95 - reference.encode.p95,
        "paste": current.paste.p95 - reference.paste.p95,
    }
    stage, delta = max(deltas.items(), key=lambda item: abs(item[1]))
    net = current.generation.p95 - reference.generation.p95
    share = (abs(delta) / abs(net) * 100) if abs(net) > 0 else 0.0
    return stage, delta, share


def collect_critical_metrics(
    provider_snapshot: Optional[LaneSnapshot],
    codepath_snapshot: Optional[LaneSnapshot],
    base_snapshot: Optional[LaneSnapshot],
    history_snapshots: list[LaneSnapshot],
    history_max: int,
) -> dict[str, Any]:
    level_metrics: dict[str, Any] = {}
    provider_statuses: list[str] = []

    for level in ["clean", "polish", "raw"]:
        provider_row = provider_snapshot.levels.get(level) if provider_snapshot else None
        codepath_row = codepath_snapshot.levels.get(level) if codepath_snapshot else None
        base_row = (
            base_snapshot.levels.get(level)
            if provider_snapshot and base_snapshot and base_snapshot.lane == "provider"
            else None
        )

        level_entry: dict[str, Any] = {
            "provider": None,
            "codepath": None,
            "external_estimate_ms": None,
        }

        if provider_row:
            provider_entry: dict[str, Any] = {
                "p95_ms": int(round(provider_row.generation.p95)),
                "confidence": confidence_label(
                    provider_row.iterations,
                    variability(provider_row.generation),
                    provider_row.generation.p95,
                ),
            }

            if base_row:
                base_noise = max(variability(provider_row.generation), variability(base_row.generation))
                status = change_status(provider_row.generation.p95, base_row.generation.p95, noise=base_noise)
                if level in {"clean", "polish"}:
                    provider_statuses.append(status)
                provider_entry["vs_base"] = {
                    "status": status,
                    "delta_ms": int(round(provider_row.generation.p95 - base_row.generation.p95)),
                    "delta_pct": pct_delta(provider_row.generation.p95, base_row.generation.p95),
                }

                stage, delta, share = summarize_stage_delta(provider_row, base_row)
                provider_entry["dominant_stage_vs_base"] = {
                    "stage": stage,
                    "delta_ms": int(round(delta)),
                    "share_pct": round(share, 1),
                }

            deployed_series = trend_series_filtered(
                history_snapshots,
                lane="provider",
                level=level,
                metric="generation",
                max_points=history_max,
                source="master",
                exclude_snapshot=provider_snapshot,
            )
            deployed_median = median(deployed_series)
            if deployed_median is not None:
                deployed_noise = variability(provider_row.generation)
                provider_entry["vs_deployed_median"] = {
                    "status": change_status(provider_row.generation.p95, deployed_median, noise=deployed_noise),
                    "delta_ms": int(round(provider_row.generation.p95 - deployed_median)),
                    "delta_pct": pct_delta(provider_row.generation.p95, deployed_median),
                    "sample_runs": len(deployed_series),
                }

            level_entry["provider"] = provider_entry

        if codepath_row:
            codepath_entry: dict[str, Any] = {
                "p95_ms": int(round(codepath_row.generation.p95)),
                "confidence": confidence_label(
                    codepath_row.iterations,
                    variability(codepath_row.generation),
                    codepath_row.generation.p95,
                ),
            }
            codepath_series = trend_series_filtered(
                history_snapshots,
                lane="codepath",
                level=level,
                metric="generation",
                max_points=history_max,
                exclude_snapshot=codepath_snapshot,
            )
            codepath_median = median(codepath_series)
            if codepath_median is not None:
                codepath_noise = variability(codepath_row.generation)
                codepath_entry["vs_recent_median"] = {
                    "status": change_status(codepath_row.generation.p95, codepath_median, noise=codepath_noise),
                    "delta_ms": int(round(codepath_row.generation.p95 - codepath_median)),
                    "delta_pct": pct_delta(codepath_row.generation.p95, codepath_median),
                    "sample_runs": len(codepath_series),
                }
            level_entry["codepath"] = codepath_entry

        if provider_row and codepath_row:
            level_entry["external_estimate_ms"] = int(round(provider_row.generation.p95 - codepath_row.generation.p95))

        level_metrics[level] = level_entry

    deployed_provider_runs = [
        snapshot
        for snapshot in history_snapshots
        if snapshot.lane == "provider" and run_source_label(snapshot) == "master"
    ]
    codepath_runs = [snapshot for snapshot in history_snapshots if snapshot.lane == "codepath"]

    if any(status == "regressed" for status in provider_statuses):
        verdict = "regressed"
    elif any(status == "improved" for status in provider_statuses):
        verdict = "improved"
    else:
        verdict = "neutral"

    return {
        "verdict": verdict,
        "levels": level_metrics,
        "coverage": {
            "provider_master_runs": len(deployed_provider_runs),
            "codepath_runs": len(codepath_runs),
        },
    }


def render_executive_tldr(
    lines: list[str],
    critical_metrics: dict[str, Any],
    llm_tldr: Optional[str],
    head_sha: Optional[str],
    base_sha: Optional[str],
    base_mode: str,
) -> None:
    verdict = critical_metrics.get("verdict", "neutral")
    verdict_icon = "✅" if verdict == "improved" else "⚠️" if verdict == "regressed" else "➖"

    lines.append(f"## {verdict_icon} Perf TL;DR")
    lines.append("")

    if llm_tldr:
        lines.append(llm_tldr)
    else:
        clean_provider = (critical_metrics.get("levels", {}).get("clean", {}) or {}).get("provider") or {}
        polish_provider = (critical_metrics.get("levels", {}).get("polish", {}) or {}).get("provider") or {}
        clean_codepath = (critical_metrics.get("levels", {}).get("clean", {}) or {}).get("codepath") or {}
        polish_codepath = (critical_metrics.get("levels", {}).get("polish", {}) or {}).get("codepath") or {}

        if clean_provider or polish_provider:
            clean_p95 = clean_provider.get("p95_ms")
            polish_p95 = polish_provider.get("p95_ms")
            lines.append(
                f"- Provider lane user-visible p95: clean={clean_p95 if clean_p95 is not None else '—'}ms, "
                f"polish={polish_p95 if polish_p95 is not None else '—'}ms."
            )
        else:
            lines.append("- Provider lane unavailable in this run; user-visible external-service impact cannot be evaluated.")

        if clean_codepath or polish_codepath:
            clean_cp = clean_codepath.get("p95_ms")
            polish_cp = polish_codepath.get("p95_ms")
            lines.append(
                f"- Codepath lane p95 (internal-only): clean={clean_cp if clean_cp is not None else '—'}ms, "
                f"polish={polish_cp if polish_cp is not None else '—'}ms."
            )
        else:
            lines.append("- Codepath lane unavailable; internal/framework-only movement cannot be isolated.")

        coverage = critical_metrics.get("coverage", {})
        lines.append(
            f"- Confidence context: provider master history={coverage.get('provider_master_runs', 0)} run(s), "
            f"codepath history={coverage.get('codepath_runs', 0)} run(s)."
        )
    lines.append("")

    lines.append("| level | provider p95 | vs base (master) | codepath p95 | ext est (provider-codepath) | dominant stage vs base |")
    lines.append("| --- | ---: | --- | ---: | ---: | --- |")

    for level in ["clean", "polish"]:
        level_entry = critical_metrics.get("levels", {}).get(level, {})
        provider = level_entry.get("provider") or {}
        codepath = level_entry.get("codepath") or {}

        provider_p95 = provider.get("p95_ms")
        provider_text = f"{provider_p95}ms" if isinstance(provider_p95, int) else "—"

        vs_base_entry = provider.get("vs_base") or {}
        vs_base_status = vs_base_entry.get("status")
        if vs_base_status in {"improved", "regressed"}:
            vs_base_text = fmt_change(provider_p95, provider_p95 - vs_base_entry.get("delta_ms", 0)) if isinstance(provider_p95, int) else "—"
            if vs_base_status == "regressed":
                vs_base_text = f"{vs_base_text} ⚠️"
        elif vs_base_status == "neutral":
            vs_base_text = "neutral"
        else:
            vs_base_text = "—"

        codepath_p95 = codepath.get("p95_ms")
        codepath_text = f"{codepath_p95}ms" if isinstance(codepath_p95, int) else "—"

        external_est = level_entry.get("external_estimate_ms")
        external_text = fmt_signed_ms(float(external_est)) if isinstance(external_est, int) else "—"

        dominant_entry = provider.get("dominant_stage_vs_base") or {}
        dominant_stage = dominant_entry.get("stage")
        dominant_delta = dominant_entry.get("delta_ms")
        dominant_share = dominant_entry.get("share_pct")
        if isinstance(dominant_stage, str) and isinstance(dominant_delta, int):
            dominant_text = f"{dominant_stage} {fmt_signed_ms(float(dominant_delta))}"
            if isinstance(dominant_share, (int, float)):
                dominant_text += f" ({dominant_share:.0f}%)"
        else:
            dominant_text = "—"

        lines.append(
            f"| {level} | {provider_text} | {vs_base_text} | {codepath_text} | {external_text} | {dominant_text} |"
        )

    lines.append("")
    base_ref = short_sha(base_sha) if base_sha else "—"
    base_note = "" if base_mode == "exact" else f" ({base_mode})" if base_mode != "missing" else " (no baseline)"
    coverage = critical_metrics.get("coverage", {})
    lines.append(
        f"> head `{short_sha(head_sha)}` · base `{base_ref}`{base_note} · "
        f"deployed provider runs={coverage.get('provider_master_runs', 0)} · "
        f"codepath runs={coverage.get('codepath_runs', 0)}"
    )
    lines.append("")


def render_actionable_signals(
    lines: list[str],
    primary_snapshot: LaneSnapshot,
    history_snapshots: list[LaneSnapshot],
    history_max: int,
    base_snapshot: Optional[LaneSnapshot],
    codepath_snapshot: Optional[LaneSnapshot],
    changed_files: list[str],
) -> None:
    lines.append("## Actionable Signals")
    lines.append("")
    findings: list[str] = []

    for level in LEVELS:
        row = primary_snapshot.levels.get(level)
        if row is None:
            continue

        base_row = (
            base_snapshot.levels.get(level)
            if base_snapshot and base_snapshot.lane == primary_snapshot.lane
            else None
        )
        if base_row is None:
            continue

        status = change_status(
            row.generation.p95,
            base_row.generation.p95,
            noise=max(variability(row.generation), variability(base_row.generation)),
        )
        if status != "regressed":
            continue

        total_delta = row.generation.p95 - base_row.generation.p95
        stage_deltas = {
            "stt": row.stt.p95 - base_row.stt.p95,
            "rewrite": row.rewrite.p95 - base_row.rewrite.p95,
            "encode": row.encode.p95 - base_row.encode.p95,
            "paste": row.paste.p95 - base_row.paste.p95,
        }
        dominant_stage = max(stage_deltas, key=lambda stage: stage_deltas[stage])
        dominant_delta = stage_deltas[dominant_stage]
        contribution = (dominant_delta / total_delta * 100) if total_delta > 0 else 0.0

        cross_lane_hint = ""
        if primary_snapshot.lane == "provider" and codepath_snapshot:
            codepath_row = codepath_snapshot.levels.get(level)
            if codepath_row is not None:
                codepath_series = trend_series(
                    history_snapshots,
                    "codepath",
                    level,
                    "generation",
                    max_points=max(2, history_max),
                )
                if len(codepath_series) >= 2:
                    codepath_trend = change_status(
                        codepath_series[-1],
                        codepath_series[-2],
                        noise=variability(codepath_row.generation),
                    )
                    if codepath_trend == "neutral":
                        cross_lane_hint = "codepath stable while provider regressed; likely external/provider variance."
                    elif codepath_trend == "regressed":
                        cross_lane_hint = "both provider and codepath moved; likely code-path change."

        related_files = stage_related_files(changed_files, dominant_stage)
        files_hint = ", ".join(f"`{path}`" for path in related_files) if related_files else "no stage-specific file match"
        findings.append(
            f"- `{level}` regressed by {fmt_change(row.generation.p95, base_row.generation.p95)}; "
            f"largest stage delta is `{dominant_stage}` ({fmt_ms(dominant_delta)}, {contribution:.0f}% of net delta). "
            f"Changed files: {files_hint}. {cross_lane_hint}".strip()
        )

    if not findings:
        lines.append("- No level crossed regression thresholds versus base in this run.")
    else:
        lines.extend(findings)
    lines.append("")


def maybe_generate_llm_synthesis(payload: dict[str, Any]) -> Optional[str]:
    api_key = os.getenv("OPENROUTER_API_KEY", "").strip()
    if not api_key:
        return None

    prompt = (
        "You are the lead-performance summarizer for a production app PR.\n"
        "Return exactly 3 markdown bullets, each starting with '- '.\n"
        "Bullets must be concise, quantitative, and evidence-based:\n"
        "1) user-visible impact (provider lane clean/polish),\n"
        "2) attribution (provider vs codepath + dominant stage),\n"
        "3) confidence/risk + one next validation step.\n"
        "Rules: use only provided data, include at least one numeric value per bullet, "
        "no speculation, no preamble, each bullet <= 28 words.\n\n"
        f"Data:\n{json.dumps(payload, separators=(',', ':'))}"
    )

    synthesis_models = [
        os.getenv("VOX_PERF_SYNTH_MODEL_PRIMARY", "google/gemini-3-flash-preview").strip(),
        os.getenv("VOX_PERF_SYNTH_MODEL_FALLBACK", "google/gemini-2.5-flash").strip(),
    ]

    for model in synthesis_models:
        if not model:
            continue
        request_body = {
            "model": model,
            "messages": [
                {
                    "role": "system",
                    "content": "Be strict, numeric, and avoid unsupported claims.",
                },
                {"role": "user", "content": prompt},
            ],
            "temperature": 0.0,
            "max_tokens": 260,
        }

        req = urllib.request.Request(
            "https://openrouter.ai/api/v1/chat/completions",
            data=json.dumps(request_body).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )

        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                raw = resp.read().decode("utf-8")
            decoded = json.loads(raw)
            content = decoded.get("choices", [{}])[0].get("message", {}).get("content")
            if isinstance(content, list):
                content = "\n".join(str(item.get("text", "")) for item in content if isinstance(item, dict))
            if not isinstance(content, str):
                continue

            lines = [line.strip() for line in content.strip().splitlines() if line.strip()]
            bullet_lines = [line for line in lines if line.startswith("-")]
            if len(bullet_lines) >= 3:
                return "\n".join(bullet_lines[:3])

            cleaned = content.strip()
            if cleaned:
                return cleaned[:1800]
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, KeyError, IndexError, UnicodeDecodeError):
            continue
    return None


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


def render_lane_detail(
    lines: list[str],
    snapshot: LaneSnapshot,
    history_snapshots: list[LaneSnapshot],
    history_max: int,
    timeline_max: int,
    render_mermaid_charts: bool,
    base_snapshot: Optional[LaneSnapshot] = None,
) -> None:
    """Detailed per-lane tables: stage breakdown, trend history, fixture breakdown, routing."""
    fixture_count = len(snapshot.fixtures)
    lines.append(
        f"Weighted aggregate across {fixture_count} fixture(s) by audio bytes; "
        f"{snapshot.iterations_per_fixture} measured + {snapshot.warmup_per_fixture} warmup iteration(s) per level+fixture."
    )
    lines.append("")

    lines.append("| Level | p50 | p95 | spread | STT p95 | Rewrite p95 | Encode p95 | Paste p95 | Dominant |")
    lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |")
    for level in LEVELS:
        row = snapshot.levels.get(level)
        if row is None:
            lines.append(f"| {level} | — | — | — | — | — | — | — | — |")
            continue
        lines.append(
            f"| {level} | {fmt_ms(row.generation.p50)} | {fmt_ms(row.generation.p95)} | "
            f"{fmt_ms(variability(row.generation))} | "
            f"{fmt_ms(row.stt.p95)} | "
            f"{fmt_ms(row.rewrite.p95)} | "
            f"{fmt_ms(row.encode.p95)} | "
            f"{fmt_ms(row.paste.p95)} | "
            f"{dominant_stage(row.generation, row.stt, row.rewrite, row.encode, row.paste)} |"
        )
    lines.append("")

    lines.append("**Trend (generation p95, oldest → newest)**")
    lines.append("")
    lines.append("| Level | Points | Runs | Vs mean | Vs best |")
    lines.append("| --- | --- | ---: | --- | --- |")
    for level in LEVELS:
        series = trend_series(history_snapshots, snapshot.lane, level, "generation", history_max)
        if not series:
            lines.append(f"| {level} | — | 0 | — | — |")
            continue
        latest = series[-1]
        mean = sum(series) / len(series)
        best = min(series)
        vs_best = "best" if int(round(latest - best)) == 0 else fmt_change(latest, best)
        lines.append(
            f"| {level} | {fmt_points(series)} | {len(series)} | "
            f"{fmt_change(latest, mean)} | {vs_best} |"
        )
    lines.append("")

    lane_history = lane_snapshots(history_snapshots, snapshot.lane)
    if render_mermaid_charts:
        render_mermaid_trend_chart(lines, lane_history, snapshot.lane)
        render_stage_metric_chart(lines, lane_history, snapshot.lane, "stt", "STT")
        render_stage_metric_chart(lines, lane_history, snapshot.lane, "rewrite", "Rewrite")
        render_stage_metric_chart(lines, lane_history, snapshot.lane, "encode", "Encode")
        render_stage_metric_chart(lines, lane_history, snapshot.lane, "paste", "Paste")
    else:
        lines.append("_Mermaid charts omitted in CI for readability and render reliability._")
        lines.append("")
    render_run_timeline(lines, lane_history, max_rows=max(6, timeline_max))

    render_fixture_table(lines, snapshot)

    if base_snapshot and base_snapshot.lane == snapshot.lane:
        lines.append("**Base branch comparison**")
        lines.append("")
        lines.append("| Level | p50 change | p95 change |")
        lines.append("| --- | --- | --- |")
        for level in LEVELS:
            current_row = snapshot.levels.get(level)
            base_row = base_snapshot.levels.get(level)
            if not current_row or not base_row:
                lines.append(f"| {level} | n/a | n/a |")
                continue
            lines.append(
                f"| {level} | {fmt_change(current_row.generation.p50, base_row.generation.p50)} | "
                f"{fmt_change(current_row.generation.p95, base_row.generation.p95)} |"
            )
        lines.append("")

    lines.append("**Routing**")
    lines.append("")
    lines.append("| Field | Value |")
    lines.append("| --- | --- |")
    lines.append(f"| STT | mode={snapshot.stt_mode}, policy={snapshot.stt_policy}" + (f", forced={snapshot.stt_forced}" if snapshot.stt_forced else "") + f", chain={fmt_chain(snapshot.stt_chain)} |")
    lines.append(f"| Rewrite | {snapshot.rewrite_routing} |")
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
    ap.add_argument("--history-dir", required=False, help="Directory containing prior perf JSON files (PR + master history)")
    ap.add_argument("--history-max", required=False, type=int, default=24, help="Max points per trend series")
    ap.add_argument("--timeline-max", required=False, type=int, default=16, help="Max rows in run timeline table")
    ap.add_argument("--render-mermaid-charts", action="store_true", help="Render Mermaid charts in report details")
    ap.add_argument("--changed-files", required=False, help="Optional path to changed-files list from git diff")
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
    changed_files = load_changed_files(args.changed_files)
    current_runs: list[dict[str, Any]] = [head]
    if codepath_head:
        current_runs.append(codepath_head)
    trend_runs = dedupe_and_sort_runs(history_runs + current_runs)
    history_snapshots = [snapshot for run in trend_runs if (snapshot := build_snapshot(run)) is not None]
    history_max = max(2, args.history_max)
    timeline_max = max(6, args.timeline_max)
    render_mermaid_charts = bool(args.render_mermaid_charts)

    provider_snapshot = snapshots.get("provider")
    codepath_snapshot = snapshots.get("codepath")
    primary_snapshot = provider_snapshot or codepath_snapshot

    lines: list[str] = []
    lines.append("<!-- vox-perf-audit -->")

    # ── Summary (always visible) ─────────────────────────────────────────────
    if primary_snapshot:
        critical_metrics = collect_critical_metrics(
            provider_snapshot=provider_snapshot,
            codepath_snapshot=codepath_snapshot,
            base_snapshot=base_snapshot,
            history_snapshots=history_snapshots,
            history_max=history_max,
        )
        llm_payload = {
            "head": short_sha(head_sha),
            "base": short_sha(resolved_base_sha) if resolved_base_sha else None,
            "base_mode": base_mode,
            "critical_metrics": critical_metrics,
            "changed_files": changed_files[:20],
        }
        llm_tldr = maybe_generate_llm_synthesis(llm_payload)

        render_executive_tldr(
            lines,
            critical_metrics=critical_metrics,
            llm_tldr=llm_tldr,
            head_sha=head_sha,
            base_sha=resolved_base_sha,
            base_mode=base_mode,
        )

        lines.append("<details>")
        lines.append("<summary>Quantitative scorecard and synthesis inputs</summary>")
        lines.append("")

        render_summary_section(
            lines,
            primary_snapshot,
            history_snapshots,
            base_snapshot,
            history_max,
            head_sha=head_sha,
            base_sha=resolved_base_sha,
            base_mode=base_mode,
        )
        render_actionable_signals(
            lines,
            primary_snapshot=primary_snapshot,
            history_snapshots=history_snapshots,
            history_max=history_max,
            base_snapshot=base_snapshot,
            codepath_snapshot=codepath_snapshot,
            changed_files=changed_files,
        )

        lines.append("**LLM payload (critical metrics)**")
        lines.append("")
        lines.append("```json")
        lines.append(json.dumps(llm_payload, indent=2, sort_keys=True))
        lines.append("```")
        lines.append("")
        lines.append("</details>")
        lines.append("")

    # ── Provider details (collapsible) ───────────────────────────────────────
    if provider_snapshot:
        detail_lines: list[str] = []
        render_lane_detail(
            detail_lines,
            provider_snapshot,
            history_snapshots,
            history_max,
            timeline_max=timeline_max,
            render_mermaid_charts=render_mermaid_charts,
            base_snapshot=base_snapshot,
        )
        lines.append("<details>")
        lines.append("<summary>Provider Perf — stage breakdown, trend history, routing</summary>")
        lines.append("")
        lines.extend(detail_lines)
        lines.append("</details>")
        lines.append("")
    else:
        lines.append("<details>")
        lines.append("<summary>Provider Perf — unavailable</summary>")
        lines.append("")
        lines.append("Provider lane unavailable in this run (likely missing CI secrets).")
        lines.append("")
        lines.append("</details>")
        lines.append("")

    # ── Codepath details (collapsible) ───────────────────────────────────────
    if codepath_snapshot:
        cp_detail_lines: list[str] = []
        render_lane_detail(
            cp_detail_lines,
            codepath_snapshot,
            history_snapshots,
            history_max,
            timeline_max=timeline_max,
            render_mermaid_charts=render_mermaid_charts,
        )
        lines.append("<details>")
        lines.append("<summary>Codepath Perf (deterministic mock) — stage breakdown, trend history</summary>")
        lines.append("")
        lines.extend(cp_detail_lines)
        lines.append("</details>")
        lines.append("")

    out = "\n".join(lines)
    if args.out:
        Path(args.out).write_text(out, encoding="utf-8")
    else:
        print(out)


if __name__ == "__main__":
    main()
