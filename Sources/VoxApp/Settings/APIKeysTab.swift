import SwiftUI

public struct APIKeysTab: View {
    @ObservedObject private var prefs = PreferencesStore.shared

    public init() {}

    public var body: some View {
        Form {
            Section("Speech-to-Text (ElevenLabs)") {
                SecureField("ElevenLabs API Key", text: binding(for: \.elevenLabsAPIKey))
                    .textContentType(.password)
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
