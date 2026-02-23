# Product Strategy Analysis — 2026-02-23

## Key Themes Identified

### Theme 1: "Confidence Through Transparency" (UX Debt)
Silent rewrite fallback, generic "Processing" message, 1.2s success state with no detail, recovery actions hidden in menus.
- DictationPipeline silently falls back to raw on rewrite failure (no user signal)
- HUDTiming: 1.2s success = invisible
- Recovery: LastDictationRecoveryStore in-memory TTL hidden in menu

### Theme 2: "One-Tap Restart" (UX Recovery)
Recovery snapshot expires silently (10-min TTL). Menu-only affordances. Retry leads to dead-end UX.
- Plumbing exists, just needs surfacing
- Issue #293: Recovery menu items stay enabled after TTL

### Theme 3: "Implicit Context Routing"
One mode for code/email/prose/notes. Generic prompt = inconsistent quality across contexts.
- ADR-0001 killed user-facing settings — use auto-detection instead
- AX API to detect paste target, route to appropriate prompt

### Theme 4: "Honest Onboarding"
Checklist says "complete" too early. AppDelegate prints provider status matrix (all missing keys = confusing).
- OnboardingChecklistView says "Setup complete" when rewrite is non-functional
- Startup printer signals incompleteness to users who see it

### Theme 5: "Power Mode Unlocked"
No path for power users. ADR-0001 gates settings. No monetization hook.
- Opt-in power mode unlocking custom prompts, diagnostics UI
- Lower priority, higher effort

## Critical UX Finding: "Invisible Success Paradox"
Vox's "invisible assistant" promise makes SUCCESS look like FAILURE to users.
Fix: make the process visible (HUD stages), keep interface invisible (no popups).

## Priority Order (impact/effort)
1. Theme 4: Honest Onboarding (Low effort, Medium impact)
2. Theme 2: One-Tap Restart (Low effort, Medium impact)  
3. Theme 1: Transparency (Medium effort, High impact)
4. Theme 3: Context Routing (High effort, High impact)
5. Theme 5: Power Mode (High effort, Long-term)
