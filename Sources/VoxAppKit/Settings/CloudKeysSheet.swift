import SwiftUI

struct CloudKeysSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var prefs = PreferencesStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.16))
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Cloud Provider Keys")
                        .font(.title2.weight(.bold))
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

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsSection(
                        title: "Transcription (Speech-to-Text)",
                        systemImage: "waveform",
                        prominence: .primary
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Configured providers are tried in order, then Vox falls back to Apple Speech.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            ForEach(CloudProviderCatalog.transcriptionKeys) { key in
                                KeyField(
                                    title: key.title,
                                    detail: key.detail,
                                    text: binding(for: key.keyPath)
                                )
                            }
                        }
                    }

                    SettingsSection(
                        title: "Rewrite",
                        systemImage: "sparkles",
                        prominence: .secondary
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Used for Clean/Polish processing levels.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            ForEach(CloudProviderCatalog.rewriteKeys) { key in
                                KeyField(
                                    title: key.title,
                                    detail: key.detail,
                                    text: binding(for: key.keyPath)
                                )
                            }
                        }
                    }

                    HStack {
                        Link("Setup guide", destination: CloudProviderCatalog.setupGuideURL)
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer(minLength: 0)
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
    /// Live `PreferencesStore` binding — written only on commit, not every keystroke.
    let text: Binding<String>

    /// Local buffer: edits accumulate here, never touching Keychain mid-type.
    @State private var draft: String = ""

    private var isConfigured: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    Circle()
                        .fill(isConfigured ? Color.green : Color.gray.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Text(isConfigured ? "Configured" : "Not configured")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                Spacer(minLength: 0)
            }

            SecureField("API key", text: $draft) {
                // onSubmit: commit when user presses Return
                commit()
            }
            .textContentType(.password)
            .textFieldStyle(.roundedBorder)
            .onAppear { draft = text.wrappedValue }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .onDisappear { commit() }
    }

    private func commit() {
        text.wrappedValue = draft
    }
}
