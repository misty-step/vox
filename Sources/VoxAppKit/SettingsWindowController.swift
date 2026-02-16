import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController: NSWindowController {

    public init(hotkeyAvailable: Bool = true, onRetryHotkey: (() -> Void)? = nil) {
        let view = SettingsView(hotkeyAvailable: hotkeyAvailable, onRetryHotkey: onRetryHotkey ?? {})
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Vox Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 480))
        window.center()
        super.init(window: window)
    }

    func updateHotkeyAvailability(_ available: Bool, onRetry: (() -> Void)? = nil) {
        if let hostingController = window?.contentViewController as? NSHostingController<SettingsView> {
            hostingController.rootView = SettingsView(
                hotkeyAvailable: available,
                onRetryHotkey: onRetry ?? {}
            )
        }
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
