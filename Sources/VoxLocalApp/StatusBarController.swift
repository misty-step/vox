import AppKit

public enum StatusBarState {
    case idle
    case recording
    case processing
}

@MainActor
public final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let onToggle: () -> Void
    private let onSettings: () -> Void
    private let onQuit: () -> Void

    private var currentState: StatusBarState = .idle

    public init(onToggle: @escaping () -> Void, onSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onSettings = onSettings
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configure()
        updateIcon(for: .idle)
    }

    public func updateState(_ state: StatusBarState) {
        guard state != currentState else { return }
        currentState = state
        updateIcon(for: state)
    }

    private func configure() {
        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Toggle Recording", action: #selector(toggleRecording), keyEquivalent: " ")
        toggleItem.keyEquivalentModifierMask = [.option]
        toggleItem.target = self

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self

        let quitItem = NSMenuItem(title: "Quit VoxLocal", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self

        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func updateIcon(for state: StatusBarState) {
        guard let button = statusItem.button else { return }

        let icon = createVoxIcon(for: state)
        button.image = icon
        button.imagePosition = .imageOnly

        switch state {
        case .idle:
            button.toolTip = "VoxLocal – Ready (⌥Space to record)"
        case .recording:
            button.toolTip = "VoxLocal – Recording..."
        case .processing:
            button.toolTip = "VoxLocal – Processing..."
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

            NSColor.labelColor.setStroke()

            vPath.stroke()

            if state == .recording || state == .processing {
                let badgeSize: CGFloat = 6
                let badgeRect = NSRect(
                    x: rect.width - badgeSize - 1,
                    y: rect.height - badgeSize - 1,
                    width: badgeSize,
                    height: badgeSize
                )
                if state == .recording {
                    NSColor.systemRed.setFill()
                } else {
                    NSColor.systemOrange.setFill()
                }
                NSBezierPath(ovalIn: badgeRect).fill()
            }

            return true
        }

        image.isTemplate = false
        return image
    }

    @objc private func toggleRecording() { onToggle() }
    @objc private func openSettings() { onSettings() }
    @objc private func quitApp() { onQuit() }
}
