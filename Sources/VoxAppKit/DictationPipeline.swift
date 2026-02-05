import Foundation
import VoxCore
import VoxMac
import VoxProviders

public final class DictationPipeline: DictationProcessing {
    private let stt: STTProvider
    private let rewriter: RewriteProvider
    private let paster: TextPaster
    private let prefs: PreferencesReading

    @MainActor
    public init(
        stt: STTProvider,
        rewriter: RewriteProvider,
        paster: TextPaster,
        prefs: PreferencesReading? = nil
    ) {
        self.stt = stt
        self.rewriter = rewriter
        self.paster = paster
        self.prefs = prefs ?? PreferencesStore.shared
    }

    public func process(audioURL: URL) async throws -> String {
        print("[Pipeline] Starting processing for \(audioURL.lastPathComponent)")
        let rawTranscript: String
        do {
            rawTranscript = try await stt.transcribe(audioURL: audioURL)
        } catch {
            print("[Pipeline] STT failed: \(error.localizedDescription)")
            throw error
        }
        let transcript = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[Pipeline] STT complete (\(transcript.count) chars)")
        guard !transcript.isEmpty else { throw VoxError.noTranscript }

        var output = transcript
        let preferenceSnapshot = await MainActor.run {
            (
                processingLevel: prefs.processingLevel,
                customContext: prefs.customContext
            )
        }
        let level = preferenceSnapshot.processingLevel
        if level != .off {
            do {
                let prompt = buildPrompt(
                    level: level,
                    transcript: transcript,
                    customContext: preferenceSnapshot.customContext
                )
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
        }

        let finalText = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { throw VoxError.noTranscript }

        print("[Pipeline] Pasting \(finalText.count) chars")
        try await paster.paste(text: finalText)
        print("[Pipeline] Done")
        return finalText
    }

    private func buildPrompt(level: ProcessingLevel, transcript: String, customContext: String) -> String {
        let base = RewritePrompts.prompt(for: level, transcript: transcript)
        let trimmed = customContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return "\(base)\n\nContext:\n\(trimmed)"
    }
}
