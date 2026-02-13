# HUD State System Exploration

**Issue**: #210 — Design exploration for recorder HUD states
**Source**: User feedback on #190
**Date**: 2026-02-12

---

## Problems

Three observations from user feedback:

1. **Recording state feels noisy.** Red dot + timer + 8-segment meter is a lot of visual information for "I'm listening." The meter updates at ~80ms intervals, creating constant motion.

2. **Racing/fallback states are confusing.** Messages like "Retrying 2/3 (0.5s)" and "Trying Deepgram…" expose internal provider names and retry mechanics. Users don't know what Deepgram is. They don't care about backoff delays.

3. **Done/processing lacks intentional feel.** Processing shows a spinner + variable text. Done flashes a green checkmark for 0.5s then vanishes. The transition from "Transcribing" → "Retrying 1/3 (0.5s)" → "Trying Deepgram…" → "Done" feels like watching debug output, not a polished state machine.

### Current State Map

| State | Visual | Text | Duration |
|-------|--------|------|----------|
| Idle | Gray dot | "Ready" | Until triggered |
| Recording | Pulsing red dot + timer + 8-segment meter | None | User-controlled |
| Processing | Spinner | "Transcribing" | Varies |
| Retrying | Spinner | "Retrying 2/3 (0.5s)" | Brief |
| Fallback | Spinner | "Trying Deepgram…" | Brief |
| Success | Green checkmark | "Done" | 0.5s auto-hide |
| Error | — | — | Hide immediately |

The problem isn't individual states — it's the **transitions**. A user sees: `● 00:14 [▓▓░░░░░░]` → `◌ Transcribing` → `◌ Retrying 1/3 (0.5s)` → `◌ Trying Deepgram…` → `✓ Done`. Five distinct visual states in a few seconds, two of which contain jargon.

---

## Design Principles (Shared)

These apply regardless of which concept we choose:

1. **Provider names never surface.** "Deepgram", "ElevenLabs", "Whisper" are implementation details.
2. **Retry mechanics never surface.** "2/3", "0.5s delay" are engineering telemetry, not user status.
3. **One processing state, not three.** Recording → Processing → Done. No mid-processing state changes unless significantly delayed.
4. **Done should register.** 0.5s is too fast for conscious acknowledgment. 1.0–1.5s lets the user see the result before it vanishes.
5. **Consistent sizing.** No jumpy layout changes between states.

---

## Concept 1: Red Dot (Minimal Motion)

### Philosophy
*The camera metaphor. Recording = red dot. That's it.*

Strip the recording state to its essence: you're recording. The timer tells you how long. Everything else is noise.

### State Map

```
RECORDING:  ● 01:23
            ↑   ↑
         Red dot Timer only. No meter. No label.
         (pulsing)

PROCESSING: ◌ Transcribing…
            ↑
         Spinner. Same text always. No state changes mid-processing.

DONE:       ✓ Done
            Holds 1.2s, then fades.

ERROR:      Fade out (no visible error state in HUD — error dialog handles it)
```

### Audio Level Feedback
Instead of the 8-segment meter, audio levels modulate the **red dot opacity** (0.6 → 1.0) and **scale** (0.9 → 1.1). Louder speech = brighter, larger dot. Subtle enough to feel alive without demanding attention.

### Retry/Fallback Handling
Processing message stays "Transcribing…" regardless of what's happening underneath. If processing exceeds 8 seconds, message upgrades to "Still transcribing…" — acknowledging the wait without explaining why.

### Sizing
Fixed 180×44px for all non-idle states. Idle stays compact at 132×34px.

### Tradeoffs
- **Pro**: Extremely low cognitive load. Familiar metaphor (camera, voice memo).
- **Pro**: No layout shifts between recording and processing.
- **Con**: Power users lose the level meter. No way to see if the mic is picking up audio beyond the dot modulation.
- **Con**: Might feel *too* minimal — "is it working?"

---

## Concept 2: Meter-First Hero

### Philosophy
*The level meter IS the state indicator. Everything else orbits it.*

Invert the current hierarchy: the meter becomes the dominant visual element spanning most of the HUD width. The red dot and timer become secondary annotations.

### State Map

```
RECORDING:  ● [▓▓▓▓▓▓▓▓▓░░░░░░░] 01:23
            ↑  ←──── 16 segments ────→   ↑
         Small    Hero meter, full width   Timer
         red dot                           right-aligned

PROCESSING: [░░░░░░░░░░░░░░░░░] Transcribing…
            Meter segments pulse in sequence (Knight Rider / KITT pattern)
            L→R sweep, 1.5s cycle

DONE:       [▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓] Done ✓
            All segments fill simultaneously (green tint), hold 1.2s

ERROR:      Meter fades out
```

