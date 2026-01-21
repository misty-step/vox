import AppKit
import Foundation

enum Diagnostics {
    enum LogLevel: Int {
        case debug = 0
        case info = 1
        case error = 2
        case off = 3
    }

    private static let currentLogLevel = logLevel(from: ProcessInfo.processInfo.environment)

    static var alertsEnabled: Bool {
        ProcessInfo.processInfo.environment["VOX_DEBUG_ALERTS"] == "1"
    }

    static func logLevel(from env: [String: String]) -> LogLevel {
        guard let raw = env["VOX_LOG_LEVEL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return .info
        }

        switch raw.lowercased() {
        case "debug":
            return .debug
        case "info":
            return .info
        case "error":
            return .error
        case "off":
            return .off
        default:
            return .info
        }
    }

    static func shouldLog(_ level: LogLevel, env: [String: String]) -> Bool {
        level.rawValue >= logLevel(from: env).rawValue
    }

    static func info(_ message: String) {
        guard shouldLog(.info) else { return }
        print("[Vox][\(timestamp())] \(message)")
    }

    static func debug(_ message: String) {
        guard shouldLog(.debug) else { return }
        print("[Vox][debug][\(timestamp())] \(message)")
    }

    static func error(_ message: String) {
        if shouldLog(.error) {
            print("[Vox][error][\(timestamp())] \(message)")
        }
        if alertsEnabled {
            showAlert(title: "Vox Error", message: message)
        }
    }

    private static func shouldLog(_ level: LogLevel) -> Bool {
        level.rawValue >= currentLogLevel.rawValue
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
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
