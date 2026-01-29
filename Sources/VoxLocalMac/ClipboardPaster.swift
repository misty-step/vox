import AppKit
import Carbon
import Foundation
import VoxLocalCore

public final class ClipboardPaster {
    private let restoreDelay: TimeInterval
    private let shouldRestore: Bool

    public init(restoreDelay: TimeInterval = 60.0, shouldRestore: Bool = false) {
        self.restoreDelay = restoreDelay
        self.shouldRestore = shouldRestore
    }

    public func paste(text: String) throws {
        guard PermissionManager.isAccessibilityTrusted() else {
            throw VoxLocalError.permissionDenied("Accessibility permission required.")
        }
        try paste(text: text, restoreAfter: shouldRestore ? restoreDelay : nil)
    }

    public func paste(text: String, restoreAfter delay: TimeInterval?) throws {
        guard PermissionManager.isAccessibilityTrusted() else {
            throw VoxLocalError.permissionDenied("Accessibility permission required.")
        }
        copy(text: text, restoreAfter: delay)
        // Small delay to let clipboard update propagate before sending keystroke
        Thread.sleep(forTimeInterval: 0.05)
        sendPasteKeystroke()
    }

    public func copy(text: String, restoreAfter delay: TimeInterval?) {
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        print("[Paster] Clipboard set success: \(success)")
        print("[Paster] Clipboard now contains: \(pasteboard.string(forType: .string) ?? "nil")")

        guard let delay else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            print("[Paster] Restoring clipboard after \(delay)s")
            self.restorePasteboard(pasteboard, snapshot: snapshot)
        }
    }

    private func snapshotPasteboard(_ pb: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        guard let items = pb.pasteboardItems else { return [] }
        return items.map { item in
            var map: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { map[type] = data }
            }
            return map
        }
    }

    private func restorePasteboard(_ pb: NSPasteboard, snapshot: [[NSPasteboard.PasteboardType: Data]]) {
        pb.clearContents()
        let items: [NSPasteboardItem] = snapshot.map { entry in
            let item = NSPasteboardItem()
            for (type, data) in entry { item.setData(data, forType: type) }
            return item
        }
        pb.writeObjects(items)
    }

    private func sendPasteKeystroke() {
        // Log frontmost app
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            print("[Paster] Frontmost app: \(frontmost.localizedName ?? "unknown") (bundle: \(frontmost.bundleIdentifier ?? "none"))")
        } else {
            print("[Paster] WARNING: No frontmost application!")
        }

        print("[Paster] Sending Cmd+V keystroke...")
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand

        print("[Paster] keyDown event: \(keyDown != nil ? "created" : "FAILED")")
        print("[Paster] keyUp event: \(keyUp != nil ? "created" : "FAILED")")

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        print("[Paster] Keystroke posted to .cghidEventTap")
    }
}
