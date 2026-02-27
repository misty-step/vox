import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController: NSWindowController {

    let hotkeyState: HotkeyState

    public init(hotkeyAvailable: Bool = true, onRetryHotkey: (() -> Void)? = nil) {
        let state = HotkeyState(isAvailable: hotkeyAvailable, onRetry: onRetryHotkey ?? {})
        let view = SettingsView(hotkeyState: state)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Vox Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 480))
        window.center()
        self.hotkeyState = state
        super.init(window: window)
    }

    public func updateHotkeyAvailability(_ available: Bool, onRetry: (() -> Void)? = nil) {
        hotkeyState.isAvailable = available
        if let retry = onRetry {
            hotkeyState.onRetry = retry
        }
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
