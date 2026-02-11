import Foundation
import VoxCore
import VoxMac
import VoxProviders

/// Tracks timing for each pipeline stage.
/// Note: `totalTime` is a live wall-clock reading — use stage sums for captured snapshots.
struct PipelineTiming: Sendable {
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

public final class DictationPipeline: DictationProcessing, TranscriptProcessing {
    private let stt: STTProvider
    private let rewriter: RewriteProvider
    private let paster: TextPaster
    private let prefs: PreferencesReading
    private let rewriteCache: RewriteResultCache
    private let pipelineTimeout: TimeInterval
    private let rewriteStageTimeouts: RewriteStageTimeouts
    private let enableOpus: Bool
    private let opusBypassThreshold: Int
    private let enableRewriteCache: Bool
    private let convertCAFToOpus: @Sendable (URL) async throws -> URL
    // Invoked once per process call. On failures it receives partial stage timings.
    private let timingHandler: (@Sendable (PipelineTiming) -> Void)?

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
        opusBypassThreshold: Int = 200_000,
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
            opusBypassThreshold: opusBypassThreshold,
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
        opusBypassThreshold: Int = 200_000,
        pipelineTimeout: TimeInterval = 120,
        rewriteStageTimeouts: RewriteStageTimeouts = .default,
        timingHandler: (@Sendable (PipelineTiming) -> Void)? = nil
    ) {
        self.stt = stt
        self.rewriter = rewriter
        self.paster = paster
        self.prefs = prefs ?? PreferencesStore.shared
        self.rewriteCache = rewriteCache
        self.enableRewriteCache = enableRewriteCache
        self.enableOpus = enableOpus
        self.opusBypassThreshold = opusBypassThreshold
        self.convertCAFToOpus = convertCAFToOpus
        self.pipelineTimeout = pipelineTimeout
        self.rewriteStageTimeouts = rewriteStageTimeouts
        self.timingHandler = timingHandler
    }

    public func process(audioURL: URL) async throws -> String {
        var timing = PipelineTiming()
        defer {
            timingHandler?(timing)
        }

        // Capture original size BEFORE encoding
        let originalAttributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path)
        timing.originalSizeBytes = originalAttributes?[.size] as? Int ?? 0
        try CapturedAudioInspector.ensureHasAudioFrames(at: audioURL)

        // Encode to Opus if enabled
        let uploadURL: URL
        let isCAF = audioURL.pathExtension.lowercased() == "caf"
        if enableOpus, isCAF, timing.originalSizeBytes >= opusBypassThreshold {
            let encodeStart = CFAbsoluteTimeGetCurrent()
            do {
                let opusURL = try await convertCAFToOpus(audioURL)
                let attrs = try? FileManager.default.attributesOfItem(atPath: opusURL.path)
                timing.encodedSizeBytes = attrs?[.size] as? Int ?? 0
                if timing.encodedSizeBytes > 0 {
                    uploadURL = opusURL
                } else {
                    print("[Pipeline] Opus conversion produced empty output, using CAF fallback")
                    uploadURL = audioURL
                    SecureFileDeleter.delete(at: opusURL)
                }
            } catch {
                print("[Pipeline] Opus conversion failed: \(error.localizedDescription), using CAF fallback")
                uploadURL = audioURL
            }
            timing.encodeTime = CFAbsoluteTimeGetCurrent() - encodeStart
        } else {
            if enableOpus, isCAF, timing.originalSizeBytes < opusBypassThreshold {
                #if DEBUG
                print("[Pipeline] Opus skipped: file size \(timing.originalSizeBytes) below threshold \(opusBypassThreshold)")
                #endif
            }
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

        let level = await MainActor.run { prefs.processingLevel }
        let processed = try await rewriteAndPaste(transcript: transcript, level: level)
        timing.rewriteTime = processed.rewriteTime
        timing.pasteTime = processed.pasteTime

        #if DEBUG
        print(timing.summary())
        #endif
        return processed.text
    }

    public func process(transcript rawTranscript: String) async throws -> String {
        let transcript = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { throw VoxError.noTranscript }
        let level = await MainActor.run { prefs.processingLevel }
        let processed = try await rewriteAndPaste(transcript: transcript, level: level)
        return processed.text
    }

    private func rewriteAndPaste(
        transcript: String,
        level: ProcessingLevel
    ) async throws -> (text: String, rewriteTime: TimeInterval, pasteTime: TimeInterval) {
        var output = transcript
        var rewriteTime: TimeInterval = 0
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
                    let candidate = try await withRewriteTimeout(seconds: rewriteStageTimeouts.seconds(for: level)) {
                        try await self.rewriter.rewrite(
                            transcript: transcript,
                            systemPrompt: prompt,
                            model: model
                        )
                    }
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
            } catch let error as RewriteError where error == .timeout {
                let waited = CFAbsoluteTimeGetCurrent() - rewriteStart
                print("[Pipeline] Rewrite timed out after \(String(format: "%.2f", waited))s, using raw transcript")
                output = transcript
            } catch {
                print("[Pipeline] Rewrite failed, using raw transcript: \(error.localizedDescription)")
                output = transcript
            }
            rewriteTime = CFAbsoluteTimeGetCurrent() - rewriteStart
        }

        let finalText = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { throw VoxError.noTranscript }

        let pasteStart = CFAbsoluteTimeGetCurrent()
        #if DEBUG
        print("[Pipeline] Pasting \(finalText.count) chars")
        #endif
        try await paster.paste(text: finalText)
        let pasteTime = CFAbsoluteTimeGetCurrent() - pasteStart

        return (text: finalText, rewriteTime: rewriteTime, pasteTime: pasteTime)
    }

}

// MARK: - Timeout Helper

/// Wraps an async operation with a deadline.
/// Used to cap total multi-provider STT attempts (4 providers × retries = 360s worst-case without this).
private func withPipelineTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let timeoutNanoseconds = try validatedTimeoutNanoseconds(seconds: seconds, context: "pipeline")

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

private func withRewriteTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let timeoutNanoseconds = try validatedTimeoutNanoseconds(seconds: seconds, context: "rewrite")

    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: timeoutNanoseconds)
            throw RewriteError.timeout
        }
        guard let result = try await group.next() else {
            group.cancelAll()
            throw RewriteError.timeout
        }
        group.cancelAll()
        return result
    }
}

private func validatedTimeoutNanoseconds(seconds: TimeInterval, context: String) throws -> UInt64 {
    guard seconds > 0, seconds.isFinite else {
        throw VoxError.internalError("Invalid \(context) timeout: \(seconds)")
    }

    let nanoseconds = seconds * 1_000_000_000
    // Keep conversion strict: values rounding up to 2^64 must be rejected.
    guard nanoseconds.isFinite, nanoseconds >= 0, nanoseconds < Double(UInt64.max) else {
        throw VoxError.internalError("Invalid \(context) timeout: \(seconds)")
    }

    return UInt64(nanoseconds)
}

struct RewriteStageTimeouts: Sendable {
    let lightSeconds: TimeInterval
    let aggressiveSeconds: TimeInterval
    let enhanceSeconds: TimeInterval

    static let `default` = RewriteStageTimeouts(
        lightSeconds: 6,
        aggressiveSeconds: 8,
        enhanceSeconds: 10
    )

    func seconds(for level: ProcessingLevel) -> TimeInterval {
        switch level {
        case .off:
            return 0
        case .light:
            return lightSeconds
        case .aggressive:
            return aggressiveSeconds
        case .enhance:
            return enhanceSeconds
        }
    }
}
