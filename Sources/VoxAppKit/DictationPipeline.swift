import Foundation
import VoxCore
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

private struct PipelineResult: Sendable {
    let text: String
    let sttTime: TimeInterval
    let rewriteTime: TimeInterval
    let pasteTime: TimeInterval
}

public final class DictationPipeline: DictationProcessing {
    private let stt: STTProvider
    private let rewriter: RewriteProvider
    private let paster: TextPaster
    private let prefs: PreferencesReading
    private let sttTimeout: TimeInterval
    private let rewriteTimeout: TimeInterval
    private let totalTimeout: TimeInterval
    private let enableOpus: Bool

    @MainActor
    public init(
        stt: STTProvider,
        rewriter: RewriteProvider,
        paster: TextPaster,
        prefs: PreferencesReading? = nil,
        enableOpus: Bool = true,
        sttTimeout: TimeInterval = 15,
        rewriteTimeout: TimeInterval = 10,
        totalTimeout: TimeInterval = 30
    ) {
        self.stt = stt
        self.rewriter = rewriter
        self.paster = paster
        self.prefs = prefs ?? PreferencesStore.shared
        self.enableOpus = enableOpus
        self.sttTimeout = sttTimeout
        self.rewriteTimeout = rewriteTimeout
        self.totalTimeout = totalTimeout
    }

    public func process(audioURL: URL) async throws -> String {
        var timing = PipelineTiming()

        // Capture original size BEFORE encoding
        let originalAttributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path)
        timing.originalSizeBytes = originalAttributes?[.size] as? Int ?? 0

        // Encode to Opus if enabled
        let uploadURL: URL
        if enableOpus {
            let encodeStart = CFAbsoluteTimeGetCurrent()
            let result = await AudioEncoder.encodeForUpload(cafURL: audioURL)
            timing.encodeTime = CFAbsoluteTimeGetCurrent() - encodeStart
            if result.format == .opus {
                timing.encodedSizeBytes = result.bytes
            }
            uploadURL = result.url
        } else {
            uploadURL = audioURL
        }

        // Clean up encoded file after processing (if different from original)
        defer {
            if uploadURL != audioURL {
                SecureFileDeleter.delete(at: uploadURL)
            }
        }

        #if DEBUG
        print("[Pipeline] Starting processing for \(audioURL.lastPathComponent)")
        #endif

        let result = try await withTimeout(seconds: totalTimeout, stage: .fullPipeline) {
            let (transcript, sttTime) = try await self.performSTT(audioURL: uploadURL)
            let (finalText, rewriteTime) = try await self.processTranscript(transcript)
            let pasteTime = try await self.pasteText(finalText)
            return PipelineResult(
                text: finalText,
                sttTime: sttTime,
                rewriteTime: rewriteTime,
                pasteTime: pasteTime
            )
        }

        timing.sttTime = result.sttTime
        timing.rewriteTime = result.rewriteTime
        timing.pasteTime = result.pasteTime
        #if DEBUG
        print(timing.summary())
        #endif
        return result.text
    }

    private func performSTT(audioURL: URL) async throws -> (text: String, duration: TimeInterval) {
        let sttStart = CFAbsoluteTimeGetCurrent()
        let rawTranscript: String
        do {
            rawTranscript = try await withTimeout(seconds: sttTimeout, stage: .stt) {
                try await self.stt.transcribe(audioURL: audioURL)
            }
        } catch {
            #if DEBUG
            print("[Pipeline] STT failed: \(error.localizedDescription)")
            #endif
            throw error
        }

        let transcript = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        #if DEBUG
        print("[Pipeline] STT complete (\(transcript.count) chars)")
        #endif
        guard !transcript.isEmpty else { throw VoxError.noTranscript }
        return (transcript, CFAbsoluteTimeGetCurrent() - sttStart)
    }

    private func processTranscript(_ transcript: String) async throws -> (text: String, duration: TimeInterval) {
        var output = transcript
        var rewriteTime: TimeInterval = 0
        let preferenceSnapshot = await MainActor.run {
            (
                processingLevel: prefs.processingLevel,
                customContext: prefs.customContext
            )
        }
        let level = preferenceSnapshot.processingLevel
        if level != .off {
            let rewriteStart = CFAbsoluteTimeGetCurrent()
            do {
                let prompt = buildPrompt(
                    level: level,
                    transcript: transcript,
                    customContext: preferenceSnapshot.customContext
                )
                let candidate = try await withTimeout(seconds: rewriteTimeout, stage: .rewrite) {
                    try await self.rewriter.rewrite(
                        transcript: transcript,
                        systemPrompt: prompt,
                        model: level.defaultModel
                    )
                }
                let decision = RewriteQualityGate.evaluate(raw: transcript, candidate: candidate, level: level)
                output = decision.isAcceptable ? candidate : transcript
                if !decision.isAcceptable {
                    #if DEBUG
                    print("[Pipeline] Rewrite rejected by quality gate (ratio: \(String(format: "%.2f", decision.ratio)))")
                    #endif
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as VoxError where error == .pipelineTimeout(stage: .rewrite) {
                #if DEBUG
                print("[Pipeline] Rewrite timed out, using raw transcript")
                #endif
                output = transcript
            } catch {
                #if DEBUG
                print("[Pipeline] Rewrite failed, using raw transcript: \(error.localizedDescription)")
                #endif
                output = transcript
            }
            rewriteTime = CFAbsoluteTimeGetCurrent() - rewriteStart
        }

        let finalText = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { throw VoxError.noTranscript }
        return (finalText, rewriteTime)
    }

    private func pasteText(_ text: String) async throws -> TimeInterval {
        let pasteStart = CFAbsoluteTimeGetCurrent()
        #if DEBUG
        print("[Pipeline] Pasting \(text.count) chars")
        #endif
        try await paster.paste(text: text)
        #if DEBUG
        print("[Pipeline] Done")
        #endif
        return CFAbsoluteTimeGetCurrent() - pasteStart
    }

    private func buildPrompt(level: ProcessingLevel, transcript: String, customContext: String) -> String {
        let base = RewritePrompts.prompt(for: level, transcript: transcript)
        let trimmed = customContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return "\(base)\n\nContext:\n\(trimmed)"
    }
}

// MARK: - Timeout Helper

private func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    stage: PipelineStage,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    // Guard against invalid timeout values
    guard seconds > 0, !seconds.isNaN, !seconds.isInfinite else {
        throw VoxError.pipelineTimeout(stage: stage)
    }

    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw VoxError.pipelineTimeout(stage: stage)
        }
        guard let result = try await group.next() else {
            group.cancelAll()
            throw VoxError.pipelineTimeout(stage: stage)
        }
        group.cancelAll()
        return result
    }
}
