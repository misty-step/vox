import AppKit
import Carbon
import VoxCore
import VoxMac

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var session: VoxSession?
    private var hotkeyMonitor: HotkeyMonitor?
    private let onboarding = OnboardingStore()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Clean up recovery audio older than 24 hours
        cleanupOldRecoveryFiles()

        let prefs = PreferencesStore.shared
        let hasElevenLabs = !prefs.elevenLabsAPIKey.isEmpty
        let hasOpenRouter = !prefs.openRouterAPIKey.isEmpty
        let hasDeepgram = !prefs.deepgramAPIKey.isEmpty
        let hasOpenAI = !prefs.openAIAPIKey.isEmpty
        print("[Vox] STT providers: ElevenLabs \(hasElevenLabs ? "✓" : "–") | Deepgram \(hasDeepgram ? "✓" : "–") | Whisper \(hasOpenAI ? "✓" : "–") | Apple Speech ✓")
        let hasGemini = !prefs.geminiAPIKey.isEmpty
        let rewriteChain = [
            hasGemini ? "Gemini" : nil,
            hasOpenRouter ? "OpenRouter" : nil,
        ].compactMap { $0 }.joined(separator: " → ")
        print("[Vox] Rewrite: \(rewriteChain.isEmpty ? "–" : rewriteChain)")
        print("[Vox] Processing level: \(prefs.processingLevel.rawValue)")

        PermissionManager.promptForAccessibilityIfNeeded()

        let session = VoxSession(sessionExtension: OnboardingSessionExtension(onboarding: onboarding))
        self.session = session

        settingsWindowController = SettingsWindowController(
            hotkeyAvailable: hotkeyMonitor != nil,
            onRetryHotkey: { [weak self] in self?.retryHotkeyRegistration() }
        )
        let statusBarController = StatusBarController(
            onToggle: { Task { await session.toggleRecording() } },
            onSetupChecklist: { [weak self] in self?.showOnboardingChecklist() },
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

        let registrationResult = HotkeyMonitor.register(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey),
            handler: { Task { await session.toggleRecording() } }
        )

        switch registrationResult {
        case .success(let monitor):
            hotkeyMonitor = monitor
            self.statusBarController?.setHotkeyAvailable(true)
        case .failure(let error):
            hotkeyMonitor = nil
            self.statusBarController?.setHotkeyAvailable(false)
            presentHotkeyError(error, canRetry: true)
        }

        showOnboardingChecklistIfNeeded()
    }

    private func showSettings() {
        settingsWindowController?.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func showOnboardingChecklist() {
        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController(
                onboarding: onboarding,
                onOpenSettings: { [weak self] in self?.showSettings() }
            )
        }
        onboardingWindowController?.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func showOnboardingChecklistIfNeeded() {
        guard onboarding.hasShownChecklist == false else { return }

        let needsAccessibility = !PermissionManager.isAccessibilityTrusted()
        let needsMicrophone = PermissionManager.microphoneAuthorizationStatus() != .authorized
        if needsAccessibility || needsMicrophone {
            showOnboardingChecklist()
        }
        onboarding.markChecklistShown()
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

    private func presentHotkeyError(_ error: Error, canRetry: Bool = false) {
        let alert = NSAlert()
        alert.messageText = "Hotkey Unavailable"
        alert.informativeText = "Option+Space could not be registered because another app is already using this shortcut.\n\nYou can still start dictation by clicking \"Start Dictation\" in the Vox menu bar menu."
        alert.alertStyle = .warning

        if canRetry {
            alert.addButton(withTitle: "Retry")
        }
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()

        if canRetry, response == .alertFirstButtonReturn {
            // Retry registration
            retryHotkeyRegistration()
        } else if (canRetry && response == .alertSecondButtonReturn) || (!canRetry && response == .alertFirstButtonReturn) {
            // Open Settings
            showSettings()
        }
    }

    private func retryHotkeyRegistration() {
        guard let session = session else { return }

        let registrationResult = HotkeyMonitor.register(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey),
            handler: { Task { await session.toggleRecording() } }
        )

        switch registrationResult {
        case .success(let monitor):
            hotkeyMonitor = monitor
            statusBarController?.setHotkeyAvailable(true)
            settingsWindowController?.updateHotkeyAvailability(true, onRetry: { [weak self] in self?.retryHotkeyRegistration() })
        case .failure(let error):
            hotkeyMonitor = nil
            statusBarController?.setHotkeyAvailable(false)
            settingsWindowController?.updateHotkeyAvailability(false, onRetry: { [weak self] in self?.retryHotkeyRegistration() })
            presentHotkeyError(error, canRetry: true)
        }
    }
}
