import Foundation
@preconcurrency import VoxCore
import VoxMac
import VoxProviders

/// Tracks timing for each pipeline stage.
struct PipelineTiming {
    let startTime: CFAbsoluteTime
    var encodeTime: TimeInterval = 0
    var sttTime: TimeInterval = 0
    var rewriteTime: TimeInterval = 0
    var pasteTime: TimeInterval = 0
    var originalSizeBytes: Int = 0
    var encodedSizeBytes: Int = 0

    init() {
        self.startTime = CFAbsoluteTimeGetCurrent()
    }

    var totalTime: TimeInterval {
        CFAbsoluteTimeGetCurrent() - startTime
    }

    func summary() -> String {
        let encoded = encodedSizeBytes > 0 ? encodedSizeBytes : originalSizeBytes
        let ratio = originalSizeBytes > 0 ? Double(encoded) / Double(originalSizeBytes) : 1.0
        let sizeInfo = originalSizeBytes > 0
            ? "size: \(formatBytes(originalSizeBytes))→\(formatBytes(encoded)) (\(Int(ratio*100))%)"
            : ""
        return String(
            format: "[Pipeline] Total: %.2fs (encode: %.2fs, stt: %.2fs, rewrite: %.2fs, paste: %.2fs) %@",
            totalTime, encodeTime, sttTime, rewriteTime, pasteTime, sizeInfo
        )
    }
}

private func formatBytes(_ bytes: Int) -> String {
    if bytes < 1024 { return "\(bytes)B" }
    if bytes < 1024 * 1024 { return String(format: "%.1fKB", Double(bytes) / 1024) }
    return String(format: "%.1fMB", Double(bytes) / (1024 * 1024))
}

public final class DictationPipeline: DictationProcessing {
    private let stt: STTProvider
    private let rewriter: RewriteProvider
    private let paster: TextPaster
    private let prefs: PreferencesReading
    private let enableOpus: Bool

    public init(
        stt: STTProvider,
        rewriter: RewriteProvider,
        paster: TextPaster,
        prefs: PreferencesReading? = nil,
        enableOpus: Bool = true
    ) {
        self.stt = stt
        self.rewriter = rewriter
        self.paster = paster
        self.prefs = prefs ?? PreferencesStore.shared
        self.enableOpus = enableOpus
    }

    public func process(audioURL: URL) async throws -> String {
        var timing = PipelineTiming()

        // Encode to Opus if enabled
        let uploadURL: URL
        if enableOpus {
            let encodeStart = CFAbsoluteTimeGetCurrent()
            let result = await AudioEncoder.encodeForUpload(cafURL: audioURL)
            timing.encodeTime = CFAbsoluteTimeGetCurrent() - encodeStart
            timing.originalSizeBytes = result.bytes
            if result.format == .opus {
                timing.encodedSizeBytes = result.bytes
            }
            uploadURL = result.url
        } else {
            uploadURL = audioURL
            timing.originalSizeBytes = (try? Data(contentsOf: audioURL).count) ?? 0
        }

        // Clean up encoded file after processing (if different from original)
        defer {
            if uploadURL != audioURL {
                try? FileManager.default.removeItem(at: uploadURL)
            }
        }

        print("[Pipeline] Starting processing for \(audioURL.lastPathComponent)")

        // STT stage
        let rawTranscript: String
        let sttStart = CFAbsoluteTimeGetCurrent()
        do {
            rawTranscript = try await stt.transcribe(audioURL: uploadURL)
        } catch {
            print("[Pipeline] STT failed: \(error.localizedDescription)")
            throw error
        }
        timing.sttTime = CFAbsoluteTimeGetCurrent() - sttStart

        let transcript = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[Pipeline] STT complete (\(transcript.count) chars)")
        guard !transcript.isEmpty else { throw VoxError.noTranscript }

        // Rewrite stage
        var output = transcript
        let level = prefs.processingLevel
        if level != .off {
            let rewriteStart = CFAbsoluteTimeGetCurrent()
            do {
                let prompt = buildPrompt(level: level, transcript: transcript, customContext: prefs.customContext)
                let candidate = try await rewriter.rewrite(
                    transcript: transcript,
                    systemPrompt: prompt,
                    model: level.defaultModel
                )
                let decision = RewriteQualityGate.evaluate(raw: transcript, candidate: candidate, level: level)
                output = decision.isAcceptable ? candidate : transcript
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                print("[Pipeline] Rewrite failed, using raw transcript: \(error.localizedDescription)")
            }
            timing.rewriteTime = CFAbsoluteTimeGetCurrent() - rewriteStart
        }

        let finalText = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { throw VoxError.noTranscript }

        // Paste stage
        let pasteStart = CFAbsoluteTimeGetCurrent()
        print("[Pipeline] Pasting \(finalText.count) chars")
        try await paster.paste(text: finalText)
        timing.pasteTime = CFAbsoluteTimeGetCurrent() - pasteStart

        print(timing.summary())
        return finalText
    }

    private func buildPrompt(level: ProcessingLevel, transcript: String, customContext: String) -> String {
        let base = RewritePrompts.prompt(for: level, transcript: transcript)
        let trimmed = customContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return "\(base)\n\nContext:\n\(trimmed)"
    }
}
