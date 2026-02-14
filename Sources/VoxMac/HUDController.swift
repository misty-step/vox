import AppKit
import SwiftUI
import Combine
import VoxCore

@MainActor
public final class HUDController: HUDDisplaying {
    private let state = HUDState()
    private let panel: NSPanel
    private let announcer: any AccessibilityAnnouncing
    private let reducedMotion: Bool
    private var scheduledHide: DispatchWorkItem?
    private var announcementPolicy = HUDAnnouncementPolicy()
    private var hasInitialPosition = false
    private var cancellables = Set<AnyCancellable>()

    /// Extra space around the HUD content so the drop shadow isn't clipped by the panel edge.
    private static let shadowPadding: CGFloat = 24
    private static let positionKey = "HUDWindowPosition"
    private static let defaultTopOffset: CGFloat = 80

    public init() {
        reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let pad = Self.shadowPadding
        let content = HUDView(state: state)
            .environment(\.reducedMotion, reducedMotion)
            .padding(pad)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(
            x: 0,
            y: 0,
            width: HUDLayout.expandedWidth + pad * 2,
            height: HUDLayout.expandedHeight + pad * 2
        )

        panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting
        panel.isMovableByWindowBackground = true
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        announcer = VoiceOverAnnouncer(element: panel)
        hasInitialPosition = restorePosition()
        setupPositionPersistence()
    }

    // MARK: - Position Persistence

    private func setupPositionPersistence() {
        NotificationCenter.default.publisher(for: NSWindow.didMoveNotification, object: panel)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.savePosition()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.savePosition()
            }
            .store(in: &cancellables)
    }

    private func savePosition() {
        let origin = panel.frame.origin
        let positionData: [String: CGFloat] = ["x": origin.x, "y": origin.y]
        UserDefaults.standard.set(positionData, forKey: Self.positionKey)
    }

    @discardableResult
    private func restorePosition() -> Bool {
        if let data = UserDefaults.standard.dictionary(forKey: Self.positionKey) as? [String: CGFloat],
           let x = data["x"],
           let y = data["y"] {
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            return true
        }
        return positionTopCenter()
    }

    @discardableResult
    private func positionTopCenter() -> Bool {
        guard let screen = NSScreen.main else { return false }
        let size = panel.frame.size
        let x = screen.visibleFrame.midX - size.width / 2
        let y = screen.visibleFrame.maxY - size.height - Self.defaultTopOffset
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        return true
    }

    // MARK: - HUDDisplaying

    public func showRecording(average: Float, peak: Float) {
        state.startRecording()
        state.average = average
        state.peak = peak
        announceTransition(to: .recording)
        show()
    }

    public func updateLevels(average: Float, peak: Float) {
        guard state.mode == .recording else { return }
        state.average = average
        state.peak = peak
    }

    public func showProcessing(message: String) {
        state.startProcessing(message: message)
        announceTransition(to: .processing)
        show()
    }

    public func showSuccess() {
        scheduledHide?.cancel()
        state.startSuccess()
        announceTransition(to: .success)
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
        if let announcement = announcementPolicy.hideAnnouncement(for: state.mode) {
            announcer.announce(announcement)
        }
        animatedHide()
    }

    // MARK: - Private

    private func animatedHide() {
        guard state.isVisible else { return }
        state.dismiss(reducedMotion: reducedMotion) { [weak self] in
            self?.announcementPolicy.markIdle()
            self?.panel.orderOut(nil)
        }
    }

    private func show() {
        scheduledHide?.cancel()
        scheduledHide = nil
        ensureVisiblePosition()
        state.show()
        panel.orderFrontRegardless()
    }

    private func ensureVisiblePosition() {
        if !hasInitialPosition {
            hasInitialPosition = restorePosition()
            return
        }

        let frame = panel.frame
        let isVisibleOnAnyScreen = NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(frame)
        }
        if !isVisibleOnAnyScreen {
            _ = positionTopCenter()
        }
    }

    private func announceTransition(to mode: HUDMode) {
        if let announcement = announcementPolicy.transitionAnnouncement(for: mode) {
            announcer.announce(announcement)
        }
    }
}
