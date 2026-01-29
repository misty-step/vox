import AppKit
import Carbon
import VoxMac

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var session: VoxSession?
    private var hotkeyMonitor: HotkeyMonitor?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let prefs = PreferencesStore.shared
        let hasElevenLabs = !prefs.elevenLabsAPIKey.isEmpty
        let hasOpenRouter = !prefs.openRouterAPIKey.isEmpty
        print("[Vox] ElevenLabs API key: \(hasElevenLabs ? "✓" : "✗ MISSING")")
        print("[Vox] OpenRouter API key: \(hasOpenRouter ? "✓" : "✗ MISSING")")
        print("[Vox] Model: \(prefs.selectedModel)")
        print("[Vox] Processing level: \(prefs.processingLevel.rawValue)")

        if !hasElevenLabs || !hasOpenRouter {
            print("[Vox] Tip: Set ELEVENLABS_API_KEY and OPENROUTER_API_KEY env vars, or use Settings to configure.")
        }

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
        session.onStateChange = { [weak statusBarController] state in
            let statusState: StatusBarState
            switch state {
            case .idle:
                statusState = .idle
            case .recording:
                statusState = .recording
            case .processing:
                statusState = .processing
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

    private func presentHotkeyError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Hotkey unavailable"
        alert.informativeText = "Option+Space could not be registered. \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.runModal()
    }
}
