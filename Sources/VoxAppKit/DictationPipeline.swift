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

public final class DictationPipeline: DictationProcessing {
    private let stt: STTProvider
    private let rewriter: RewriteProvider
    private let paster: TextPaster
    private let prefs: PreferencesReading
    private let pipelineTimeout: TimeInterval
    private let enableOpus: Bool

    @MainActor
    public init(
        stt: STTProvider,
        rewriter: RewriteProvider,
        paster: TextPaster,
        prefs: PreferencesReading? = nil,
        enableOpus: Bool = true,
        pipelineTimeout: TimeInterval = 120
    ) {
        self.stt = stt
        self.rewriter = rewriter
        self.paster = paster
        self.prefs = prefs ?? PreferencesStore.shared
        self.enableOpus = enableOpus
        self.pipelineTimeout = pipelineTimeout
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

        // STT stage
        let rawTranscript: String
        let sttStart = CFAbsoluteTimeGetCurrent()
        do {
            rawTranscript = try await withPipelineTimeout(seconds: pipelineTimeout) {
                try await self.stt.transcribe(audioURL: uploadURL)
            }
        } catch {
            #if DEBUG
            print("[Pipeline] STT failed: \(error.localizedDescription)")
            #endif
            throw error
        }
        timing.sttTime = CFAbsoluteTimeGetCurrent() - sttStart

        let transcript = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        #if DEBUG
        print("[Pipeline] STT complete (\(transcript.count) chars)")
        #endif
        guard !transcript.isEmpty else { throw VoxError.noTranscript }

        // Rewrite stage
        var output = transcript
        let level = await MainActor.run { prefs.processingLevel }
        if level != .off {
            let rewriteStart = CFAbsoluteTimeGetCurrent()
            do {
                let prompt = RewritePrompts.prompt(for: level, transcript: transcript)
                let candidate = try await rewriter.rewrite(
                    transcript: transcript,
                    systemPrompt: prompt,
                    model: level.defaultModel
                )
                let decision = RewriteQualityGate.evaluate(raw: transcript, candidate: candidate, level: level)
                output = decision.isAcceptable ? candidate : transcript
                if !decision.isAcceptable {
                    #if DEBUG
                    print("[Pipeline] Rewrite rejected by quality gate (ratio: \(String(format: "%.2f", decision.ratio)))")
                    #endif
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                #if DEBUG
                print("[Pipeline] Rewrite failed, using raw transcript: \(error.localizedDescription)")
                #endif
                output = transcript
            }
            timing.rewriteTime = CFAbsoluteTimeGetCurrent() - rewriteStart
        }

        let finalText = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { throw VoxError.noTranscript }

        // Paste stage
        let pasteStart = CFAbsoluteTimeGetCurrent()
        #if DEBUG
        print("[Pipeline] Pasting \(finalText.count) chars")
        #endif
        try await paster.paste(text: finalText)
        timing.pasteTime = CFAbsoluteTimeGetCurrent() - pasteStart

        #if DEBUG
        print(timing.summary())
        #endif
        return finalText
    }
}

// MARK: - Timeout Helper

/// Wraps an async operation with a deadline.
/// Used to cap the STT fallback chain (4 providers × retries = 360s worst-case without this).
private func withPipelineTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    guard seconds > 0, !seconds.isNaN, !seconds.isInfinite else {
        throw VoxError.pipelineTimeout
    }

    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw VoxError.pipelineTimeout
        }
        guard let result = try await group.next() else {
            group.cancelAll()
            throw VoxError.pipelineTimeout
        }
        group.cancelAll()
        return result
    }
}
