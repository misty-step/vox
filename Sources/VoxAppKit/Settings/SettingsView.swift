import SwiftUI

public struct SettingsView: View {
    private let productInfo: ProductInfo
    @State private var showingCloudKeys = false
    private let hotkeyAvailable: Bool
    private let onRetryHotkey: () -> Void

    public init(
        productInfo: ProductInfo = .current(),
        hotkeyAvailable: Bool = true,
        onRetryHotkey: @escaping () -> Void = {}
    ) {
        self.productInfo = productInfo
        self.hotkeyAvailable = hotkeyAvailable
        self.onRetryHotkey = onRetryHotkey
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(hotkeyAvailable ? "Press Option+Space to dictate" : "Press menu bar icon to dictate")
                    .font(.title3.weight(.semibold))
                Text("Pick a microphone. Add cloud keys only if you want faster transcription and rewriting.")
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
                    BasicsSection(hotkeyAvailable: hotkeyAvailable, onRetryHotkey: onRetryHotkey)
                    CloudProvidersSection(onManageKeys: { showingCloudKeys = true })
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
    }
}
