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

    @MainActor public func paste(text: String) async throws {
        try await paste(text: text, restoreAfter: shouldRestore ? restoreDelay : nil)
    }

    @MainActor public func paste(text: String, restoreAfter delay: TimeInterval?) async throws {
        // Copy first so text is on clipboard even if accessibility check fails.
        // Only snapshot when we plan to restore (delay != nil).
        let (pasteboard, snapshot, written) = copyToClipboard(text: text, captureSnapshot: delay != nil)

        guard PermissionManager.isAccessibilityTrusted() else {
            if written {
                throw VoxError.permissionDenied(
                    "Accessibility permission required for auto-paste.\n\n"
                    + "Your text has been copied to the clipboard — press ⌘V to paste it manually.\n\n"
                    + "To enable auto-paste: System Settings → Privacy & Security → Accessibility"
                )
            } else {
                throw VoxError.permissionDenied(
                    "Accessibility permission required."
                )
            }
        }

        // Yield main thread while clipboard update propagates
        try await Task.sleep(for: .milliseconds(50))
        sendPasteKeystroke()

        // Schedule clipboard restore only after successful paste
        scheduleRestore(on: pasteboard, snapshot: snapshot, after: delay)
    }

    public func copy(text: String, restoreAfter delay: TimeInterval?) {
        let (pasteboard, snapshot, _) = copyToClipboard(text: text, captureSnapshot: delay != nil)
        scheduleRestore(on: pasteboard, snapshot: snapshot, after: delay)
    }

    // MARK: - Clipboard helpers

    private func copyToClipboard(
        text: String,
        captureSnapshot: Bool
    ) -> (NSPasteboard, [[NSPasteboard.PasteboardType: Data]]?, Bool) {
        let pasteboard = NSPasteboard.general
        let snapshot = captureSnapshot ? snapshotPasteboard(pasteboard) : nil
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        #if DEBUG
        print("[Paster] Clipboard set: \(success)")
        #endif
        return (pasteboard, snapshot, success)
    }

    private func scheduleRestore(
        on pasteboard: NSPasteboard,
        snapshot: [[NSPasteboard.PasteboardType: Data]]?,
        after delay: TimeInterval?
    ) {
        guard let delay, let snapshot else { return }
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
