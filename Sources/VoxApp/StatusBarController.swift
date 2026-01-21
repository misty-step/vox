import AppKit
import Foundation
import VoxCore

final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onToggle: () -> Void
    private let onProcessingLevelChange: (ProcessingLevel) -> Void
    private let onQuit: () -> Void
    private var currentState: SessionController.State = .idle
    private var resetWorkItem: DispatchWorkItem?
    private var processingLevel: ProcessingLevel
    private var processingItems: [ProcessingLevel: NSMenuItem] = [:]

    init(
        onToggle: @escaping () -> Void,
        onProcessingLevelChange: @escaping (ProcessingLevel) -> Void,
        onQuit: @escaping () -> Void,
        processingLevel: ProcessingLevel
    ) {
        self.onToggle = onToggle
        self.onProcessingLevelChange = onProcessingLevelChange
        self.onQuit = onQuit
        self.processingLevel = processingLevel
        super.init()

        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Toggle Recording", action: #selector(handleToggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let processingItem = NSMenuItem(title: "Processing", action: nil, keyEquivalent: "")
        let processingMenu = NSMenu()
        ProcessingLevel.allCases.forEach { level in
            let item = NSMenuItem(title: title(for: level), action: #selector(handleProcessingLevel(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = level
            processingMenu.addItem(item)
            processingItems[level] = item
        }
        processingItem.submenu = processingMenu
        menu.addItem(processingItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Vox", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.title = "Vox"
        updateProcessingMenu()
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
        setProcessingMenuEnabled(state == .idle)
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

    @objc private func handleProcessingLevel(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? ProcessingLevel else { return }
        processingLevel = level
        updateProcessingMenu()
        onProcessingLevelChange(level)
    }

    @objc private func handleQuit(_ sender: NSMenuItem) {
        onQuit()
    }

    private func updateProcessingMenu() {
        processingItems.forEach { level, item in
            item.state = level == processingLevel ? .on : .off
        }
    }

    private func setProcessingMenuEnabled(_ isEnabled: Bool) {
        processingItems.values.forEach { $0.isEnabled = isEnabled }
    }

    private func title(for level: ProcessingLevel) -> String {
        level.rawValue.capitalized
    }
}
