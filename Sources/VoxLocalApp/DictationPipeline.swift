import Foundation
import VoxLocalCore
import VoxLocalMac
import VoxLocalProviders

public final class DictationPipeline {
    private let prefs: PreferencesStore
    private let paster: ClipboardPaster

    public init(prefs: PreferencesStore = .shared, paster: ClipboardPaster = ClipboardPaster()) {
        self.prefs = prefs
        self.paster = paster
    }

    public func process(audioURL: URL) async throws -> String {
        print("[Pipeline] Starting processing for \(audioURL.lastPathComponent)")
        let elevenKey = prefs.elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !elevenKey.isEmpty else {
            throw VoxLocalError.provider("ElevenLabs API key is missing.")
        }

        print("[Pipeline] Calling ElevenLabs STT...")
        let stt = ElevenLabsClient(apiKey: elevenKey)
        let rawTranscript = try await stt.transcribe(audioURL: audioURL)
        let transcript = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[Pipeline] Transcript: \(transcript)")
        guard !transcript.isEmpty else { throw VoxLocalError.noTranscript }

        var output = transcript
        let level = prefs.processingLevel
        if level != .off {
            let openRouterKey = prefs.openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !openRouterKey.isEmpty else {
                throw VoxLocalError.provider("OpenRouter API key is missing.")
            }
            let prompt = buildPrompt(level: level, customContext: prefs.customContext)
            let rewriter = OpenRouterClient(apiKey: openRouterKey)
            let candidate = try await rewriter.rewrite(
                transcript: transcript,
                systemPrompt: prompt,
                model: prefs.selectedModel
            )
            let decision = RewriteQualityGate.evaluate(raw: transcript, candidate: candidate, level: level)
            output = decision.isAcceptable ? candidate : transcript
        }

        let finalText = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { throw VoxLocalError.noTranscript }

        print("[Pipeline] Final text to paste: \(finalText)")
        print("[Pipeline] Accessibility trusted: \(PermissionManager.isAccessibilityTrusted())")
        try await MainActor.run {
            print("[Pipeline] Calling paster.paste()...")
            try paster.paste(text: finalText)
            print("[Pipeline] Paste completed successfully")
        }
        return finalText
    }

    private func buildPrompt(level: ProcessingLevel, customContext: String) -> String {
        let base = RewritePrompts.prompt(for: level)
        let trimmed = customContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return "\(base)\n\nContext:\n\(trimmed)"
    }
}
