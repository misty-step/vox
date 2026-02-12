#!/usr/bin/env python3
"""
STT Provider Eval — compare speech-to-text providers on real audio.

Usage:
    python3 scripts/stt-eval.py --record 30        # Record 30s then eval
    python3 scripts/stt-eval.py path/to/audio.wav   # Eval existing file
    python3 scripts/stt-eval.py --iterations 3       # Multiple runs

Set API keys via environment or .env.local:
    ELEVENLABS_API_KEY, DEEPGRAM_API_KEY, OPENAI_API_KEY, GROQ_API_KEY
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from difflib import SequenceMatcher
from pathlib import Path

import requests

REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = REPO_ROOT / "docs" / "performance"


# ---------------------------------------------------------------------------
# API key loading
# ---------------------------------------------------------------------------

def load_env(names):
    """Load API keys from environment, falling back to .env.local."""
    keys = {}
    env_path = REPO_ROOT / ".env.local"
    env_lines = {}
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                env_lines[k.strip()] = v.strip().strip('"').strip("'")
    for name in names:
        keys[name] = os.environ.get(name) or env_lines.get(name, "")
    return keys


# ---------------------------------------------------------------------------
# Recording
# ---------------------------------------------------------------------------

def record_audio(duration, output_path, device_index=1):
    """Record audio using ffmpeg avfoundation."""
    print(f"\n  Recording {duration}s from device {device_index}...")
    print(f"  Speak now! ", end="", flush=True)

    cmd = [
        "ffmpeg", "-y",
        "-f", "avfoundation",
        "-i", f":{device_index}",
        "-ar", "16000",
        "-ac", "1",
        "-sample_fmt", "s16",
        "-t", str(duration),
        output_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=duration + 10)
    if result.returncode != 0:
        print(f"FAILED")
        print(f"  ffmpeg stderr: {result.stderr[-500:]}")
        sys.exit(1)

    size = os.path.getsize(output_path)
    print(f"Done ({size / 1024:.0f} KB)")
    return output_path


def ensure_wav(input_path):
    """Convert input to 16kHz mono WAV if needed."""
    path = Path(input_path)
    if path.suffix.lower() == ".wav":
        return str(path)
    wav_path = path.with_suffix(".wav")
    print(f"  Converting {path.name} → {wav_path.name}...")
    subprocess.run([
        "ffmpeg", "-y", "-i", str(path),
        "-ar", "16000", "-ac", "1", "-sample_fmt", "s16",
        str(wav_path),
    ], capture_output=True, check=True)
    return str(wav_path)


# ---------------------------------------------------------------------------
# Provider implementations
# ---------------------------------------------------------------------------

def call_elevenlabs(api_key, wav_path):
    """ElevenLabs Scribe v2 (batch)."""
    start = time.monotonic()
    with open(wav_path, "rb") as f:
        resp = requests.post(
            "https://api.elevenlabs.io/v1/speech-to-text",
            headers={"xi-api-key": api_key},
            files={"file": ("audio.wav", f, "audio/wav")},
            data={"model_id": "scribe_v2"},
            timeout=120,
        )
    latency = time.monotonic() - start
    if resp.status_code != 200:
        return None, latency, f"HTTP {resp.status_code}: {resp.text[:200]}"
    return resp.json().get("text", ""), latency, None


def call_deepgram(api_key, wav_path):
    """Deepgram Nova-3 (batch)."""
    start = time.monotonic()
    with open(wav_path, "rb") as f:
        resp = requests.post(
            "https://api.deepgram.com/v1/listen",
            params={"model": "nova-3", "punctuate": "true", "smart_format": "true"},
            headers={
                "Authorization": f"Token {api_key}",
                "Content-Type": "audio/wav",
            },
            data=f.read(),
            timeout=120,
        )
    latency = time.monotonic() - start
    if resp.status_code != 200:
        return None, latency, f"HTTP {resp.status_code}: {resp.text[:200]}"
    data = resp.json()
    try:
        transcript = data["results"]["channels"][0]["alternatives"][0]["transcript"]
    except (KeyError, IndexError):
        return None, latency, f"Unexpected response: {json.dumps(data)[:200]}"
    return transcript, latency, None


def call_openai(api_key, wav_path, model):
    """OpenAI transcription (whisper-1, gpt-4o-mini-transcribe, etc.)."""
    start = time.monotonic()
    with open(wav_path, "rb") as f:
        resp = requests.post(
            "https://api.openai.com/v1/audio/transcriptions",
            headers={"Authorization": f"Bearer {api_key}"},
            files={"file": ("audio.wav", f, "audio/wav")},
            data={"model": model},
            timeout=120,
        )
    latency = time.monotonic() - start
    if resp.status_code != 200:
        return None, latency, f"HTTP {resp.status_code}: {resp.text[:200]}"
    return resp.json().get("text", ""), latency, None


def call_groq(api_key, wav_path, model):
    """Groq (OpenAI-compatible endpoint)."""
    start = time.monotonic()
    with open(wav_path, "rb") as f:
        resp = requests.post(
            "https://api.groq.com/openai/v1/audio/transcriptions",
            headers={"Authorization": f"Bearer {api_key}"},
            files={"file": ("audio.wav", f, "audio/wav")},
            data={"model": model},
            timeout=120,
        )
    latency = time.monotonic() - start
    if resp.status_code != 200:
        return None, latency, f"HTTP {resp.status_code}: {resp.text[:200]}"
    return resp.json().get("text", ""), latency, None


# ---------------------------------------------------------------------------
# Provider registry
# ---------------------------------------------------------------------------

PROVIDERS = [
    {
        "name": "ElevenLabs Scribe v2",
        "key_name": "ELEVENLABS_API_KEY",
        "call": lambda key, path: call_elevenlabs(key, path),
    },
    {
        "name": "Deepgram Nova-3",
        "key_name": "DEEPGRAM_API_KEY",
        "call": lambda key, path: call_deepgram(key, path),
    },
    {
        "name": "OpenAI gpt-4o-mini-transcribe",
        "key_name": "OPENAI_API_KEY",
        "call": lambda key, path: call_openai(key, path, "gpt-4o-mini-transcribe"),
    },
    {
        "name": "OpenAI whisper-1",
        "key_name": "OPENAI_API_KEY",
        "call": lambda key, path: call_openai(key, path, "whisper-1"),
    },
    {
        "name": "Groq whisper-large-v3-turbo",
        "key_name": "GROQ_API_KEY",
        "call": lambda key, path: call_groq(key, path, "whisper-large-v3-turbo"),
    },
    {
        "name": "Groq distil-whisper-large-v3-en",
        "key_name": "GROQ_API_KEY",
        "call": lambda key, path: call_groq(key, path, "distil-whisper-large-v3-en"),
    },
]


# ---------------------------------------------------------------------------
# Evaluation
# ---------------------------------------------------------------------------

def similarity(a, b):
    """Normalized string similarity (0-1)."""
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()


def run_eval(providers, keys, wav_path, iterations):
    """Run all providers and collect results."""
    active = [p for p in providers if keys.get(p["key_name"])]
    skipped = [p for p in providers if not keys.get(p["key_name"])]

    if skipped:
        print(f"\n  Skipping (no API key): {', '.join(p['name'] for p in skipped)}")
    print(f"  Testing: {', '.join(p['name'] for p in active)}")
    print()

    all_results = {p["name"]: [] for p in active}

    for iteration in range(iterations):
        if iterations > 1:
            print(f"  --- Iteration {iteration + 1}/{iterations} ---")

        # Run all providers in parallel
        futures = {}
        with ThreadPoolExecutor(max_workers=len(active)) as executor:
            for p in active:
                key = keys[p["key_name"]]
                future = executor.submit(p["call"], key, wav_path)
                futures[future] = p["name"]

            for future in as_completed(futures):
                name = futures[future]
                try:
                    transcript, latency, error = future.result()
                except Exception as e:
                    transcript, latency, error = None, 0, str(e)

                if error:
                    print(f"  {name:40s}  ERROR: {error[:80]}")
                    all_results[name].append({
                        "iteration": iteration + 1,
                        "error": error,
                        "latency": latency,
                    })
                else:
                    chars = len(transcript) if transcript else 0
                    print(f"  {name:40s}  {latency:6.2f}s  {chars:4d} chars")
                    all_results[name].append({
                        "iteration": iteration + 1,
                        "transcript": transcript,
                        "latency": latency,
                        "chars": chars,
                    })

    return all_results


def compute_consensus(results):
    """Find the most common transcript (plurality vote)."""
    transcripts = []
    for name, runs in results.items():
        for run in runs:
            if "transcript" in run and run["transcript"]:
                transcripts.append(run["transcript"])
    if not transcripts:
        return ""
    # Use the transcript most similar to all others as reference
    best_score = -1
    best = transcripts[0]
    for t in transcripts:
        score = sum(similarity(t, other) for other in transcripts)
        if score > best_score:
            best_score = score
            best = t
    return best


def generate_report(results, consensus, wav_path, iterations, timestamp):
    """Generate markdown comparison report."""
    lines = [
        "# STT Provider Evaluation",
        "",
        f"- Generated: {timestamp}",
        f"- Audio: `{Path(wav_path).name}`",
        f"- Iterations: {iterations}",
        "",
        "## Results",
        "",
        "| Provider | Latency (avg) | Latency (min) | Chars | Similarity | Errors |",
        "| --- | --- | --- | --- | --- | --- |",
    ]

    # Sort by average latency
    summaries = []
    for name, runs in results.items():
        successes = [r for r in runs if "transcript" in r]
        errors = [r for r in runs if "error" in r]
        if not successes:
            summaries.append((name, 999, 999, 0, 0, len(errors), len(runs)))
            continue
        avg_lat = sum(r["latency"] for r in successes) / len(successes)
        min_lat = min(r["latency"] for r in successes)
        avg_chars = sum(r["chars"] for r in successes) / len(successes)
        # Similarity to consensus
        avg_sim = sum(
            similarity(r["transcript"], consensus) for r in successes
        ) / len(successes) if consensus else 0
        summaries.append((name, avg_lat, min_lat, avg_chars, avg_sim, len(errors), len(runs)))

    summaries.sort(key=lambda x: x[1])

    for name, avg_lat, min_lat, chars, sim, errs, total in summaries:
        if avg_lat == 999:
            lines.append(f"| {name} | — | — | — | — | {errs}/{total} |")
        else:
            lines.append(
                f"| **{name}** | {avg_lat:.2f}s | {min_lat:.2f}s | "
                f"{chars:.0f} | {sim:.1%} | {errs}/{total} |"
            )

    # Transcripts section
    lines.extend(["", "## Transcripts", ""])
    for name, runs in results.items():
        successes = [r for r in runs if "transcript" in r]
        if successes:
            # Show the first successful transcript
            text = successes[0]["transcript"]
            lines.extend([
                f"### {name}",
                "",
                f"> {text}",
                "",
            ])

    # Consensus
    if consensus:
        lines.extend([
            "## Consensus Transcript (reference)",
            "",
            f"> {consensus}",
            "",
        ])

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="STT Provider Evaluation")
    parser.add_argument("audio_file", nargs="?", help="Path to audio file (WAV, CAF, etc.)")
    parser.add_argument("--record", type=int, metavar="SECONDS", help="Record N seconds")
    parser.add_argument("--device", type=int, default=1, help="Audio input device index (default: 1)")
    parser.add_argument("--iterations", type=int, default=3, help="Runs per provider (default: 3)")
    args = parser.parse_args()

    if not args.audio_file and not args.record:
        parser.error("Provide an audio file or use --record N")

    # Load keys
    key_names = list({p["key_name"] for p in PROVIDERS})
    keys = load_env(key_names)
    active_count = sum(1 for p in PROVIDERS if keys.get(p["key_name"]))
    if active_count == 0:
        print("ERROR: No API keys found. Set keys in .env.local or environment.")
        sys.exit(1)

    # Get audio
    if args.record:
        wav_path = tempfile.mktemp(suffix=".wav", prefix="stt-eval-")
        record_audio(args.record, wav_path, device_index=args.device)
    else:
        if not os.path.exists(args.audio_file):
            print(f"ERROR: File not found: {args.audio_file}")
            sys.exit(1)
        wav_path = ensure_wav(args.audio_file)

    file_size = os.path.getsize(wav_path)
    duration = file_size / (16000 * 2)  # 16kHz, 16-bit mono
    print(f"\n  Audio: {wav_path}")
    print(f"  Size: {file_size / 1024:.0f} KB, ~{duration:.1f}s")

    # Run eval
    print(f"\n  Running {args.iterations} iteration(s) per provider...\n")
    results = run_eval(PROVIDERS, keys, wav_path, args.iterations)

    # Compute consensus
    consensus = compute_consensus(results)

    # Generate report
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    report = generate_report(results, consensus, wav_path, args.iterations, timestamp)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    report_path = OUTPUT_DIR / f"stt-eval-{date_str}.md"
    report_path.write_text(report)

    # Save raw data
    raw_path = OUTPUT_DIR / f"stt-eval-raw-{date_str}.json"
    raw_data = {
        "timestamp": timestamp,
        "audio_file": wav_path,
        "duration_s": duration,
        "iterations": args.iterations,
        "results": results,
        "consensus": consensus,
    }
    raw_path.write_text(json.dumps(raw_data, indent=2, default=str))

    # Print summary
    print(f"\n{'=' * 70}")
    print(report)
    print(f"{'=' * 70}")
    print(f"\n  Report: {report_path}")
    print(f"  Raw data: {raw_path}")


if __name__ == "__main__":
    main()
