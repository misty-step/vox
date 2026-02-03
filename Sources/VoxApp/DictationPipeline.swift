import Foundation
import VoxCore
import VoxMac
import VoxProviders

public final class DictationPipeline {
    private let stt: STTProvider
    private let rewriter: RewriteProvider
    private let paster: TextPaster
    private let prefs: PreferencesStore

    public init(
        stt: STTProvider,
        rewriter: RewriteProvider,
        paster: TextPaster,
        prefs: PreferencesStore = .shared
    ) {
        self.stt = stt
        self.rewriter = rewriter
        self.paster = paster
        self.prefs = prefs
    }

    public func process(audioURL: URL) async throws -> String {
        print("[Pipeline] Starting processing for \(audioURL.lastPathComponent)")
        print("[Pipeline] Calling STT...")
        let rawTranscript = try await stt.transcribe(audioURL: audioURL)
        let transcript = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[Pipeline] Transcript: \(transcript)")
        guard !transcript.isEmpty else { throw VoxError.noTranscript }

        var output = transcript
        let level = prefs.processingLevel
        if level != .off {
            let prompt = buildPrompt(level: level, transcript: transcript, customContext: prefs.customContext)
            let candidate = try await rewriter.rewrite(
                transcript: transcript,
                systemPrompt: prompt,
                model: level.defaultModel
            )
            let decision = RewriteQualityGate.evaluate(raw: transcript, candidate: candidate, level: level)
            output = decision.isAcceptable ? candidate : transcript
        }

        let finalText = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { throw VoxError.noTranscript }

        print("[Pipeline] Final text to paste: \(finalText)")
        print("[Pipeline] Accessibility trusted: \(PermissionManager.isAccessibilityTrusted())")
        print("[Pipeline] Calling paster.paste()...")
        try await paster.paste(text: finalText)
        print("[Pipeline] Paste completed successfully")
        return finalText
    }

    private func buildPrompt(level: ProcessingLevel, transcript: String, customContext: String) -> String {
        let base = RewritePrompts.prompt(for: level, transcript: transcript)
        let trimmed = customContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return "\(base)\n\nContext:\n\(trimmed)"
    }
}
