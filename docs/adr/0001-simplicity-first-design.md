# ADR-0001: Simplicity-First Design

## Status

Accepted

## Context

Vox competes with SuperWhisper and similar voice-to-text tools that have accumulated layers of settings, modes, and configuration options. Users report feeling overwhelmed by competitors. Vox's core value proposition is that it "just works" — press a hotkey, speak, get text.

Every setting is a question the user must answer. Every option is a decision the user didn't want to make. Feature creep is the existential threat to this product.

An audit of the current codebase (Feb 2026) found the configuration surface is already minimal:

- **4 API keys** (credentials, not preferences)
- **1 microphone picker** (defaults to system device)
- **1 processing level** (Off / Light / Aggressive / Enhance)

No advanced tabs, no threshold tuning, no model selection, no retry configuration. This is good. The question is how to keep it this way as the project grows.

## Decision

All new features and changes must pass a simplicity gate before merging:

### The Gate

1. **Does this add a user-visible setting?** If yes, it must justify why a sensible default isn't possible. The burden of proof is on the setting, not the default. Adding a toggle, dropdown, or text field requires explicit justification in the PR description.

2. **Would this confuse a non-technical user?** If the feature requires explanation beyond a single sentence, it's too complex.

3. **Can this be automatic?** STT provider selection is automatic (cascading fallback). Processing level models are automatic (baked into the enum). This pattern should extend to all new capabilities.

### Concrete Rules

- **Maximum settings surface**: API keys + microphone + processing level. New settings require an ADR.
- **No "Advanced" tabs**: ever.
- **No user-facing threshold tuning**: quality gates, timeouts, retry counts stay internal.
- **No model selection UI**: model choice is a product decision, not a user decision.
- **Dark features are dead features**: code that stores preferences with no UI path must be removed. If it's worth having, it's worth showing. If it's not worth showing, it's not worth maintaining.
- **Defaults over options**: when in doubt, pick the best default and ship it. Revisit only if users report problems.

### Removed in This ADR

`customContext` — a string stored in UserDefaults and appended to rewrite prompts, with no UI to set it. Removed as dead surface area per the "dark features" rule.

## Consequences

### Positive

- Users never feel overwhelmed
- Fewer code paths to test and maintain
- Faster onboarding (set API keys, done)
- Product identity stays clear

### Negative

- Power users can't fine-tune behavior
- Some features that competitors offer won't be added
- Contributors must justify complexity upfront, which adds friction

### Neutral

- The processing level enum remains the primary UX lever for controlling output quality
- If custom context proves valuable, it can return with proper UI and a clear user story

## Alternatives Considered

### Alternative 1: Keep customContext as a Hidden Power-User Feature

Set via defaults write or a config file. Rejected because hidden features violate the simplicity contract — they create undocumented behavior, untested paths, and maintenance burden without serving the target user.

### Alternative 2: Add customContext UI to Settings

Add a text field to the Processing tab. Rejected because it fails the "would this confuse a non-technical user?" test. Most users wouldn't know what context to provide, and an empty text field invites confusion.
