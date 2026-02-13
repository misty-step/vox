import SwiftUI

public struct SettingsView: View {
    private let productInfo: ProductInfo
    @State private var showingCloudKeys = false
    @State private var showingVoxCloud = false

    public init(productInfo: ProductInfo = .current()) {
        self.productInfo = productInfo
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(headerTitle)
                    .font(.title3.weight(.semibold))
                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    BasicsSection()
                    cloudProvidersSection
                }
                .padding(16)
            }

            ProductStandardsFooter(productInfo: productInfo)
        }
        .frame(minWidth: 560, minHeight: 420)
        .sheet(isPresented: $showingCloudKeys) {
            CloudKeysSheet()
                .frame(minWidth: 640, minHeight: 520)
        }
        .sheet(isPresented: $showingVoxCloud) {
            VoxCloudTokenSheet()
        }
    }

    private var headerTitle: String {
        PreferencesStore.shared.voxCloudEnabled ? "Vox Cloud Enabled" : "Press Option+Space to dictate"
    }

    private var headerSubtitle: String {
        if PreferencesStore.shared.voxCloudEnabled {
            return "Cloud transcription and rewriting active. No additional provider keys needed."
        }
        return "Pick a microphone. Add cloud keys only if you want faster transcription and rewriting."
    }

    @ViewBuilder
    private var cloudProvidersSection: some View {
        if PreferencesStore.shared.voxCloudEnabled {
            VoxCloudStatusSection(onManage: { showingVoxCloud = true })
        } else {
            CloudProvidersSection(onManageKeys: { showingCloudKeys = true })
        }
    }
}

/// Section shown when Vox Cloud mode is enabled
struct VoxCloudStatusSection: View {
    @ObservedObject private var prefs = PreferencesStore.shared
    private let onManage: () -> Void

    var body: some View {
        GroupBox("Vox Cloud") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Connected")
                        .font(.subheadline.weight(.semibold))
                }

                Text("All transcription and rewriting is handled by Vox Cloud. No individual provider keys required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer(minLength: 0)
                    Button("Manage Token…", action: onManage)
                }

                Text("Token is stored securely in macOS Keychain.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
