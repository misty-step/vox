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
            id: "inception",
            title: "Inception",
            detail: "Used for Mercury model IDs (mercury-2, etc.).",
            keyPath: \.inceptionAPIKey,
            keychainKey: .inceptionAPIKey
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
        let hasInception = configured.contains("Inception")

        switch (hasGemini, hasInception) {
        case (false, false):
            return "Raw transcript"
        case (true, false):
            return "Gemini"
        case (false, true):
            return "Inception"
        case (true, true):
            return "Model-routed (Inception for Mercury models; Gemini for Gemini models/fallback)"
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
