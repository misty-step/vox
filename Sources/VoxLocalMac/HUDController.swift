import AppKit
import SwiftUI

public final class HUDController {
    private let state = HUDState()
    private let panel: NSPanel

    public init() {
        let content = HUDView(state: state)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 220, height: 110)

        panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting
        panel.isMovableByWindowBackground = true
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        positionPanel()
    }

    public func showRecording(average: Float, peak: Float) {
        state.startRecording()
        state.average = average
        state.peak = peak
        show()
    }

    public func updateLevels(average: Float, peak: Float) {
        guard state.mode == .recording else { return }
        state.average = average
        state.peak = peak
    }

    public func showProcessing() {
        state.startProcessing()
        show()
    }

    public func hide() {
        panel.orderOut(nil)
    }

    private func show() {
        positionPanel()
        panel.orderFrontRegardless()
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let size = panel.frame.size
        let x = screen.visibleFrame.midX - size.width / 2
        let y = screen.visibleFrame.maxY - size.height - 80
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
