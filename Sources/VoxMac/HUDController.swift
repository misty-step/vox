import AppKit
import SwiftUI
import VoxCore

@MainActor
public final class HUDController: HUDDisplaying {
    private let state = HUDState()
    private let panel: NSPanel
    private let reducedMotion: Bool
    private var scheduledHide: DispatchWorkItem?

    public init() {
        reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let content = HUDView(state: state)
            .environment(\.reducedMotion, reducedMotion)
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

    public func showProcessing(message: String) {
        state.startProcessing(message: message)
        show()
    }

    public func showSuccess() {
        scheduledHide?.cancel()
        state.startSuccess()
        show()
        let task = DispatchWorkItem { [weak self] in
            self?.animatedHide()
        }
        scheduledHide = task
        DispatchQueue.main.asyncAfter(deadline: .now() + HUDTiming.successDisplayDuration, execute: task)
    }

    public func hide() {
        scheduledHide?.cancel()
        scheduledHide = nil
        animatedHide()
    }

    private func animatedHide() {
        guard state.isVisible else { return }
        state.dismiss(reducedMotion: reducedMotion) { [weak self] in
            self?.panel.orderOut(nil)
        }
    }

    private func show() {
        scheduledHide?.cancel()
        scheduledHide = nil
        positionPanel()
        state.show()
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
