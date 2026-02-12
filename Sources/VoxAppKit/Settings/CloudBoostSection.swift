import SwiftUI

struct CloudBoostSection: View {
    @ObservedObject private var prefs = PreferencesStore.shared
    @State private var showKeys = false

    var body: some View {
        Section("Cloud Boost (Optional)") {
            Text("Add cloud keys to improve speed and rewrite quality. Apple Speech remains available either way.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            DisclosureGroup(isExpanded: $showKeys) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speech-to-Text")
                            .font(.subheadline.weight(.semibold))

                        SecureField("ElevenLabs API Key", text: binding(for: \.elevenLabsAPIKey))
                            .textContentType(.password)
                        SecureField("Deepgram API Key (optional fallback)", text: binding(for: \.deepgramAPIKey))
                            .textContentType(.password)
                        SecureField("OpenAI API Key (optional Whisper)", text: binding(for: \.openAIAPIKey))
                            .textContentType(.password)

                        Link("Deepgram Console", destination: URL(string: "https://console.deepgram.com/")!)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rewrite")
                            .font(.subheadline.weight(.semibold))

                        SecureField("Gemini API Key", text: binding(for: \.geminiAPIKey))
                            .textContentType(.password)
                        SecureField("OpenRouter API Key (fallback)", text: binding(for: \.openRouterAPIKey))
                            .textContentType(.password)

                        Text("Gemini direct is faster. OpenRouter is used if no Gemini key is set.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("Add / edit cloud provider keys")
            }
        }
    }

    private var statusText: String {
        "Status: STT \(sttConfiguredCount)/3, Rewrite \(rewriteConfiguredCount)/2"
    }

    private var sttConfiguredCount: Int {
        [
            prefs.elevenLabsAPIKey,
            prefs.deepgramAPIKey,
            prefs.openAIAPIKey,
        ].filter { !$0.isEmpty }.count
    }

    private var rewriteConfiguredCount: Int {
        [
            prefs.geminiAPIKey,
            prefs.openRouterAPIKey,
        ].filter { !$0.isEmpty }.count
    }

    private func binding(for keyPath: ReferenceWritableKeyPath<PreferencesStore, String>) -> Binding<String> {
        Binding(
            get: { prefs[keyPath: keyPath] },
            set: { prefs[keyPath: keyPath] = $0 }
        )
    }
}
