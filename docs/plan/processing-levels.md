# Processing Levels — Spec

## Problem
- Current rewrite sometimes over-edits
- Need single knob, not settings maze

## Goals
- One setting, three levels
- Default safe for daily use
- Clear behavior per level
- No hidden model/provider coupling in UX

## Non-goals
- Per-app profiles
- Multiple knobs (tone, length, persona)
- Live preview editor

## Setting
- Name: `processing_level`
- Values: `off`, `light`, `aggressive`
- Default: `light`
- Config surfaces:
  - `.env.local` → `VOX_PROCESSING_LEVEL` (fallback: `VOX_REWRITE_LEVEL`)
  - `~/Documents/Vox/config.json` → `processingLevel`

## Level 1 — Off (Raw Transcript)
- Pipeline: STT only, no LLM call
- Output: raw provider text
- Purpose: speed, trust, debugging

## Level 2 — Light Post-Processing
- Model: fast/cheap (ex: Gemini Flash)
- Scope:
  - Punctuation, capitalization, sentence splits
  - Light formatting (new lines, simple lists)
  - Preserve wording and order
- Guardrails:
  - Do not remove filler words
  - Do not paraphrase or summarize
  - Keep numbers, acronyms, proper nouns verbatim

## Level 3 — Aggressive Cleanup + Elevation
- Model: stronger (ex: Gemini Pro/Flash Thinking)
- Scope:
  - Clarify intent, structure, tone
  - Can reorder for clarity
  - Can summarize, but must keep all specific nouns, requirements, and constraints
- Output tone:
  - Executive, concise, actionable
  - Suitable for coding/LLM instructions
- Guardrails:
  - No new facts
  - Keep all named entities + numbers
  - If unsure, keep original phrasing

## Failure + Fallback
- Rewrite failure → raw transcript
- Aggressive output missing entities → fallback to light (policy, no code yet)

## UX Notes
- One selector only (Off / Light / Aggressive)
- No per-session prompts
- Primary surface: menu bar menu item
  - Label: `Processing`
  - Submenu: `Off`, `Light`, `Aggressive` (radio/checkmark)
  - Change applies next run, not mid-session
- Secondary surface: config file for power users
  - `.env.local` and `~/Documents/Vox/config.json`

## Acceptance
- Off skips rewrite call
- Light never drops filler words
- Aggressive never invents facts or deletes named entities
