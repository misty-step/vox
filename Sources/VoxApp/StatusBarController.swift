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
        guard state != currentState else { return }
        currentState = state
        updateIcon(for: state)
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
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle Recording", action: #selector(toggleRecording), keyEquivalent: " ")
        toggleItem.keyEquivalentModifierMask = [.option]
        toggleItem.target = self
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

        let hasKeys = hasAPIKeysConfigured()
        let keyTitle = hasKeys ? "✓ API Keys Configured" : "✗ API Keys Missing"
        let keyStatusItem = NSMenuItem(
            title: keyTitle,
            action: hasKeys ? nil : #selector(openSettings),
            keyEquivalent: ""
        )
        keyStatusItem.target = hasKeys ? nil : self
        keyStatusItem.isEnabled = !hasKeys
        menu.addItem(keyStatusItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Vox", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func hasAPIKeysConfigured() -> Bool {
        let hasElevenLabs = !prefs.elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasOpenRouter = !prefs.openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasElevenLabs && hasOpenRouter
    }

    private func updateIcon(for state: StatusBarState) {
        guard let button = statusItem.button else { return }

        let icon = createVoxIcon(for: state)
        button.image = icon
        button.imagePosition = .imageOnly

        switch state {
        case .idle:
            button.toolTip = "Vox – Ready (⌥Space to record)"
        case .recording:
            button.toolTip = "Vox – Recording..."
        case .processing:
            button.toolTip = "Vox – Processing..."
        }
    }

    private func createVoxIcon(for state: StatusBarState) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let vPath = NSBezierPath()
            let inset: CGFloat = 2
            let top = rect.height - inset
            let bottom = inset + 2
            let left = inset + 1
            let right = rect.width - inset - 1
            let center = rect.width / 2
            let strokeWidth: CGFloat = 2.5

            vPath.move(to: NSPoint(x: left, y: top))
            vPath.line(to: NSPoint(x: center, y: bottom))
            vPath.line(to: NSPoint(x: right, y: top))

            vPath.lineWidth = strokeWidth
            vPath.lineCapStyle = .round
            vPath.lineJoinStyle = .round

            NSColor.black.setStroke()

            vPath.stroke()

            let badgeSize: CGFloat = 6
            let badgeRect = NSRect(
                x: rect.width - badgeSize - 1,
                y: rect.height - badgeSize - 1,
                width: badgeSize,
                height: badgeSize
            )

            switch state {
            case .recording:
                NSColor.black.setFill()
                NSBezierPath(ovalIn: badgeRect).fill()
            case .processing:
                let ringWidth: CGFloat = 1.5
                let ringRect = badgeRect.insetBy(dx: ringWidth / 2, dy: ringWidth / 2)
                let ringPath = NSBezierPath(ovalIn: ringRect)
                ringPath.lineWidth = ringWidth
                NSColor.black.setStroke()
                ringPath.stroke()
            case .idle:
                break
            }

            let dotCount: Int
            switch state.processingLevel {
            case .off:
                dotCount = 0
            case .light:
                dotCount = 1
            case .aggressive:
                dotCount = 2
            case .enhance:
                dotCount = 3
            }

            if dotCount > 0 {
                let dotSize: CGFloat = 2.5
                let dotSpacing: CGFloat = 2
                let totalWidth = CGFloat(dotCount) * dotSize + CGFloat(dotCount - 1) * dotSpacing
                let startX = (rect.width - totalWidth) / 2
                let dotY: CGFloat = 1
                NSColor.black.setFill()
                for index in 0..<dotCount {
                    let x = startX + CGFloat(index) * (dotSize + dotSpacing)
                    let dotRect = NSRect(x: x, y: dotY, width: dotSize, height: dotSize)
                    NSBezierPath(ovalIn: dotRect).fill()
                }
            }

            return true
        }

        image.isTemplate = true
        return image
    }

    @objc private func selectProcessingLevel(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? ProcessingLevel else { return }
        guard prefs.processingLevel != level else { return }
        prefs.processingLevel = level
        applyState(currentState.updatingProcessingLevel(level))
        rebuildMenu()
    }

    @objc private func toggleRecording() { onToggle() }
    @objc private func openSettings() { onSettings() }
    @objc private func quitApp() { onQuit() }
}
