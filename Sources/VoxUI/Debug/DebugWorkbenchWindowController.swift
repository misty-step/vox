import AppKit
import SwiftUI

@MainActor
public final class DebugWorkbenchWindowController: NSWindowController {
    public init(store: DebugWorkbenchStore) {
        let view = DebugWorkbenchView(store: store)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Vox Debug Workbench"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 980, height: 700))
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("VoxDebugWorkbenchWindow")
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
