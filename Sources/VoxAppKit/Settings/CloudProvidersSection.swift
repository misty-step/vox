import SwiftUI

struct CloudProvidersSection: View {
    @ObservedObject private var prefs = PreferencesStore.shared
    private let onManageKeys: () -> Void

    init(onManageKeys: @escaping () -> Void) {
        self.onManageKeys = onManageKeys
    }

    var body: some View {
        GroupBox("Cloud Providers (Optional)") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cloud keys can improve transcription speed and rewrite quality. Without keys, Vox uses Apple Speech on-device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LabeledContent("Transcription") {
                    Text(transcriptionStatus)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Rewrite") {
                    Text(rewriteStatus)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer(minLength: 0)
                    Button("Manage Keys…", action: onManageKeys)
                }

                Text("Keys are stored securely in macOS Keychain.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

#if DEBUG
                Text("Development: env vars override Keychain.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
#endif
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var transcriptionStatus: String {
        let configured = sttProviders
        if configured.isEmpty { return "Apple Speech (on-device)" }
        return "\(configured.joined(separator: " → ")) → Apple Speech"
    }

    private var rewriteStatus: String {
        let chain = rewriteProviders
        return chain.isEmpty ? "Off" : chain
    }

    private var sttProviders: [String] {
        var providers: [String] = []

        if !prefs.elevenLabsAPIKey.isEmpty { providers.append("ElevenLabs") }
        if !prefs.deepgramAPIKey.isEmpty { providers.append("Deepgram") }
        if !prefs.openAIAPIKey.isEmpty { providers.append("Whisper") }

        return providers
    }

    private var rewriteProviders: String {
        [
            !prefs.geminiAPIKey.isEmpty ? "Gemini" : nil,
            !prefs.openRouterAPIKey.isEmpty ? "OpenRouter" : nil,
        ]
        .compactMap { $0 }
        .joined(separator: " → ")
    }
}
