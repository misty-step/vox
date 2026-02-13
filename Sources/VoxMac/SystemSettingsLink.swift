import AppKit
import Foundation

public enum SystemSettingsLink {
    public static func openAccessibilityPrivacy() -> Bool {
        // Best-effort. URL scheme behavior can drift across macOS releases.
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }

    public static func openMicrophonePrivacy() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }
}
