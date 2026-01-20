import AppKit
import Foundation

public final class HUDController {
    public enum State {
        case hidden
        case recording
        case processing
    }

    private let panel: NSPanel
    private let view: HUDView
    private var currentState: State = .hidden
    private var messageWorkItem: DispatchWorkItem?
    private var isShowingMessage = false

    public init() {
        let size = NSSize(width: 220, height: 96)
        view = HUDView(frame: NSRect(origin: .zero, size: size))

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = view
    }

    public func show(state: State) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentState = state
            if self.isShowingMessage, state == .hidden {
                return
            }
            if self.isShowingMessage, state != .hidden {
                self.cancelMessage()
            }
            switch state {
            case .hidden:
                self.view.state = .hidden
                self.panel.orderOut(nil)
            case .recording:
                self.view.state = .recording
                self.showPanel()
            case .processing:
                self.view.state = .processing
                self.showPanel()
            }
        }
    }

    public func showMessage(_ text: String, duration: TimeInterval = 4.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isShowingMessage = true
            self.messageWorkItem?.cancel()
            self.view.showMessage(text, duration: duration)
            self.showPanel()

            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.isShowingMessage = false
                self.applyCurrentState()
            }
            self.messageWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
        }
    }

    public func updateInputLevels(average: Float, peak: Float) {
        DispatchQueue.main.async { [weak self] in
            self?.view.updateInputLevels(average: average, peak: peak)
        }
    }

    private func showPanel() {
        positionPanel()
        panel.orderFrontRegardless()
    }

    private func applyCurrentState() {
        show(state: currentState)
    }

    private func cancelMessage() {
        messageWorkItem?.cancel()
        messageWorkItem = nil
        isShowingMessage = false
    }

    private func positionPanel() {
        let screen = screenForMouse() ?? NSScreen.main
        guard let screen else { return }
        let frame = screen.visibleFrame
        let x = frame.midX - panel.frame.width / 2
        let y = frame.minY + 24
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func screenForMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
    }
}
