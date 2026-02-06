# Mission: Fix PR #155 — CI Failures + Review Comments

You are Bramble. You previously opened PR #155 on misty-step/vox (branch `bramble/performance`). CI is failing and reviewers flagged issues. Fix everything and push.

## Location
`/home/sprite/workspace/vox` — checkout branch `bramble/performance`

## CI Build Errors (MUST FIX FIRST)

### 1. ElevenLabsClient.swift — `readData(ofLength:)` returns `Data`, not `Data?`
```
error: initializer for conditional binding must have Optional type, not 'Data'
while let chunk = audioFileHandle.readData(ofLength: chunkSize), !chunk.isEmpty {
```
Fix: `readData(ofLength:)` returns `Data` (non-optional). Use a regular loop:
```swift
var chunk = audioFileHandle.readData(ofLength: chunkSize)
while !chunk.isEmpty {
    handle.write(chunk)
    chunk = audioFileHandle.readData(ofLength: chunkSize)
}
```

### 2. WhisperClient.swift — Same `readData` issue + unused variable
```
error: immutable value 'multipartSize' was never used
error: initializer for conditional binding must have Optional type, not 'Data'
```
Fix: Replace `let (multipartURL, multipartSize)` with `let (multipartURL, _)` and fix the same readData loop pattern.

## Review Comments to Address

### Critical (gemini-code-assist)
1. **AudioEncoder.swift:89** — `convertBuffer` uses `withCheckedThrowingContinuation` unnecessarily. `AVAudioConverter.convert(to:error:withInputFrom:)` is synchronous. Remove the continuation wrapper, call it directly.
2. **DictationPipeline.swift:76** — `timing.originalSizeBytes` is set to encoded file size, not original. Fix: capture original size BEFORE encoding.
3. **AudioEncoder.swift:111** — Reads entire file into memory with `Data(contentsOf:)` just for size. Use `FileManager.default.attributesOfItem(atPath:)` instead.

### Major (coderabbitai)
4. **Use SecureFileDeleter** for all audio file cleanup (DictationPipeline, AudioEncoder, ElevenLabsClient, WhisperClient). Check if `SecureFileDeleter` exists in the codebase; if not, use `FileManager.default.removeItem`.
5. **ElevenLabsClient.swift + WhisperClient.swift** — Deduplicate `buildMultipartFile` into a shared utility.

## Rules
- `git checkout bramble/performance` first
- Fix ALL build errors — run `swift build` to verify
- Address ALL critical and major review comments
- Small commits with conventional messages (e.g., `fix: resolve readData non-optional type error`)
- Push when done — CI will re-run automatically
- Do NOT rebase or force-push

## Git Config
```bash
git config user.name "kaylee-mistystep"
git config user.email "kaylee@mistystep.io"
```
