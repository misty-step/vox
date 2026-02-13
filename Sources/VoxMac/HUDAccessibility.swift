import AppKit
import Foundation

enum HUDAccessibility {
    static let label = "Vox Dictation"

    static func value(
        for mode: HUDMode,
        recordingDuration: TimeInterval,
        processingMessage: String
    ) -> String {
        switch mode {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording, \(formatDuration(recordingDuration))"
        case .processing:
            return "Processing"
        case .success:
            return "Done"
        }
    }

    static func stateAnnouncement(for mode: HUDMode) -> String? {
        switch mode {
        case .idle:
            return nil
        case .recording:
            return "Recording started."
        case .processing:
            return "Recording stopped. Processing dictation."
        case .success:
            return "Dictation complete."
        }
    }

    static func hideAnnouncement(for mode: HUDMode) -> String? {
        switch mode {
        case .recording, .processing:
            return "Dictation failed."
        case .idle, .success:
            return nil
        }
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let clamped = max(0, Int(duration.rounded(.down)))
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

@MainActor
protocol AccessibilityAnnouncing: AnyObject {
    func announce(_ message: String)
}

@MainActor
final class VoiceOverAnnouncer: AccessibilityAnnouncing {
    private let element: AnyObject

    init(element: AnyObject) {
        self.element = element
    }

    func announce(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        NSAccessibility.post(
            element: element,
            notification: .announcementRequested,
            userInfo: [
                .announcement: trimmed,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}

struct HUDAnnouncementPolicy {
    private var lastMode: HUDMode = .idle

    mutating func transitionAnnouncement(for mode: HUDMode) -> String? {
        guard mode != lastMode else { return nil }
        lastMode = mode
        return HUDAccessibility.stateAnnouncement(for: mode)
    }

    mutating func hideAnnouncement(for mode: HUDMode) -> String? {
        lastMode = .idle
        return HUDAccessibility.hideAnnouncement(for: mode)
    }

    mutating func markIdle() {
        lastMode = .idle
    }
}
