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
                Text("Works out of the box. Option+Space to dictate. Add cloud keys only if you want a boost.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Form {
                BasicsSection()
                CloudBoostSection()
            }
            .padding(.horizontal, 8)

            ProductStandardsFooter(productInfo: productInfo)
        }
        .frame(minWidth: 560, minHeight: 420)
        .padding(6)
    }
}
