import SwiftUI

public struct SettingsView: View {
    private let productInfo: ProductInfo

    public init(productInfo: ProductInfo = .current()) {
        self.productInfo = productInfo
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vox Settings")
                    .font(.title3.weight(.semibold))
                Text("Configure providers, processing mode, and input routing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            TabView {
                APIKeysTab()
                    .tabItem { Label("API & Providers", systemImage: "key.horizontal.fill") }
                ProcessingTab()
                    .tabItem { Label("Dictation", systemImage: "waveform") }
            }
            .padding(.horizontal, 8)

            ProductStandardsFooter(productInfo: productInfo)
        }
        .frame(minWidth: 560, minHeight: 420)
        .padding(6)
    }
}
