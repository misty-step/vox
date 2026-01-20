import AppKit
import Foundation

final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onToggle: () -> Void
    private let onQuit: () -> Void
    private var currentState: SessionController.State = .idle
    private var resetWorkItem: DispatchWorkItem?

    init(onToggle: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onQuit = onQuit
        super.init()

        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Toggle Recording", action: #selector(handleToggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Vox", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.title = "Vox"
    }

    func update(state: SessionController.State) {
        currentState = state
        switch state {
        case .idle:
            statusItem.button?.title = "Vox"
        case .recording:
            statusItem.button?.title = "● Vox"
        case .processing:
            statusItem.button?.title = "… Vox"
        }
    }

    func showMessage(_ message: String, duration: TimeInterval = 4.0) {
        resetWorkItem?.cancel()
        statusItem.button?.title = "Vox: \(message)"

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.update(state: self.currentState)
        }
        resetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    @objc private func handleToggle() {
        onToggle()
    }

    @objc private func handleQuit(_ sender: NSMenuItem) {
        onQuit()
    }
}
