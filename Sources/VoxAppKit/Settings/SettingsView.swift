import SwiftUI

public struct SettingsView: View {
    private let productInfo: ProductInfo

    public init(productInfo: ProductInfo = .current()) {
        self.productInfo = productInfo
    }

    public var body: some View {
        VStack(spacing: 0) {
            TabView {
                APIKeysTab()
                    .tabItem { Text("API Keys") }
                ProcessingTab()
                    .tabItem { Text("Processing") }
            }

            ProductStandardsFooter(productInfo: productInfo)
        }
        .frame(minWidth: 520, minHeight: 380)
        .padding(8)
    }
}
