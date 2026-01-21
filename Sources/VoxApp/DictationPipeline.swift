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

    func run(audioURL: URL, processingLevel: ProcessingLevel) async throws -> String {
        let sessionId = UUID()

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

        let trimmed = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VoxError.noTranscript
        }

        guard processingLevel != .off else {
            Diagnostics.info("Processing level off. Skipping rewrite.")
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
            Diagnostics.info("Submitting transcript to rewrite provider.")
            let response = try await rewriteProvider.rewrite(request)
            let candidate = response.finalText.trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.isEmpty {
                Diagnostics.error("Rewrite returned empty text. Using raw transcript.")
                return transcript.text
            }
            Diagnostics.info("Rewrite completed. Output length: \(candidate.count) chars.")
            return candidate
        } catch {
            Diagnostics.error("Rewrite failed: \(String(describing: error)). Using raw transcript.")
            return transcript.text
        }
    }
}