### Audio Level Feedback
16-segment meter with smooth transitions. Segments have slight height variation (taller toward center) for a more organic waveform feel. Active segments are white 0.92 opacity; inactive are 0.12.

### Retry/Fallback Handling
Same as Concept 1: always "Transcribing…", upgrades to "Still transcribing…" after 8s.

### Sizing
Fixed 260×44px for recording/processing/done. Wider to accommodate the hero meter.

### Tradeoffs
- **Pro**: Clear audio feedback — users can see their mic is working.
- **Pro**: The KITT sweep during processing is visually interesting and communicates "working" without text churn.
- **Con**: Wider HUD takes more screen space.
- **Con**: The meter-to-sweep transition might feel discontinuous.

---

## Concept 3: Unified Capsule

### Philosophy
*One shape. One rhythm. State expressed through color and content, never layout.*

The HUD is always the same capsule. The interior changes; the container never does. This eliminates all layout transitions and makes state changes feel like a single object morphing rather than switching between different UI components.

### State Map

```
IDLE:       [·] Ready                     (gray, compact)

RECORDING:  [● 01:23 ▓▓▓▓░░░░]           (white border, expanded)
            Red dot + timer + 4-segment mini-meter

PROCESSING: [◌ Transcribing…]             (same dimensions, same border)
            Spinner replaces dot. Meter fades out. Timer fades out.

DONE:       [✓ Done]                      (green border pulse, same dimensions)
            Check replaces spinner. Holds 1.2s.
```

### Key Difference: Transition Animation
Content crossfades within the fixed capsule. The red dot morphs into the spinner (scale down → rotation starts → trim path appears). The spinner morphs into the checkmark (trim path completes into check shape). This creates a visual through-line: `● → ◌ → ✓`.

### Audio Level Feedback
Retained as a 4-segment mini-meter (down from current 8). Compact, subordinate to the timer. Disappears during processing — it served its purpose during recording.

### Retry/Fallback Handling
"Transcribing…" always. After 10s: "Almost there…" — warmer, more reassuring than "Still transcribing."

### Sizing
Expanded: 220×44px (slightly narrower than current 236). Compact: 120×34px.

### Tradeoffs
- **Pro**: Zero layout jank. The capsule is always the same shape/size.
- **Pro**: The ● → ◌ → ✓ morphing creates a narrative arc (recording → working → done).
- **Pro**: 4-segment meter keeps "is the mic working?" feedback without the visual noise of 8 segments.
- **Con**: The morphing animation adds implementation complexity.
- **Con**: "Almost there…" is a white lie — we don't know how long processing will take.

---

## Concept 4: Status Line (Text-Forward)

### Philosophy
*Words over widgets. Every state is a clear, human sentence.*

Replace iconography with plain language. The HUD becomes a floating status bar that tells you what's happening in words.

### State Map

```
IDLE:       Ready

RECORDING:  Recording · 01:23
            (Red left accent bar, no icons)

PROCESSING: Transcribing your recording…
            (Animated ellipsis: . → .. → …, 0.8s cycle)

DONE:       Transcription complete
            (Green left accent bar, holds 1.5s)
```

### Audio Level Feedback
None visible. The red accent bar on the left edge pulses subtly with audio level (opacity 0.6 → 1.0).

### Retry/Fallback Handling
"Transcribing your recording…" always. After 8s: "Taking a bit longer than usual…"

### Sizing
Variable width based on text, max 280px. Fixed height 36px.

### Tradeoffs
- **Pro**: Maximum clarity. Zero ambiguity about what's happening.
- **Pro**: Accessible by default — screen readers get the same information as sighted users.
- **Con**: Text-only feels generic. Loses the premium feel of the current design.
- **Con**: Variable width means layout shifts between states.
- **Con**: No audio feedback at all — users can't tell if the mic is working.

---

## Concept 5: Phased Density

### Philosophy
*Show more when it matters, less when it doesn't.*

Recording needs audio feedback (is the mic working?). Processing doesn't. Done needs acknowledgment. Adapt information density to what the user actually needs in each phase.

### State Map

