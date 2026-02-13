import AppKit
import SwiftUI
import Combine
import VoxCore

/// Represents preset positions for the HUD
public enum HUDPositionPreset: String, CaseIterable {
    case topCenter = "topCenter"
    case bottomCenter = "bottomCenter"
    case custom = "custom"
}

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

    private enum Constants {
        static let positionKey = "HUDWindowPosition"
        static let presetKey = "HUDPositionPreset"
        static let defaultTopOffset: CGFloat = 80
        static let defaultBottomOffset: CGFloat = 40
    }

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
        setupPositionPersistence()
        hasInitialPosition = restorePosition()
    }

    // MARK: - Position Management

    private func setupPositionPersistence() {
        NotificationCenter.default.publisher(for: NSWindow.didMoveNotification, object: panel)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.savePosition()
            }
            .store(in: &cancellables)
    }

    private func savePosition() {
        let frame = panel.frame
        let positionData: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        UserDefaults.standard.set(positionData, forKey: Constants.positionKey)
        UserDefaults.standard.set(HUDPositionPreset.custom.rawValue, forKey: Constants.presetKey)
    }

    @discardableResult
    private func restorePosition() -> Bool {
        if let presetRaw = UserDefaults.standard.string(forKey: Constants.presetKey),
           let preset = HUDPositionPreset(rawValue: presetRaw),
           preset != .custom {
            return applyPreset(preset)
        }

        if let positionData = UserDefaults.standard.dictionary(forKey: Constants.positionKey) as? [String: CGFloat],
           let x = positionData["x"],
           let y = positionData["y"] {
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            return true
        }

        return applyPreset(.topCenter)
    }

    @discardableResult
    public func applyPreset(_ preset: HUDPositionPreset) -> Bool {
        guard let screen = NSScreen.main else { return false }
        let size = panel.frame.size

        switch preset {
        case .topCenter:
            let x = screen.visibleFrame.midX - size.width / 2
            let y = screen.visibleFrame.maxY - size.height - Constants.defaultTopOffset
            panel.setFrameOrigin(NSPoint(x: x, y: y))

        case .bottomCenter:
            let x = screen.visibleFrame.midX - size.width / 2
            let y = screen.visibleFrame.minY + Constants.defaultBottomOffset
            panel.setFrameOrigin(NSPoint(x: x, y: y))

        case .custom:
            return restorePosition()
        }

        if preset != .custom {
            UserDefaults.standard.set(preset.rawValue, forKey: Constants.presetKey)
        }
        return true
    }

    public var currentPreset: HUDPositionPreset {
        if let presetRaw = UserDefaults.standard.string(forKey: Constants.presetKey),
           let preset = HUDPositionPreset(rawValue: presetRaw) {
            return preset
        }
        return .custom
    }

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
            _ = applyPreset(.topCenter)
        }
    }

    private func announceTransition(to mode: HUDMode) {
        if let announcement = announcementPolicy.transitionAnnouncement(for: mode) {
            announcer.announce(announcement)
        }
    }
}
