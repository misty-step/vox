import AppKit
import Combine
import VoxCore

public enum StatusBarState: Equatable {
    case idle(processingLevel: ProcessingLevel)
    case recording(processingLevel: ProcessingLevel)
    case processing(processingLevel: ProcessingLevel)

    var processingLevel: ProcessingLevel {
        switch self {
        case .idle(let level), .recording(let level), .processing(let level):
            return level
        }
    }

    func updatingProcessingLevel(_ level: ProcessingLevel) -> StatusBarState {
        switch self {
        case .idle:
            return .idle(processingLevel: level)
        case .recording:
            return .recording(processingLevel: level)
        case .processing:
            return .processing(processingLevel: level)
        }
    }
}

struct StatusBarMenuSnapshot: Equatable {
    let statusTitle: String
    let modeTitle: String
    let cloudTitle: String
    let cloudNeedsAction: Bool
    let toggleTitle: String
    let toggleEnabled: Bool

    static func make(state: StatusBarState, hasCloudSTT: Bool, hasRewrite: Bool) -> StatusBarMenuSnapshot {
        let statusTitle: String
        let toggleTitle: String
        let toggleEnabled: Bool

        switch state {
        case .idle:
            statusTitle = "Status: Ready"
            toggleTitle = "Start Dictation"
            toggleEnabled = true
        case .recording:
            statusTitle = "Status: Recording"
            toggleTitle = "Stop Dictation"
            toggleEnabled = true
        case .processing:
            statusTitle = "Status: Processing"
            toggleTitle = "Start Dictation"
            toggleEnabled = false
        }

        let cloudTitle: String
        switch (hasCloudSTT, hasRewrite) {
        case (true, true):
            cloudTitle = "Cloud services: Ready"
        case (true, false):
            cloudTitle = "Cloud STT ready; rewrite missing"
        case (false, true):
            cloudTitle = "Rewrite ready; transcription local"
        case (false, false):
            cloudTitle = "Cloud services: Not configured"
        }

        return StatusBarMenuSnapshot(
            statusTitle: statusTitle,
            modeTitle: "Mode: \(state.processingLevel.menuDisplayName)",
            cloudTitle: cloudTitle,
            cloudNeedsAction: !(hasCloudSTT && hasRewrite),
            toggleTitle: toggleTitle,
            toggleEnabled: toggleEnabled
        )
    }
}

private extension ProcessingLevel {
    var menuDisplayName: String {
        switch self {
        case .off:
            return "Off"
        case .light:
            return "Light"
        case .aggressive:
            return "Aggressive"
        case .enhance:
            return "Enhance"
        }
    }
}

@MainActor
public final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let onToggle: () -> Void
    private let onSettings: () -> Void
    private let onQuit: () -> Void
    private let prefs = PreferencesStore.shared

    private var prefsObserver: AnyCancellable?

    private var currentState: StatusBarState = .idle(processingLevel: .off)

    public init(onToggle: @escaping () -> Void, onSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onSettings = onSettings
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configure()
        updateIcon(for: currentState)
    }

    public func updateState(_ state: StatusBarState, processingLevel: ProcessingLevel? = nil) {
        let resolvedState = processingLevel.map { state.updatingProcessingLevel($0) } ?? state
        applyState(resolvedState)
    }

    public func updateProcessingLevel(_ level: ProcessingLevel) {
        applyState(currentState.updatingProcessingLevel(level))
    }

    private func applyState(_ state: StatusBarState) {
        let stateChanged = state != currentState
        currentState = state
        if stateChanged {
            updateIcon(for: state)
        }
        rebuildMenu()
    }

    private func configure() {
        rebuildMenu()
        observePreferences()
    }

    private func observePreferences() {
        prefsObserver = prefs.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handlePreferencesChange()
            }
    }

    private func handlePreferencesChange() {
        applyState(currentState.updatingProcessingLevel(prefs.processingLevel))
    }

    private func rebuildMenu() {
        let cloudReadiness = resolveCloudReadiness()
        let snapshot = StatusBarMenuSnapshot.make(
            state: currentState,
            hasCloudSTT: cloudReadiness.hasCloudSTT,
            hasRewrite: cloudReadiness.hasRewrite
        )

        let menu = NSMenu()

        menu.addItem(statusMenuItem(snapshot.statusTitle))
        menu.addItem(statusMenuItem(snapshot.modeTitle))

        let cloudItem = NSMenuItem(
            title: snapshot.cloudTitle,
            action: snapshot.cloudNeedsAction ? #selector(openSettings) : nil,
            keyEquivalent: ""
        )
        cloudItem.target = snapshot.cloudNeedsAction ? self : nil
        cloudItem.isEnabled = snapshot.cloudNeedsAction
        menu.addItem(cloudItem)
        menu.addItem(.separator())

        let toggleItem = NSMenuItem(title: snapshot.toggleTitle, action: #selector(toggleRecording), keyEquivalent: " ")
        toggleItem.keyEquivalentModifierMask = [.option]
        toggleItem.target = self
        toggleItem.isEnabled = snapshot.toggleEnabled
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        let processingItem = NSMenuItem(title: "Processing Level", action: nil, keyEquivalent: "")
        let processingMenu = NSMenu()
        let levels: [(String, ProcessingLevel)] = [
            ("Off", .off),
            ("Light", .light),
            ("Aggressive", .aggressive),
            ("Enhance", .enhance)
        ]
        for (title, level) in levels {
            let item = NSMenuItem(title: title, action: #selector(selectProcessingLevel(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = level
            item.state = level == prefs.processingLevel ? .on : .off
            processingMenu.addItem(item)
        }
        processingItem.submenu = processingMenu
        menu.addItem(processingItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Vox", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func statusMenuItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private struct CloudReadiness {
        let hasCloudSTT: Bool
        let hasRewrite: Bool
    }

    private func resolveCloudReadiness() -> CloudReadiness {
        CloudReadiness(
            hasCloudSTT: isConfigured(prefs.elevenLabsAPIKey) || isConfigured(prefs.deepgramAPIKey) || isConfigured(prefs.openAIAPIKey),
            hasRewrite: isConfigured(prefs.openRouterAPIKey)
        )
    }

    private func isConfigured(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func updateIcon(for state: StatusBarState) {
        guard let button = statusItem.button else { return }

        let scale = button.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let icon = StatusBarIconRenderer.makeIcon(for: state, scale: scale)
        button.image = icon
        button.imagePosition = .imageOnly

        switch state {
        case .idle(let level):
            button.toolTip = "Vox – Ready (\(level.menuDisplayName), ⌥Space to record)"
        case .recording:
            button.toolTip = "Vox – Recording..."
        case .processing:
            button.toolTip = "Vox – Processing..."
        }
    }

    @objc private func selectProcessingLevel(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? ProcessingLevel else { return }
        guard prefs.processingLevel != level else { return }
        prefs.processingLevel = level
        applyState(currentState.updatingProcessingLevel(level))
    }

    @objc private func toggleRecording() { onToggle() }
    @objc private func openSettings() { onSettings() }
    @objc private func quitApp() { onQuit() }
}
