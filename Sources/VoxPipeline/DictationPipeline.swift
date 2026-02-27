import Foundation
import VoxCore

/// Tracks timing for each pipeline stage.
/// Note: `totalTime` is a live wall-clock reading — use stage sums for captured snapshots.
public struct PipelineTiming: Sendable {
    public let startTime: CFAbsoluteTime
    public var processingLevel: ProcessingLevel? = nil
    public var encodeTime: TimeInterval = 0
    public var sttTime: TimeInterval = 0
    public var rewriteTime: TimeInterval = 0
    public var pasteTime: TimeInterval = 0
    public var originalSizeBytes: Int = 0
    public var encodedSizeBytes: Int = 0
    /// Non-zero when the transcript came from streaming STT; captures time from stop to finalized transcript.
    public var finalizeTimeInterval: TimeInterval = 0

    public init() {
        self.startTime = CFAbsoluteTimeGetCurrent()
    }

    public var totalTime: TimeInterval {
        CFAbsoluteTimeGetCurrent() - startTime
    }

    public func summary() -> String {
        if finalizeTimeInterval > 0 {
            // Streaming path: finalize replaces encode+stt
            return String(
                format: "[Pipeline] Total: %.2fs (finalize: %dms, rewrite: %.2fs, paste: %.2fs)",
                totalTime, Int(finalizeTimeInterval * 1000), rewriteTime, pasteTime
            )
        }
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

private actor OpusConversionUnavailableLogger {
    private var hasLogged = false

    func attemptLogOnce() -> Bool {
        guard !hasLogged else { return false }
        hasLogged = true
        return true
    }
}

public final class DictationPipeline: DictationProcessing, TranscriptRecoveryProcessing {
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
    private let isOpusConversionEnabled: @Sendable () async -> Bool
    private let convertCAFToOpus: @Sendable (URL) async throws -> URL
    private let opusUnavailableReason: @Sendable () async -> String?
    private static let opusConversionUnavailableLogger = OpusConversionUnavailableLogger()
    // Internal seam for tests/benchmarks; default path uses CapturedAudioInspector.
    private let audioFrameValidator: @Sendable (URL) throws -> Void
    // Invoked once per process call. On failures it receives partial stage timings.
    private let timingHandler: (@Sendable (PipelineTiming) -> Void)?
    // Invoked when a transcript is successfully processed and pasted.
    // Async so callers can persist state (e.g. recovery snapshot) before process() returns.
    private let onProcessedTranscript: (@Sendable (_ rawTranscript: String, _ outputText: String, _ processingLevel: ProcessingLevel) async -> Void)?
    // Debug-only hooks for live transcript/rewrite inspection.
    private let onRawTranscript: (@Sendable (_ rawTranscript: String) -> Void)?
    private let onRewriteResult: (@Sendable (_ level: ProcessingLevel, _ outputText: String) -> Void)?
    private let onPipelineLog: (@Sendable (_ message: String) -> Void)?
    // Structured diagnostics events. Caller (VoxSession) wires this to DiagnosticsStore.
    // Keeps VoxPipeline free of a VoxDiagnostics dependency.
    private let onDiagnosticsLog: (@Sendable (_ name: String, _ message: String) -> Void)?

    @MainActor
    public convenience init(
        stt: STTProvider,
        rewriter: RewriteProvider,
        paster: TextPaster,
        prefs: PreferencesReading,
        enableRewriteCache: Bool = false,
        enableOpus: Bool = true,
        isOpusConversionEnabled: @escaping @Sendable () async -> Bool = { true },
        convertCAFToOpus: @escaping @Sendable (URL) async throws -> URL = { $0 },
        opusUnavailableReason: @escaping @Sendable () async -> String? = { nil },
        opusBypassThreshold: Int = 200_000,
        pipelineTimeout: TimeInterval = 120,
        timingHandler: (@Sendable (PipelineTiming) -> Void)? = nil,
        onProcessedTranscript: (@Sendable (_ rawTranscript: String, _ outputText: String, _ processingLevel: ProcessingLevel) async -> Void)? = nil,
        onRawTranscript: (@Sendable (_ rawTranscript: String) -> Void)? = nil,
        onRewriteResult: (@Sendable (_ level: ProcessingLevel, _ outputText: String) -> Void)? = nil,
        onPipelineLog: (@Sendable (_ message: String) -> Void)? = nil,
        onDiagnosticsLog: (@Sendable (_ name: String, _ message: String) -> Void)? = nil,
        audioFrameValidator: @escaping @Sendable (URL) throws -> Void = { _ in }
    ) {
        self.init(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            rewriteCache: .shared,
            enableRewriteCache: enableRewriteCache,
            enableOpus: enableOpus,
            isOpusConversionEnabled: isOpusConversionEnabled,
            convertCAFToOpus: convertCAFToOpus,
            opusUnavailableReason: opusUnavailableReason,
            opusBypassThreshold: opusBypassThreshold,
            pipelineTimeout: pipelineTimeout,
            timingHandler: timingHandler,
            onProcessedTranscript: onProcessedTranscript,
            onRawTranscript: onRawTranscript,
            onRewriteResult: onRewriteResult,
            onPipelineLog: onPipelineLog,
            onDiagnosticsLog: onDiagnosticsLog,
            audioFrameValidator: audioFrameValidator
        )
    }

    @MainActor
    init(
        stt: STTProvider,
        rewriter: RewriteProvider,
        paster: TextPaster,
        prefs: PreferencesReading,
        rewriteCache: RewriteResultCache,
        enableRewriteCache: Bool = false,
        enableOpus: Bool = true,
        isOpusConversionEnabled: @escaping @Sendable () async -> Bool = { true },
        convertCAFToOpus: @escaping @Sendable (URL) async throws -> URL = { $0 },
        opusUnavailableReason: @escaping @Sendable () async -> String? = { nil },
        opusBypassThreshold: Int = 200_000,
        pipelineTimeout: TimeInterval = 120,
        rewriteStageTimeouts: RewriteStageTimeouts = .default,
        timingHandler: (@Sendable (PipelineTiming) -> Void)? = nil,
        onProcessedTranscript: (@Sendable (_ rawTranscript: String, _ outputText: String, _ processingLevel: ProcessingLevel) async -> Void)? = nil,
        onRawTranscript: (@Sendable (_ rawTranscript: String) -> Void)? = nil,
        onRewriteResult: (@Sendable (_ level: ProcessingLevel, _ outputText: String) -> Void)? = nil,
        onPipelineLog: (@Sendable (_ message: String) -> Void)? = nil,
        onDiagnosticsLog: (@Sendable (_ name: String, _ message: String) -> Void)? = nil,
        audioFrameValidator: @escaping @Sendable (URL) throws -> Void = { _ in }
    ) {
        self.stt = stt
        self.rewriter = rewriter
        self.paster = paster
        self.prefs = prefs
        self.rewriteCache = rewriteCache
        self.enableRewriteCache = enableRewriteCache
        self.enableOpus = enableOpus
        self.opusBypassThreshold = opusBypassThreshold
        self.isOpusConversionEnabled = isOpusConversionEnabled
        self.convertCAFToOpus = convertCAFToOpus
        self.opusUnavailableReason = opusUnavailableReason
        self.pipelineTimeout = pipelineTimeout
        self.rewriteStageTimeouts = rewriteStageTimeouts
        self.timingHandler = timingHandler
        self.onProcessedTranscript = onProcessedTranscript
        self.onRawTranscript = onRawTranscript
        self.onRewriteResult = onRewriteResult
        self.onPipelineLog = onPipelineLog
        self.onDiagnosticsLog = onDiagnosticsLog
        self.audioFrameValidator = audioFrameValidator
    }

    public func process(audioURL: URL) async throws -> String {
        var timing = PipelineTiming()
        defer {
            timingHandler?(timing)
        }

        // Capture original size BEFORE encoding
        let originalAttributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path)
        timing.originalSizeBytes = originalAttributes?[.size] as? Int ?? 0
        try audioFrameValidator(audioURL)

        // Encode to Opus if enabled
        let uploadURL: URL
        let isCAF = audioURL.pathExtension.lowercased() == "caf"
        if enableOpus, isCAF, timing.originalSizeBytes >= opusBypassThreshold {
            let encodeStart = CFAbsoluteTimeGetCurrent()
            do {
                if await isOpusConversionEnabled() {
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
                } else {
                    if await Self.opusConversionUnavailableLogger.attemptLogOnce(),
                       let unavailable = await opusUnavailableReason() {
                        print("[Pipeline] Opus unavailable: \(unavailable)")
                    }
                    uploadURL = audioURL
                }
            } catch {
                print("[Pipeline] Opus conversion skipped, using CAF fallback")
                #if DEBUG
                print("[Pipeline] Opus conversion failed: \(error.localizedDescription)")
                #endif
                onDiagnosticsLog?("opus_conversion_fallback", "conversion_stage=opus error=\(error.localizedDescription)")
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
        onRawTranscript?(transcript)

        let level = await MainActor.run { prefs.processingLevel }
        timing.processingLevel = level
        logActiveProcessingLevel(level)
        let processed = try await rewriteAndPaste(
            transcript: transcript,
            level: level,
            bypassRewriteCache: false
        )
        await onProcessedTranscript?(transcript, processed.text, level)
        timing.rewriteTime = processed.rewriteTime
        timing.pasteTime = processed.pasteTime

        #if DEBUG
        print(timing.summary())
        #endif
        return processed.text
    }

    public func process(transcript rawTranscript: String) async throws -> String {
        let level = await MainActor.run { prefs.processingLevel }
        return try await process(
            transcript: rawTranscript,
            processingLevel: level,
            bypassRewriteCache: false,
            streamingFinalizeTimeInterval: 0
        )
    }

    /// Extended entry point for the streaming path; includes finalize time in the timing summary.
    public func process(
        transcript rawTranscript: String,
        streamingFinalizeTimeInterval: TimeInterval
    ) async throws -> String {
        let level = await MainActor.run { prefs.processingLevel }
        return try await process(
            transcript: rawTranscript,
            processingLevel: level,
            bypassRewriteCache: false,
            streamingFinalizeTimeInterval: streamingFinalizeTimeInterval
        )
    }

    public func process(
        transcript rawTranscript: String,
        processingLevel: ProcessingLevel,
        bypassRewriteCache: Bool
    ) async throws -> String {
        try await process(
            transcript: rawTranscript,
            processingLevel: processingLevel,
            bypassRewriteCache: bypassRewriteCache,
            streamingFinalizeTimeInterval: 0
        )
    }

    private func process(
        transcript rawTranscript: String,
        processingLevel: ProcessingLevel,
        bypassRewriteCache: Bool,
        streamingFinalizeTimeInterval: TimeInterval
    ) async throws -> String {
        var timing = PipelineTiming()
        timing.finalizeTimeInterval = streamingFinalizeTimeInterval
        defer {
            timingHandler?(timing)
        }

        let transcript = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { throw VoxError.noTranscript }
        onRawTranscript?(transcript)
        timing.processingLevel = processingLevel
        logActiveProcessingLevel(processingLevel)
        let processed = try await rewriteAndPaste(
            transcript: transcript,
            level: processingLevel,
            bypassRewriteCache: bypassRewriteCache
        )
        await onProcessedTranscript?(transcript, processed.text, processingLevel)

        timing.rewriteTime = processed.rewriteTime
        timing.pasteTime = processed.pasteTime

        print(timing.summary())
        return processed.text
    }

    private func rewriteAndPaste(
        transcript: String,
        level: ProcessingLevel,
        bypassRewriteCache: Bool
    ) async throws -> (text: String, rewriteTime: TimeInterval, pasteTime: TimeInterval) {
        var output = transcript
        var rewriteTime: TimeInterval = 0
        if level != .raw {
            let rewriteStart = CFAbsoluteTimeGetCurrent()
            let model = level.defaultModel
            do {
                if enableRewriteCache,
                   !bypassRewriteCache,
                   let cached = await rewriteCache.value(
                    for: transcript,
                    level: level,
                    model: model
                ) {
                    output = cached
                    #if DEBUG
                    print("[Pipeline] Rewrite cache hit")
                    #endif
                    onPipelineLog?("rewrite cache hit (level=\(level.rawValue), model=\(model))")
                    recordRewriteStageOutcome(
                        level: level,
                        model: model,
                        outcome: "cache_hit",
                        extra: "cache_hit=true"
                    )
                } else {
                    let prompt = RewritePrompts.prompt(for: level, transcript: transcript)
                    guard let rewriteTimeoutSeconds = rewriteStageTimeouts.seconds(for: level) else {
                        throw VoxError.internalError("Rewrite timeout requested for level: \(level)")
                    }
                    let candidate = try await withTimeout(
                        seconds: rewriteTimeoutSeconds,
                        context: .rewrite,
                        timeoutError: RewriteStageTimeoutError.deadlineExceeded
                    ) {
                        try await self.rewriter.rewrite(
                            transcript: transcript,
                            systemPrompt: prompt,
                            model: model
                        )
                    }
                    let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedCandidate.isEmpty {
                        print("[Pipeline] Rewrite returned empty, using raw transcript")
                        onPipelineLog?("rewrite returned empty; using raw transcript (level=\(level.rawValue))")
                        output = transcript
                        recordRewriteStageOutcome(
                            level: level,
                            model: model,
                            outcome: "empty_raw_fallback"
                        )
                    } else {
                        output = candidate
                        if enableRewriteCache {
                            await rewriteCache.store(
                                candidate,
                                for: transcript,
                                level: level,
                                model: model
                            )
                        }
                        recordRewriteStageOutcome(
                            level: level,
                            model: model,
                            outcome: "success",
                            extra: "cache_hit=false"
                        )
                    }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch is RewriteStageTimeoutError {
                let waited = CFAbsoluteTimeGetCurrent() - rewriteStart
                print("[Pipeline] Rewrite timed out after \(String(format: "%.2f", waited))s, using raw transcript")
                onPipelineLog?("rewrite timed out after \(Int(waited * 1000))ms; using raw transcript")
                output = transcript
                recordRewriteStageOutcome(
                    level: level,
                    model: model,
                    outcome: "timeout_raw_fallback",
                    extra: "elapsed_ms=\(Int(waited * 1000))"
                )
            } catch {
                print("[Pipeline] Rewrite failed, using raw transcript: \(rewriteFailureSummary(error))")
                onPipelineLog?("rewrite failed; using raw transcript (\(rewriteFailureSummary(error)))")
                output = transcript
                recordRewriteStageOutcome(
                    level: level,
                    model: model,
                    outcome: "error_raw_fallback",
                    extra: "error=\(rewriteFailureSummary(error))"
                )
            }
            rewriteTime = CFAbsoluteTimeGetCurrent() - rewriteStart
        }

        let finalText = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { throw VoxError.noTranscript }
        onRewriteResult?(level, finalText)

        let pasteStart = CFAbsoluteTimeGetCurrent()
        #if DEBUG
        print("[Pipeline] Pasting \(finalText.count) chars")
        #endif
        onPipelineLog?("pasting \(finalText.count) chars")
        try await paster.paste(text: finalText)
        let pasteTime = CFAbsoluteTimeGetCurrent() - pasteStart

        return (text: finalText, rewriteTime: rewriteTime, pasteTime: pasteTime)
    }

    private func logActiveProcessingLevel(_ level: ProcessingLevel) {
        if level == .raw {
            onPipelineLog?("processing level raw (rewrite disabled)")
            #if DEBUG
            print("[Pipeline] Processing level: raw (rewrite disabled)")
            #endif
        } else {
            onPipelineLog?("processing level \(level.rawValue) (model: \(level.defaultModel))")
            #if DEBUG
            print("[Pipeline] Processing level: \(level.rawValue) (model: \(level.defaultModel))")
            #endif
        }
    }

    private func recordRewriteStageOutcome(
        level: ProcessingLevel,
        model: String,
        outcome: String,
        extra: String = ""
    ) {
        var message = "level=\(level.rawValue) model=\(model) outcome=\(outcome)"
        if !extra.isEmpty {
            message += " \(extra)"
        }
        onDiagnosticsLog?("rewrite_stage_outcome", message)
    }

}

// MARK: - Timeout Helper

private enum TimeoutContext: String, Sendable {
    case pipeline
    case rewrite
}

private enum RewriteStageTimeoutError: Error, Sendable {
    case deadlineExceeded
}

/// Wraps an async operation with a deadline.
/// Used to cap total multi-provider STT attempts (4 providers × retries = 360s worst-case without this).
private func withPipelineTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withTimeout(seconds: seconds, context: .pipeline, timeoutError: VoxError.pipelineTimeout, operation: operation)
}

private func withTimeout<T: Sendable, TimeoutError: Error & Sendable>(
    seconds: TimeInterval,
    context: TimeoutContext,
    timeoutError: TimeoutError,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let timeoutNanoseconds = try validatedTimeoutNanoseconds(seconds: seconds, context: context)

    return try await withThrowingTaskGroup(of: T.self) { group in
        defer { group.cancelAll() }

        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: timeoutNanoseconds)
            throw timeoutError
        }
        guard let result = try await group.next() else { throw timeoutError }
        return result
    }
}

private func validatedTimeoutNanoseconds(seconds: TimeInterval, context: TimeoutContext) throws -> UInt64 {
    guard seconds > 0, seconds.isFinite else {
        throw VoxError.internalError("Invalid \(context.rawValue) timeout: \(seconds)")
    }

    let nanoseconds = seconds * 1_000_000_000
    // Keep conversion strict: values rounding up to 2^64 must be rejected.
    guard nanoseconds.isFinite, nanoseconds >= 0, nanoseconds < Double(UInt64.max) else {
        throw VoxError.internalError("Invalid \(context.rawValue) timeout: \(seconds)")
    }

    return UInt64(nanoseconds)
}

public struct RewriteStageTimeouts: Sendable {
    public let cleanSeconds: TimeInterval
    public let polishSeconds: TimeInterval

    public init(cleanSeconds: TimeInterval, polishSeconds: TimeInterval) {
        self.cleanSeconds = cleanSeconds
        self.polishSeconds = polishSeconds
    }

    public static let `default` = RewriteStageTimeouts(
        cleanSeconds: 15,
        polishSeconds: 30
    )

    public func seconds(for level: ProcessingLevel) -> TimeInterval? {
        switch level {
        case .clean:
            return cleanSeconds
        case .polish:
            return polishSeconds
        case .raw:
            return nil
        }
    }
}

private func rewriteFailureSummary(_ error: Error) -> String {
    if let rewriteError = error as? RewriteError {
        switch rewriteError {
        case .auth:
            return "auth"
        case .quotaExceeded:
            return "quotaExceeded"
        case .throttled:
            return "throttled"
        case .invalidRequest(let msg):
            return "invalidRequest(\(msg))"
        case .network(let msg):
            return "network(\(msg))"
        case .timeout:
            return "providerTimeout"
        case .unknown(let msg):
            return "unknown(\(msg))"
        }
    }
    // Avoid logging free-form error text in release; keep it coarse.
    return String(describing: type(of: error))
}

// MARK: - Debug Diagnostics

#if DEBUG
private enum ANSIColor {
    static let green = "\u{001B}[32m"
    static let red = "\u{001B}[31m"
    static let yellow = "\u{001B}[33m"
    static let reset = "\u{001B}[0m"
}

#endif
