import SwiftUI

struct CloudProvidersSection: View {
    @ObservedObject private var prefs = PreferencesStore.shared
    private let onManageKeys: () -> Void

    init(onManageKeys: @escaping () -> Void) {
        self.onManageKeys = onManageKeys
    }

    var body: some View {
        SettingsSection(
            title: "Cloud Providers (Optional)",
            systemImage: "cloud.fill",
            prominence: .secondary
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cloud keys can improve transcription speed and rewrite quality. Without keys, Vox uses Apple Speech on-device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Transcription")
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 8) {
                        ForEach(CloudProviderCatalog.transcriptionKeys) { key in
                            ProviderStatusBadge(
                                title: key.title,
                                configured: prefs.keyStatusCache[key.keychainKey] == true
                            )
                        }
                    }
                    Text(CloudProviderCatalog.transcriptionSummary(prefs: prefs))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Rewrite")
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 8) {
                        ForEach(CloudProviderCatalog.rewriteKeys) { key in
                            ProviderStatusBadge(
                                title: key.title,
                                configured: prefs.keyStatusCache[key.keychainKey] == true
                            )
                        }
                    }
                    Text(CloudProviderCatalog.rewriteSummary(prefs: prefs))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer(minLength: 0)
                    Button("Manage Keys…", action: onManageKeys)
                        .buttonStyle(.borderedProminent)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProviderStatusBadge: View {
    let title: String
    let configured: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(configured ? Color.green : Color.gray.opacity(0.6))
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(configured ? Color.primary : Color.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}
