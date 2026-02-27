import Combine
import Foundation

/// Observable hotkey availability state shared across SettingsWindowController and SettingsView.
/// Mutating `isAvailable` propagates to SwiftUI without view recreation.
public final class HotkeyState: ObservableObject {
    @Published public var isAvailable: Bool
    public var onRetry: () -> Void

    public init(isAvailable: Bool = true, onRetry: @escaping () -> Void = {}) {
        self.isAvailable = isAvailable
        self.onRetry = onRetry
    }
}
