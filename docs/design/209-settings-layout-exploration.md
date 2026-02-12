# Settings Redesign Layout Exploration (Issue #209)

Goal: reduce perceived complexity. Basics first. Cloud keys optional.

Constraints:
- No new settings surface.
- Keep Keychain + env override behavior unchanged.

## Layout A: Single Page + Progressive Disclosure (Chosen)

First 10s story:
- Works out of the box (Apple Speech).
- Option+Space to dictate.
- Pick mic if needed.
- Add cloud keys only if you want speed/quality boosts.

Wireframe:
```
Vox Settings
"Works out of the box. Add cloud keys to boost speed + rewriting."

[Basics]
  Hotkey: Option+Space
  Microphone: [System Default v]

[Cloud Boost (Optional)]    Status: STT 0/3, Rewrite 0/2
  > Add / edit cloud keys
      STT: ElevenLabs, Deepgram, OpenAI
      Rewrite: Gemini, OpenRouter

(footer: version, attribution, contact)
```

Pros:
- One screen, no tabs.
- Progressive disclosure hides provider detail until needed.
- Minimal implementation churn (reuse existing key bindings).

Cons:
- Long if expanded (needs scroll).

## Layout B: Sidebar Categories (NavigationSplitView)

Wireframe:
```
Sidebar: Basics | Cloud | About
Content: one category at a time
```

Pros:
- Familiar macOS Settings mental model.
- Clear separation of basic vs advanced.

Cons:
- More UI machinery.
- More "where is X" navigation cost for small preferences set.

## Layout C: 2-Step Setup Wizard (Basics -> Optional Cloud)

Wireframe:
```
Step 1: Basics (hotkey + mic)
Step 2: Cloud boost (optional)
```

Pros:
- Lowest first-run density.
- Forces the right order.

Cons:
- Adds state + flow; heavier than needed for a small settings surface.

## Decision

Pick Layout A. Keep everything on one page, but collapse cloud keys by default.

