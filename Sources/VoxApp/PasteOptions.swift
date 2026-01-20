import Foundation

enum PasteOptions {
    static var restoreDelay: TimeInterval {
        let raw = ProcessInfo.processInfo.environment["VOX_PASTE_RESTORE_DELAY_MS"]
        if let raw, let ms = Double(raw) {
            return max(0, ms / 1000.0)
        }
        return 0.25
    }

    static var shouldRestore: Bool {
        let raw = ProcessInfo.processInfo.environment["VOX_PASTE_RESTORE"]
        if let raw {
            return raw != "0"
        }
        return true
    }

    static var clipboardHold: TimeInterval {
        let raw = ProcessInfo.processInfo.environment["VOX_CLIPBOARD_HOLD_MS"]
        if let raw, let ms = Double(raw) {
            return max(0, ms / 1000.0)
        }
        return 120.0
    }
}
