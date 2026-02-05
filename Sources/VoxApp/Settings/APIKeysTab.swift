import SwiftUI

public struct APIKeysTab: View {
    @ObservedObject private var prefs = PreferencesStore.shared

    public init() {}

    public var body: some View {
        Form {
            Section("Speech-to-Text (ElevenLabs)") {
                SecureField("ElevenLabs API Key", text: binding(for: \.elevenLabsAPIKey))
                    .textContentType(.password)
                SecureField("Deepgram API Key (optional fallback)", text: binding(for: \.deepgramAPIKey))
                    .textContentType(.password)
                SecureField("OpenAI API Key (optional Whisper)", text: binding(for: \.openAIAPIKey))
                    .textContentType(.password)
                Text("Apple Speech (on-device) is always available as final fallback")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link("Deepgram Console", destination: URL(string: "https://console.deepgram.com/")!)
            }

            Section("Rewrite (OpenRouter)") {
                SecureField("OpenRouter API Key", text: binding(for: \.openRouterAPIKey))
                    .textContentType(.password)
            }
        }
        .padding(12)
    }

    private func binding(for keyPath: ReferenceWritableKeyPath<PreferencesStore, String>) -> Binding<String> {
        Binding(
            get: { prefs[keyPath: keyPath] },
            set: { prefs[keyPath: keyPath] = $0 }
        )
    }
}
