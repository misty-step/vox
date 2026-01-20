import AppKit
import Foundation

enum Diagnostics {
    static var alertsEnabled: Bool {
        ProcessInfo.processInfo.environment["VOX_DEBUG_ALERTS"] == "1"
    }

    static func info(_ message: String) {
        print("[Vox] \(message)")
    }

    static func error(_ message: String) {
        print("[Vox][error] \(message)")
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
