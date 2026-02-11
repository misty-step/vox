import SwiftUI

public struct APIKeysTab: View {
    @ObservedObject private var prefs = PreferencesStore.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cloud Provider Keys")
                .font(.headline)
            Text("Optional cloud providers improve speed and rewrite quality. On-device Apple Speech remains available if cloud STT keys are missing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Form {
                Section("Speech-to-Text Providers") {
                    SecureField("ElevenLabs API Key", text: binding(for: \.elevenLabsAPIKey))
                        .textContentType(.password)
                    SecureField("Deepgram API Key (optional fallback)", text: binding(for: \.deepgramAPIKey))
                        .textContentType(.password)
                    SecureField("OpenAI API Key (optional Whisper)", text: binding(for: \.openAIAPIKey))
                        .textContentType(.password)
                    Text("Apple Speech runs locally and is always available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Link("Deepgram Console", destination: URL(string: "https://console.deepgram.com/")!)
                }

                Section("Rewrite Provider") {
                    SecureField("Gemini API Key", text: binding(for: \.geminiAPIKey))
                        .textContentType(.password)
                    SecureField("OpenRouter API Key (fallback)", text: binding(for: \.openRouterAPIKey))
                        .textContentType(.password)
                    Text("Gemini direct is faster. OpenRouter is used if no Gemini key is set.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
    }

    private func binding(for keyPath: ReferenceWritableKeyPath<PreferencesStore, String>) -> Binding<String> {
        Binding(
            get: { prefs[keyPath: keyPath] },
            set: { prefs[keyPath: keyPath] = $0 }
        )
    }
}
