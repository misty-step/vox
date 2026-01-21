import AppKit
import Foundation

enum Diagnostics {
    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static var alertsEnabled: Bool {
        ProcessInfo.processInfo.environment["VOX_DEBUG_ALERTS"] == "1"
    }

    static func info(_ message: String) {
        print("[Vox][\(timestampFormatter.string(from: Date()))] \(message)")
    }

    static func error(_ message: String) {
        print("[Vox][error][\(timestampFormatter.string(from: Date()))] \(message)")
        if alertsEnabled {
            showAlert(title: "Vox Error", message: message)
        }
    }

    static func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
