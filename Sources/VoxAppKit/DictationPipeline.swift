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
        print("[Pipeline] Starting processing for \(audioURL.lastPathComponent)")

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
        } catch let error as VoxError {
            print("[Pipeline] STT failed: \(error.localizedDescription)")
            throw error
        } catch {
            print("[Pipeline] STT failed: \(error.localizedDescription)")
            throw error
        }

        let transcript = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[Pipeline] STT complete (\(transcript.count) chars)")
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
                    print("[Pipeline] Rewrite rejected by quality gate (ratio: \(String(format: "%.2f", decision.ratio)))")
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as VoxError where error == .pipelineTimeout(stage: .rewrite) {
                print("[Pipeline] Rewrite timed out, using raw transcript")
                output = transcript
            } catch {
                print("[Pipeline] Rewrite failed, using raw transcript: \(error.localizedDescription)")
                output = transcript
            }
        }

        let finalText = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { throw VoxError.noTranscript }
        return finalText
    }

    private func pasteText(_ text: String) async throws {
        print("[Pipeline] Pasting \(text.count) chars")
        try await paster.paste(text: text)
        print("[Pipeline] Done")
    }

    private func buildPrompt(level: ProcessingLevel, transcript: String, customContext: String) -> String {
        let base = RewritePrompts.prompt(for: level, transcript: transcript)
        let trimmed = customContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return "\(base)\n\nContext:\n\(trimmed)"
    }
}

// MARK: - Timeout Helper

private func withTimeout<T>(
    seconds: TimeInterval,
    stage: PipelineStage,
    operation: () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw VoxError.pipelineTimeout(stage: stage)
        }
        guard let result = try await group.next() else {
            throw VoxError.pipelineTimeout(stage: stage)
        }
        group.cancelAll()
        return result
    }
}
