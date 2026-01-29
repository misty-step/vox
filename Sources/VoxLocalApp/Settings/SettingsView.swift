import SwiftUI

public struct SettingsView: View {
    public init() {}

    public var body: some View {
        TabView {
            APIKeysTab()
                .tabItem { Text("API Keys") }
            ProcessingTab()
                .tabItem { Text("Processing") }
        }
        .frame(minWidth: 520, minHeight: 340)
        .padding(8)
    }
}
