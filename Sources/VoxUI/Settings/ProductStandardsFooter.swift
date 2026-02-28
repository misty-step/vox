import SwiftUI
import VoxDiagnostics

struct ProductStandardsFooter: View {
    let productInfo: ProductInfo
    let versionText: String

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(versionText)  ·  \(productInfo.attribution)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Link("Contact / Help", destination: productInfo.supportURL)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
