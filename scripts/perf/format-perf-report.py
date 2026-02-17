#!/usr/bin/env python3
"""
Format a VoxPerfAudit JSON run (optionally diffed vs a baseline) into a PR-comment markdown report.

No deps. Avoids transcript content by design (inputs are timing-only JSON).
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
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


def fmt_delta_ms(x: float) -> str:
    ms = int(round(x))
    if ms == 0:
        return "0ms"
    sign = "+" if ms > 0 else ""
    return f"{sign}{ms}ms"


def short_sha(sha: Optional[str]) -> str:
    if not sha:
        return "—"
    return sha[:8]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--head", required=True, help="Head perf JSON path")
    ap.add_argument("--base", required=False, help="Base perf JSON path (optional)")
    ap.add_argument("--out", required=False, help="Output markdown path (optional; else stdout)")
    ap.add_argument("--base-sha", required=False, help="Base SHA display override")
    ap.add_argument("--head-sha", required=False, help="Head SHA display override")
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

    lines: list[str] = []
    lines.append("<!-- vox-perf-audit -->")
    lines.append("## Performance Report")
    lines.append("")
    lines.append(f"- Head: `{short_sha(head_sha)}`")
    if base:
        lines.append(f"- Base: `{short_sha(base_sha)}`")
    if stt_chain:
        forced = f", forced={stt_forced}" if stt_forced else ""
        lines.append(f"- STT: mode={stt_mode}, policy={stt_policy}{forced}, chain={fmt_chain(stt_chain)}")
    else:
        # Back-compat for schema v1.
        lines.append(f"- STT: {head.get('sttProvider', '—')}")
    lines.append(f"- Rewrite routing: {rewrite_routing}")
    lines.append(f"- Fixture: `{audio_file}` ({audio_bytes} bytes), iterations={iters} per level")
    lines.append("- Note: paste stage is a no-op in CI; focus on generation timings.")
    lines.append("")

    levels = ["raw", "clean", "polish"]
    lines.append("| Level | STT observed | Rewrite observed |")
    lines.append("| --- | --- | --- |")
    for lvl in levels:
        h = get_level(head, lvl)
        providers = h.get("providers") or {}
        stt_obs = providers.get("sttObserved") or []
        rw_obs = providers.get("rewriteObserved") or []

        if not providers:
            # schema v1 back-compat
            stt_text = head.get("sttProvider", "—")
            rw_text = "—" if lvl == "raw" else head.get("rewriteProvider", "—")
        else:
            stt_text = fmt_usage(stt_obs)
            rw_text = "—" if lvl == "raw" else fmt_usage(rw_obs)

        lines.append(f"| {lvl} | {stt_text} | {rw_text} |")
    lines.append("")

    lines.append("| Level | Generation p50 | Generation p95 | STT p95 | Rewrite p95 | Encode p95 |")
    lines.append("| --- | ---: | ---: | ---: | ---: | ---: |")
    for lvl in levels:
        h = get_level(head, lvl)
        gen = dist(h, "generationMs")
        stt = dist(h, "sttMs")
        rw = dist(h, "rewriteMs")
        enc = dist(h, "encodeMs")
        lines.append(
            f"| {lvl} | {fmt_ms(gen.p50)} | {fmt_ms(gen.p95)} | {fmt_ms(stt.p95)} | {fmt_ms(rw.p95)} | {fmt_ms(enc.p95)} |"
        )
    lines.append("")

    if base:
        lines.append("### Delta Vs Base (Generation)")
        lines.append("")
        lines.append("| Level | Δ p50 | Δ p95 |")
        lines.append("| --- | ---: | ---: |")
        for lvl in levels:
            b = get_level(base, lvl)
            h = get_level(head, lvl)
            bgen = dist(b, "generationMs")
            hgen = dist(h, "generationMs")
            lines.append(f"| {lvl} | {fmt_delta_ms(hgen.p50 - bgen.p50)} | {fmt_delta_ms(hgen.p95 - bgen.p95)} |")
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