```
RECORDING:  ● 01:23 [▓▓▓▓░░░░]           Full info: dot + timer + meter
            (Current layout, but 6 segments instead of 8, tighter spacing)

PROCESSING: ◌ Transcribing…               Simplified: spinner + text
            (Meter and timer slide out with crossfade, 0.2s)

DONE:       ✓ Done                         Minimal: check + word
            (Green border, holds 1.2s, fades 0.3s)

LONG WAIT:  ◌ Still working…              After 8s, text updates once
            (No further changes regardless of retries/fallbacks)
```

### Key Difference: Explicit "Long Wait" Threshold
After 8 seconds in processing, one — and only one — status update: "Still working…". This acknowledges the delay without the current cascade of retry/fallback messages. No further updates after this.

### Audio Level Feedback
6-segment meter during recording only. Segments have uniform height (no variation) for a cleaner look. Meter slides out when transitioning to processing.

### Retry/Fallback Handling
8s threshold for single update. Provider names and retry counts never surface.

### Sizing
236×44px recording (same width, slightly shorter). 200×44px processing/done (narrower since meter is gone).

### Tradeoffs
- **Pro**: Keeps what works (meter during recording) while fixing what doesn't (processing noise).
- **Pro**: Smallest change from current implementation — low risk.
- **Con**: Still has a width transition between recording and processing.
- **Con**: The 8s threshold is arbitrary; could feel wrong for both fast and slow transcriptions.

---

## Comparison

| Aspect | Red Dot | Meter-First | Unified Capsule | Status Line | Phased Density |
|--------|---------|-------------|-----------------|-------------|----------------|
| **Recording clarity** | Low (dot only) | High (hero meter) | Medium (mini meter) | Low (text only) | High (6-segment) |
| **Processing clarity** | High | High (KITT sweep) | High | High | High |
| **Layout stability** | Good | Good | Best | Poor (variable) | Fair (width shifts) |
| **Implementation effort** | Low | Medium | Medium-High | Low | Low |
| **Visual identity** | Minimal | Strong | Strong | Generic | Familiar |
| **Provider leakage** | None | None | None | None | None |
| **Change from current** | Large | Large | Medium | Large | Small |

---

## Selected: Pure KITT

After three rounds of visual prototyping (HTML/CSS), **Pure KITT** was selected.

### Design

260×44px fixed for all states. 20 segments. No text, no icons, no dots. Every state is communicated exclusively through the meter. The meter IS the HUD.

| State | Visual | Duration |
|-------|--------|----------|
| Idle | 20 segments at 8% opacity, 3px | Hidden |
| Recording | Segments respond to audio level + timer right-aligned | User-controlled |
| Processing | KITT sweep (L→R scanning beam, 2s cycle, staggered 0.06s/segment) | Until done |
| Success | Green cascade fills all 20 segments L→R (staggered 0.015s/segment) | 1.2s hold |

### What Changed (from prior implementation)

| Before | After |
|--------|-------|
| 8-segment meter | 20-segment full-width meter |
| Red pulsing dot | No dot — meter IS the recording indicator |
| Spinner + "Transcribing" text | KITT sweep animation (no text, no spinner) |
| Green checkmark + "Done" text | Green cascade (no text, no icons) |
| "Retrying 2/3 (0.5s)" | Provider names never surface |
| "Trying Deepgram…" | Provider names never surface |
| 0.5s success display | 1.2s success display |
| 236×48, varies by state | 260×44 fixed for all states |
| VoiceOver: "Processing, Retrying 1/2" | VoiceOver: "Processing" (always) |

### Reduced Motion

- Recording: instant segment updates (no transition animation)
- Processing: all segments at 30% opacity, 6px height (static, no sweep)
- Success: all segments instantly green (no cascade stagger)

### Files Changed

- `Sources/VoxMac/HUDView.swift` — Full rewrite with Pure KITT components
- `Sources/VoxAppKit/VoxSession.swift` — Removed provider-leaking HUD messages
- `Sources/VoxMac/HUDAccessibility.swift` — Processing always says "Processing"
- `Tests/VoxAppTests/HUDAccessibilityTests.swift` — Updated for new copy

### Rejected (Round 1–3)

All five initial concepts (Red Dot, Meter-First Hero, Unified Capsule, Status Line, Phased Density) were prototyped as HTML/CSS. Three rounds of iteration narrowed to two poles: bold sci-fi vs ultra-subdued. Six Round 3 designs (Pure KITT, Neon Scanner, Razor, Ghost, Terminal, Beam) were evaluated. Pure KITT selected for its committed aesthetic and zero-text design language.
