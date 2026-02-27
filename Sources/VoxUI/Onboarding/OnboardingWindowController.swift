import AppKit
import SwiftUI

@MainActor
public final class OnboardingWindowController: NSWindowController {
    public init(onboarding: OnboardingStore, onOpenSettings: @escaping () -> Void) {
        let view = OnboardingChecklistView(onboarding: onboarding, onOpenSettings: onOpenSettings)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Vox Setup"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 560))
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
