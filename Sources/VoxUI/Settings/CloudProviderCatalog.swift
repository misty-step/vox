import Foundation
import VoxMac

@MainActor
struct CloudProviderKey: Identifiable {
    let id: String
    let title: String
    let detail: String
    let keyPath: ReferenceWritableKeyPath<PreferencesStore, String>
    let keychainKey: KeychainHelper.Key
}

@MainActor
public enum CloudProviderCatalog {
    static let setupGuideURL = URL(string: "https://github.com/misty-step/vox#configuration")!

    static let transcriptionKeys: [CloudProviderKey] = [
        CloudProviderKey(
            id: "elevenlabs",
            title: "ElevenLabs",
            detail: "Primary cloud transcription.",
            keyPath: \.elevenLabsAPIKey,
            keychainKey: .elevenLabsAPIKey
        ),
        CloudProviderKey(
            id: "deepgram",
            title: "Deepgram",
            detail: "Optional fallback transcription.",
            keyPath: \.deepgramAPIKey,
            keychainKey: .deepgramAPIKey
        ),
    ]

    static let rewriteKeys: [CloudProviderKey] = [
        CloudProviderKey(
            id: "gemini",
            title: "Gemini",
            detail: "Used for Gemini model IDs and as best-effort fallback.",
            keyPath: \.geminiAPIKey,
            keychainKey: .geminiAPIKey
        ),
        CloudProviderKey(
            id: "openrouter",
            title: "OpenRouter",
            detail: "Used for non-Gemini model IDs (e.g. Mercury).",
            keyPath: \.openRouterAPIKey,
            keychainKey: .openRouterAPIKey
        ),
    ]

    static func transcriptionSummary(prefs: PreferencesStore) -> String {
        let configured = configuredTitles(from: transcriptionKeys, cache: prefs.keyStatusCache)
        return transcriptionSummary(configuredProviderTitles: configured)
    }

    static func transcriptionSummary(configuredProviderTitles: [String]) -> String {
        if configuredProviderTitles.isEmpty { return "Apple Speech (on-device)" }
        return "\(configuredProviderTitles.joined(separator: " → ")) → Apple Speech"
    }

    public static func rewriteSummary(prefs: PreferencesStore) -> String {
        let configured = configuredTitles(from: rewriteKeys, cache: prefs.keyStatusCache)
        return rewriteSummary(configuredProviderTitles: configured)
    }

    static func rewriteSummary(configuredProviderTitles: [String]) -> String {
        let configured = Set(configuredProviderTitles)
        let hasGemini = configured.contains("Gemini")
        let hasOpenRouter = configured.contains("OpenRouter")

        switch (hasGemini, hasOpenRouter) {
        case (false, false):
            return "Raw transcript"
        case (true, false):
            return "Gemini"
        case (false, true):
            return "OpenRouter"
        case (true, true):
            return "Model-routed (OpenRouter for non-Gemini models; Gemini for Gemini models/fallback)"
        }
    }

    private static func configuredTitles(
        from keys: [CloudProviderKey],
        cache: [KeychainHelper.Key: Bool]
    ) -> [String] {
        keys.compactMap { key in
            cache[key.keychainKey] == true ? key.title : nil
        }
    }
}
