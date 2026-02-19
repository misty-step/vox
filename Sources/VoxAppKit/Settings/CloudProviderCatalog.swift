import Foundation

@MainActor
struct CloudProviderKey: Identifiable {
    let id: String
    let title: String
    let detail: String
    let keyPath: ReferenceWritableKeyPath<PreferencesStore, String>
}

@MainActor
enum CloudProviderCatalog {
    static let setupGuideURL = URL(string: "https://github.com/misty-step/vox#configuration")!

    static let transcriptionKeys: [CloudProviderKey] = [
        CloudProviderKey(
            id: "elevenlabs",
            title: "ElevenLabs",
            detail: "Primary cloud transcription.",
            keyPath: \.elevenLabsAPIKey
        ),
        CloudProviderKey(
            id: "deepgram",
            title: "Deepgram",
            detail: "Optional fallback transcription.",
            keyPath: \.deepgramAPIKey
        ),
    ]

    static let rewriteKeys: [CloudProviderKey] = [
        CloudProviderKey(
            id: "gemini",
            title: "Gemini",
            detail: "Primary rewrite provider.",
            keyPath: \.geminiAPIKey
        ),
        CloudProviderKey(
            id: "openrouter",
            title: "OpenRouter",
            detail: "Fallback rewrite provider.",
            keyPath: \.openRouterAPIKey
        ),
    ]

    static func transcriptionSummary(prefs: PreferencesStore) -> String {
        let configured = configuredTitles(from: transcriptionKeys, prefs: prefs)
        if configured.isEmpty { return "Apple Speech (on-device)" }
        return "\(configured.joined(separator: " → ")) → Apple Speech"
    }

    static func rewriteSummary(prefs: PreferencesStore) -> String {
        let configured = configuredTitles(from: rewriteKeys, prefs: prefs)
        if configured.isEmpty { return "Raw transcript" }
        return configured.joined(separator: " → ")
    }

    private static func configuredTitles(from keys: [CloudProviderKey], prefs: PreferencesStore) -> [String] {
        keys.compactMap { key in
            prefs[keyPath: key.keyPath].isEmpty ? nil : key.title
        }
    }
}
