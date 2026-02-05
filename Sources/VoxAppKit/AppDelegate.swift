import AppKit
import Carbon
import VoxCore
import VoxMac

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var session: VoxSession?
    private var hotkeyMonitor: HotkeyMonitor?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Clean up recovery audio older than 24 hours
        cleanupOldRecoveryFiles()

        let prefs = PreferencesStore.shared
        let hasElevenLabs = !prefs.elevenLabsAPIKey.isEmpty
        let hasOpenRouter = !prefs.openRouterAPIKey.isEmpty
        let hasDeepgram = !prefs.deepgramAPIKey.isEmpty
        let hasOpenAI = !prefs.openAIAPIKey.isEmpty
        print("[Vox] STT providers: ElevenLabs \(hasElevenLabs ? "✓" : "–") | Deepgram \(hasDeepgram ? "✓" : "–") | Whisper \(hasOpenAI ? "✓" : "–") | Apple Speech ✓")
        print("[Vox] Rewrite: OpenRouter \(hasOpenRouter ? "✓" : "–")")
        print("[Vox] Processing level: \(prefs.processingLevel.rawValue)")

        PermissionManager.promptForAccessibilityIfNeeded()

        let session = VoxSession()
        self.session = session

        settingsWindowController = SettingsWindowController()
        let statusBarController = StatusBarController(
            onToggle: { Task { await session.toggleRecording() } },
            onSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
        self.statusBarController = statusBarController
        statusBarController.updateState(.idle(processingLevel: prefs.processingLevel))
        session.onStateChange = { [weak statusBarController] state in
            let level = PreferencesStore.shared.processingLevel
            let statusState: StatusBarState
            switch state {
            case .idle:
                statusState = .idle(processingLevel: level)
            case .recording:
                statusState = .recording(processingLevel: level)
            case .processing:
                statusState = .processing(processingLevel: level)
            }
            statusBarController?.updateState(statusState)
        }

        do {
            hotkeyMonitor = try HotkeyMonitor(
                keyCode: UInt32(kVK_Space),
                modifiers: UInt32(optionKey),
                handler: { Task { await session.toggleRecording() } }
            )
        } catch {
            presentHotkeyError(error)
        }
    }

    private func showSettings() {
        settingsWindowController?.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func cleanupOldRecoveryFiles() {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let recoveryDir = support.appendingPathComponent("Vox/recovery")
        guard let files = try? fm.contentsOfDirectory(at: recoveryDir, includingPropertiesForKeys: [.creationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        for file in files {
            guard let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
                  let created = attrs.creationDate,
                  created < cutoff else { continue }
            SecureFileDeleter.delete(at: file)
            print("[Vox] Cleaned up old recovery file: \(file.lastPathComponent)")
        }
    }

    private func presentHotkeyError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Hotkey unavailable"
        alert.informativeText = "Option+Space could not be registered. \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.runModal()
    }
}
