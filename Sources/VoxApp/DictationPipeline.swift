import Foundation
import VoxCore

final class DictationPipeline {
    private let sttProvider: STTProvider
    private let rewriteProvider: RewriteProvider
    private let contextURL: URL
    private let locale: String
    private let modelId: String?

    init(
        sttProvider: STTProvider,
        rewriteProvider: RewriteProvider,
        contextURL: URL,
        locale: String,
        modelId: String?
    ) {
        self.sttProvider = sttProvider
        self.rewriteProvider = rewriteProvider
        self.contextURL = contextURL
        self.locale = locale
        self.modelId = modelId
    }

    func run(
        sessionId: UUID,
        audioURL: URL,
        processingLevel: ProcessingLevel,
        history: HistorySession?
    ) async throws -> String {
        Diagnostics.info("Session \(sessionId.uuidString) processing level: \(processingLevel.rawValue).")
        Diagnostics.info("Submitting audio to STT provider.")
        let transcript = try await sttProvider.transcribe(
            TranscriptionRequest(
                sessionId: sessionId,
                audioFileURL: audioURL,
                locale: locale,
                modelId: modelId
            )
        )
        Diagnostics.info("STT completed. Transcript length: \(transcript.text.count) chars.")
        if let history {
            await history.recordTranscript(transcript.text)
        }

        let trimmed = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VoxError.noTranscript
        }

        guard processingLevel != .off else {
            Diagnostics.info("Processing level off. Skipping rewrite.")
            if let history {
                await history.recordFinal(transcript.text)
            }
            return transcript.text
        }

        let context = (try? String(contentsOf: contextURL)) ?? ""
        let request = RewriteRequest(
            sessionId: sessionId,
            locale: locale,
            transcript: TranscriptPayload(text: transcript.text),
            context: context,
            processingLevel: processingLevel
        )

        do {
            Diagnostics.info("Submitting transcript to rewrite provider. Level: \(processingLevel.rawValue).")
            let response = try await rewriteProvider.rewrite(request)
            let candidate = response.finalText.trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.isEmpty {
                Diagnostics.error("Rewrite returned empty text. Using raw transcript.")
                if let history {
                    await history.recordRewrite(candidate, ratio: 0)
                    await history.recordFinal(transcript.text)
                }
                return transcript.text
            }
            let evaluation = RewriteQualityGate.evaluate(
                raw: transcript.text,
                candidate: candidate,
                level: processingLevel
            )
            if let history {
                await history.recordRewrite(candidate, ratio: evaluation.ratio)
            }
            Diagnostics.info("Rewrite completed. Output length: \(candidate.count) chars. Ratio: \(String(format: "%.2f", evaluation.ratio)).")
            guard evaluation.isAcceptable else {
                Diagnostics.error("Rewrite too short (ratio \(String(format: "%.2f", evaluation.ratio)) < \(String(format: "%.2f", evaluation.minimumRatio))). Using raw transcript.")
                if let history {
                    await history.recordFinal(transcript.text)
                }
                return transcript.text
            }
            if let history {
                await history.recordFinal(candidate)
            }
            return candidate
        } catch {
            Diagnostics.error("Rewrite failed: \(String(describing: error)). Using raw transcript.")
            if let history {
                await history.recordError("Rewrite failed: \(String(describing: error))")
                await history.recordFinal(transcript.text)
            }
            return transcript.text
        }
    }
}
