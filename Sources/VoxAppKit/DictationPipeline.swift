import Foundation
@preconcurrency import VoxCore
import VoxMac
import VoxProviders

public final class DictationPipeline: DictationProcessing {
    private let stt: STTProvider
    private let rewriter: RewriteProvider
    private let paster: TextPaster
    private let prefs: PreferencesReading
    private let sttTimeout: TimeInterval
    private let rewriteTimeout: TimeInterval
    private let totalTimeout: TimeInterval

    public init(
        stt: STTProvider,
        rewriter: RewriteProvider,
        paster: TextPaster,
        prefs: PreferencesReading? = nil,
        sttTimeout: TimeInterval = 15,
        rewriteTimeout: TimeInterval = 10,
        totalTimeout: TimeInterval = 30
    ) {
        self.stt = stt
        self.rewriter = rewriter
        self.paster = paster
        self.prefs = prefs ?? PreferencesStore.shared
        self.sttTimeout = sttTimeout
        self.rewriteTimeout = rewriteTimeout
        self.totalTimeout = totalTimeout
    }

    public func process(audioURL: URL) async throws -> String {
        #if DEBUG
        print("[Pipeline] Starting processing for \(audioURL.lastPathComponent)")
        #endif

        return try await withTimeout(
            seconds: totalTimeout,
            stage: .fullPipeline
        ) {
            let transcript = try await self.performSTT(audioURL: audioURL)
            let finalText = try await self.processTranscript(transcript)
            try await self.pasteText(finalText)
            return finalText
        }
    }

    private func performSTT(audioURL: URL) async throws -> String {
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
        return transcript
    }

    private func processTranscript(_ transcript: String) async throws -> String {
        var output = transcript
        let level = prefs.processingLevel

        if level != .off {
            do {
                let prompt = buildPrompt(level: level, transcript: transcript, customContext: prefs.customContext)
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
        }

        let finalText = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { throw VoxError.noTranscript }
        return finalText
    }

    private func pasteText(_ text: String) async throws {
        #if DEBUG
        print("[Pipeline] Pasting \(text.count) chars")
        #endif
        try await paster.paste(text: text)
        #if DEBUG
        print("[Pipeline] Done")
        #endif
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
