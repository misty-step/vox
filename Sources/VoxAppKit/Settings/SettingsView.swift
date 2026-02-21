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

    private var content: SettingsViewContent {
        SettingsViewContent.make(productInfo: productInfo, hotkeyAvailable: hotkeyAvailable)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.accentColor.opacity(0.16))

                    Image(systemName: "waveform")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.accentColor)

                    ZStack {
                        Circle()
                            .fill(Color(nsColor: .windowBackgroundColor))
                        Image(systemName: "mic.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .frame(width: 15, height: 15)
                    .offset(x: 3, y: 3)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(content.headerTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(content.headerSubtitle)
                        .font(.headline)
                    Text("Pick a microphone. Add cloud keys only if you want faster transcription and rewriting.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)
            .background(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.08),
                        Color.clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    BasicsSection(hotkeyAvailable: hotkeyAvailable, onRetryHotkey: onRetryHotkey)
                    CloudProvidersSection(onManageKeys: { showingCloudKeys = true })
                }
                .padding(20)
            }

            ProductStandardsFooter(productInfo: productInfo, versionText: content.versionText)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 560, minHeight: 420)
        .sheet(isPresented: $showingCloudKeys) {
            CloudKeysSheet()
                .frame(minWidth: 640, minHeight: 520)
        }
    }
}
