import AppKit
import Carbon
import Foundation
import VoxCore

public final class ClipboardPaster {
    private let restoreDelay: TimeInterval
    private let shouldRestore: Bool

    public init(restoreDelay: TimeInterval = 0.25, shouldRestore: Bool = true) {
        self.restoreDelay = restoreDelay
        self.shouldRestore = shouldRestore
    }

    public func paste(text: String) throws {
        guard PermissionManager.isAccessibilityTrusted() else {
            throw VoxError.permissionDenied("Accessibility permission is required to paste.")
        }

        try paste(text: text, restoreAfter: shouldRestore ? restoreDelay : nil)
    }

    public func paste(text: String, restoreAfter delay: TimeInterval?) throws {
        guard PermissionManager.isAccessibilityTrusted() else {
            throw VoxError.permissionDenied("Accessibility permission is required to paste.")
        }

        copy(text: text, restoreAfter: delay)
        sendPasteKeystroke()
    }

    public func copy(text: String, restoreAfter delay: TimeInterval?) {
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard let delay else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.restorePasteboard(pasteboard, snapshot: snapshot)
        }
    }

    private func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            var map: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    map[type] = data
                }
            }
            return map
        }
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, snapshot: [[NSPasteboard.PasteboardType: Data]]) {
        pasteboard.clearContents()
        let items: [NSPasteboardItem] = snapshot.map { entry in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }

    private func sendPasteKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
