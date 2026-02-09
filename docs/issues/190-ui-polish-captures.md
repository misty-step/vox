# Issue 190 UI Polish Review Captures

Review artifact for `[P1] Execute premium UI polish pass (HUD/menu/settings)`.

## Capture Matrix

### Status Bar Icon Semantics
- `idle`: open `V`
- `recording`: outlined triangle
- `processing`: filled triangle

### HUD States
- `Idle` (`HUDView` preview: `Idle`)
- `Recording Low` (`HUDView` preview: `Recording Low`)
- `Recording High` (`HUDView` preview: `Recording High`)
- `Processing` (`HUDView` preview: `Processing`)
- `Success` (`HUDView` preview: `Success`)
- `Reduced Motion` (`HUDView` preview: `Reduced Motion`)

### Settings Information Architecture
- Settings window header + `API & Providers` tab
- Settings window header + `Dictation` tab

### Menu Information Architecture
- Idle menu (`Status: Ready`, cloud readiness line, `Start Dictation`)
- Recording menu (`Status: Recording`, cloud readiness line, `Stop Dictation`)
- Processing menu (`Status: Processing`, toggle disabled while processing)
- Cloud readiness lines:
  - `Cloud services: Ready`
  - `Cloud STT ready; rewrite missing`
  - `Rewrite ready; transcription local`
  - `Cloud services: Not configured`

## Review Notes
- No new settings were introduced.
- Icon state language is unchanged and enforced by tests.
- Menu/HUD changes prioritize clarity and restrained motion/material treatment.
