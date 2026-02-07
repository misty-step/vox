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
    private let rewriteCache: RewriteResultCache
    private let pipelineTimeout: TimeInterval
    private let enableOpus: Bool
    private let enableRewriteCache: Bool
    private let convertCAFToOpus: @Sendable (URL) async throws -> URL

    @MainActor
    public convenience init(
        stt: STTProvider,
        rewriter: RewriteProvider,
        paster: TextPaster,
        prefs: PreferencesReading? = nil,
        enableRewriteCache: Bool = false,
        enableOpus: Bool = true,
        convertCAFToOpus: @escaping @Sendable (URL) async throws -> URL = { inputURL in
            try await AudioConverter.convertCAFToOpus(from: inputURL)
        },
        pipelineTimeout: TimeInterval = 120
    ) {
        self.init(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            rewriteCache: .shared,
            enableRewriteCache: enableRewriteCache,
            enableOpus: enableOpus,
            convertCAFToOpus: convertCAFToOpus,
            pipelineTimeout: pipelineTimeout
        )
    }

    @MainActor
    init(
        stt: STTProvider,
        rewriter: RewriteProvider,
        paster: TextPaster,
        prefs: PreferencesReading? = nil,
        rewriteCache: RewriteResultCache,
        enableRewriteCache: Bool = false,
        enableOpus: Bool = true,
        convertCAFToOpus: @escaping @Sendable (URL) async throws -> URL = { inputURL in
            try await AudioConverter.convertCAFToOpus(from: inputURL)
        },
        pipelineTimeout: TimeInterval = 120
    ) {
        self.stt = stt
        self.rewriter = rewriter
        self.paster = paster
        self.prefs = prefs ?? PreferencesStore.shared
        self.rewriteCache = rewriteCache
        self.enableRewriteCache = enableRewriteCache
        self.enableOpus = enableOpus
        self.convertCAFToOpus = convertCAFToOpus
        self.pipelineTimeout = pipelineTimeout
    }

    public func process(audioURL: URL) async throws -> String {
        var timing = PipelineTiming()

        // Capture original size BEFORE encoding
        let originalAttributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path)
        timing.originalSizeBytes = originalAttributes?[.size] as? Int ?? 0

        // Encode to Opus if enabled
        let uploadURL: URL
        if enableOpus, audioURL.pathExtension.lowercased() == "caf" {
            let encodeStart = CFAbsoluteTimeGetCurrent()
            do {
                let opusURL = try await convertCAFToOpus(audioURL)
                let attrs = try? FileManager.default.attributesOfItem(atPath: opusURL.path)
                timing.encodedSizeBytes = attrs?[.size] as? Int ?? 0
                uploadURL = opusURL
            } catch {
                print("[Pipeline] Opus conversion failed: \(error.localizedDescription), using CAF fallback")
                uploadURL = audioURL
            }
            timing.encodeTime = CFAbsoluteTimeGetCurrent() - encodeStart
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
            print("[Pipeline] STT failed: \(error.localizedDescription)")
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
            let model = level.defaultModel
            do {
                if enableRewriteCache,
                   let cached = await rewriteCache.value(
                    for: transcript,
                    level: level,
                    model: model
                ) {
                    output = cached
                    #if DEBUG
                    print("[Pipeline] Rewrite cache hit")
                    #endif
                } else {
                    let prompt = RewritePrompts.prompt(for: level, transcript: transcript)
                    let candidate = try await rewriter.rewrite(
                        transcript: transcript,
                        systemPrompt: prompt,
                        model: model
                    )
                    let decision = RewriteQualityGate.evaluate(raw: transcript, candidate: candidate, level: level)
                    if decision.isAcceptable {
                        output = candidate
                        if enableRewriteCache {
                            await rewriteCache.store(
                                candidate,
                                for: transcript,
                                level: level,
                                model: model
                            )
                        }
                    } else {
                        output = transcript
                        print("[Pipeline] Rewrite rejected by quality gate (ratio: \(String(format: "%.2f", decision.ratio)))")
                    }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                print("[Pipeline] Rewrite failed, using raw transcript: \(error.localizedDescription)")
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
    let timeoutNanoseconds = try validatedTimeoutNanoseconds(seconds: seconds)

    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: timeoutNanoseconds)
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

private func validatedTimeoutNanoseconds(seconds: TimeInterval) throws -> UInt64 {
    guard seconds > 0, seconds.isFinite else {
        throw VoxError.internalError("Invalid pipeline timeout: \(seconds)")
    }

    let nanoseconds = seconds * 1_000_000_000
    // Keep conversion strict: values rounding up to 2^64 must be rejected.
    guard nanoseconds.isFinite, nanoseconds >= 0, nanoseconds < Double(UInt64.max) else {
        throw VoxError.internalError("Invalid pipeline timeout: \(seconds)")
    }

    return UInt64(nanoseconds)
}
