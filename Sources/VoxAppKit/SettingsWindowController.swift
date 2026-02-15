import AppKit
import SwiftUI

/// Observable state store for hotkey availability.
/// Used to update the Settings view without recreating the entire view hierarchy.
@MainActor
public final class HotkeyStateStore: ObservableObject {
    @Published public var isAvailable: Bool
    @Published public var onRetryHotkey: (() -> Void)?

    public init(isAvailable: Bool = true, onRetryHotkey: (() -> Void)? = nil) {
        self.isAvailable = isAvailable
        self.onRetryHotkey = onRetryHotkey
    }
}

@MainActor
public final class SettingsWindowController: NSWindowController {
    private let hotkeyStateStore: HotkeyStateStore

    public init(hotkeyAvailable: Bool = true, onRetryHotkey: (() -> Void)? = nil) {
        self.hotkeyStateStore = HotkeyStateStore(isAvailable: hotkeyAvailable, onRetryHotkey: onRetryHotkey)
        let view = SettingsView(hotkeyStateStore: hotkeyStateStore)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Vox Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 480))
        window.center()
        super.init(window: window)
    }

    func updateHotkeyAvailability(_ available: Bool, onRetry: (() -> Void)? = nil) {
        hotkeyStateStore.isAvailable = available
        hotkeyStateStore.onRetryHotkey = onRetry
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
