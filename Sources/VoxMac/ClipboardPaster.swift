import AppKit
import Carbon
import Foundation
import VoxCore

public final class ClipboardPaster: TextPaster {
    private let restoreDelay: TimeInterval
    private let shouldRestore: Bool

    public init(restoreDelay: TimeInterval = 60.0, shouldRestore: Bool = false) {
        self.restoreDelay = restoreDelay
        self.shouldRestore = shouldRestore
    }

    @MainActor public func paste(text: String) throws {
        guard PermissionManager.isAccessibilityTrusted() else {
            throw VoxError.permissionDenied("Accessibility permission required.")
        }
        try paste(text: text, restoreAfter: shouldRestore ? restoreDelay : nil)
    }

    public func paste(text: String, restoreAfter delay: TimeInterval?) throws {
        guard PermissionManager.isAccessibilityTrusted() else {
            throw VoxError.permissionDenied("Accessibility permission required.")
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
        #if DEBUG
        let success = pasteboard.setString(text, forType: .string)
        print("[Paster] Clipboard set: \(success)")
        #else
        pasteboard.setString(text, forType: .string)
        #endif

        guard let delay else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            #if DEBUG
            print("[Paster] Restoring clipboard after \(delay)s")
            #endif
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
        #if DEBUG
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            print("[Paster] Frontmost app: \(frontmost.localizedName ?? "unknown") (bundle: \(frontmost.bundleIdentifier ?? "none"))")
        } else {
            print("[Paster] WARNING: No frontmost application!")
        }
        #endif

        let script = NSAppleScript(source: """
            tell application "System Events"
                keystroke "v" using command down
            end tell
        """)
        if let script {
            var error: NSDictionary?
            _ = script.executeAndReturnError(&error)
            if let error {
                print("[Paster] AppleScript paste failed: \(error)")
                sendCGEventPaste()
            } else {
                #if DEBUG
                print("[Paster] AppleScript paste succeeded")
                #endif
            }
        } else {
            print("[Paster] AppleScript init failed, falling back to CGEvent")
            sendCGEventPaste()
        }
    }

    private func sendCGEventPaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        #if DEBUG
        print("[Paster] CGEvent Cmd+V posted")
        #endif
    }
}
