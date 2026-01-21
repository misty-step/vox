# macOS Client Plan

## App shape
- Menu bar app + background process
- Launch at login optional
- Minimal onboarding: mic + accessibility + sign-in (if required)

## Hotkey
- Default Option+Space
- Tap to start listening
- Tap again to commit + finalize

## UI feedback (prototype)
- Menu bar title changes: idle / recording / processing

## Settings (menu bar)
- One setting: `Processing` with levels (Off / Light / Aggressive)
- Radio/checkmark selection in menu
- Persists to config file

## Audio pipeline
- AVAudioRecorder to temp file
- Linear PCM, 16kHz, mono

## STT request
- Send recorded file to STT provider
- Await full transcript response

## Context.md
- Location: `~/Documents/Vox/context.md`
- Create if missing, keep brief starter content
- Watch file changes, keep snapshot
- Enforce size limit + truncate policy

## Text insertion
- Primary: clipboard paste + restore
- Fallback: AX setValue, then simulated typing
- Accessibility permission required
