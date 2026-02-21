import Foundation

// Snapshot-style struct for testable settings copy and metadata formatting.
struct SettingsViewContent {
    let headerTitle: String
    let headerSubtitle: String
    let versionText: String

    static func make(
        productInfo: ProductInfo,
        hotkeyAvailable: Bool
    ) -> SettingsViewContent {
        SettingsViewContent(
            headerTitle: "Vox",
            headerSubtitle: hotkeyAvailable
                ? "Press Option+Space to dictate."
                : "Use the menu bar icon to start dictation.",
            versionText: "Version \(productInfo.version) (\(productInfo.build))"
        )
    }
}
