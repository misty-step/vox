# Privacy

## Data Vox collects
- Audio temp files during recording
- Optional history artifacts (transcript, rewrite, final, metadata)
- Auth tokens (gateway mode)

## Storage
- Local Mac only: history in `~/Documents/Vox/history` or `VOX_HISTORY_DIR`
- Auth tokens stored in macOS Keychain
- No Vox cloud storage of transcripts or audio

## Controls
- History: Disabled by default. Enable with `VOX_HISTORY=1`.
- Redact history text: `VOX_HISTORY_REDACT=1`
- Retention: `VOX_HISTORY_DAYS` (default: 30)

## Third-party services
- Audio sent to [ElevenLabs](https://elevenlabs.io/privacy) for STT
- Transcript text sent to [Gemini](https://policies.google.com/privacy) or [OpenRouter](https://openrouter.ai/privacy) for rewrite

## Clear statements
- Audio temp files deleted after processing
- Transcripts not sent to Vox servers for storage
