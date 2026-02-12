import SwiftUI

struct CloudKeysSheet: View {
    @ObservedObject private var prefs = PreferencesStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Cloud Provider Keys")
                    .font(.title3.weight(.semibold))
                Text("Optional. Keys are stored securely in macOS Keychain.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

#if DEBUG
                Text("Development: env vars override Keychain.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
#endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GroupBox("Transcription (Speech-to-Text)") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Configured providers are tried in order, then Vox falls back to Apple Speech.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            KeyField(
                                title: "ElevenLabs",
                                detail: "Primary cloud transcription.",
                                text: binding(for: \.elevenLabsAPIKey)
                            )

                            KeyField(
                                title: "Deepgram",
                                detail: "Optional fallback transcription.",
                                text: binding(for: \.deepgramAPIKey)
                            )

                            KeyField(
                                title: "OpenAI (Whisper)",
                                detail: "Optional fallback transcription via Whisper.",
                                text: binding(for: \.openAIAPIKey)
                            )
                        }
                        .padding(12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    GroupBox("Rewrite") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Used for Light/Aggressive/Enhance processing levels.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            KeyField(
                                title: "Gemini",
                                detail: "Primary rewrite provider.",
                                text: binding(for: \.geminiAPIKey)
                            )

                            KeyField(
                                title: "OpenRouter",
                                detail: "Fallback rewrite provider.",
                                text: binding(for: \.openRouterAPIKey)
                            )
                        }
                        .padding(12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Link("Setup guide", destination: URL(string: "https://github.com/misty-step/vox#configuration")!)
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 6)
                }
                .padding(16)
            }
        }
    }

    private func binding(for keyPath: ReferenceWritableKeyPath<PreferencesStore, String>) -> Binding<String> {
        Binding(
            get: { prefs[keyPath: keyPath] },
            set: { prefs[keyPath: keyPath] = $0 }
        )
    }
}

private struct KeyField: View {
    let title: String
    let detail: String
    let text: Binding<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            SecureField("API key", text: text)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
