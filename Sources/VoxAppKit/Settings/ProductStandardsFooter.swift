import SwiftUI

struct ProductStandardsFooter: View {
    let productInfo: ProductInfo

    private var versionText: String {
        "Version \(productInfo.version) (\(productInfo.build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(versionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(productInfo.attribution)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Link("Contact / Help", destination: productInfo.supportURL)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
