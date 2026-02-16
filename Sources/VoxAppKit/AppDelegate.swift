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
        print("[Vox] Initial processing level: \(prefs.processingLevel.rawValue)")

        let diagnosticsContext = DiagnosticsContext.current(prefs: prefs)
        Task {
            await DiagnosticsStore.shared.record(
                name: "app_launch",
                fields: [
                    "app_version": .string(diagnosticsContext.appVersion),
                    "app_build": .string(diagnosticsContext.appBuild),
                    "os_version": .string(diagnosticsContext.osVersion),
                    "processing_level": .string(diagnosticsContext.processingLevel),
                    "stt_routing": .string(diagnosticsContext.sttRouting),
                    "streaming_allowed": .bool(diagnosticsContext.streamingAllowed),
                    "audio_backend": .string(diagnosticsContext.audioBackend),
                    "max_concurrent_stt": .int(diagnosticsContext.maxConcurrentSTT),
                    "keys_elevenlabs": .bool(diagnosticsContext.keysPresent.elevenLabs),
                    "keys_deepgram": .bool(diagnosticsContext.keysPresent.deepgram),
                    "keys_openai": .bool(diagnosticsContext.keysPresent.openAI),
                    "keys_gemini": .bool(diagnosticsContext.keysPresent.gemini),
                    "keys_openrouter": .bool(diagnosticsContext.keysPresent.openRouter),
                ]
            )
        }

        PermissionManager.promptForAccessibilityIfNeeded()

        let session = VoxSession(sessionExtension: OnboardingSessionExtension(onboarding: onboarding))
        self.session = session

        settingsWindowController = SettingsWindowController(
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

        attemptHotkeyRegistration(showErrorDialog: true)

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

    private func attemptHotkeyRegistration(showErrorDialog: Bool) {
        guard let session = session else { return }

        // Release old registration before re-registering to avoid deinit race
        hotkeyMonitor = nil

        let result = HotkeyMonitor.register(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey),
            handler: { Task { await session.toggleRecording() } }
        )

        let retryCallback: () -> Void = { [weak self] in self?.retryHotkeyRegistration() }

        switch result {
        case .success(let monitor):
            hotkeyMonitor = monitor
            statusBarController?.setHotkeyAvailable(true)
            settingsWindowController?.updateHotkeyAvailability(true, onRetry: retryCallback)
        case .failure(let error):
            statusBarController?.setHotkeyAvailable(false)
            settingsWindowController?.updateHotkeyAvailability(false, onRetry: retryCallback)
            if showErrorDialog {
                presentHotkeyError(error)
            }
        }
    }

    private func retryHotkeyRegistration() {
        attemptHotkeyRegistration(showErrorDialog: true)
    }

    private func presentHotkeyError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Hotkey Unavailable"
        alert.informativeText = """
            Option+Space could not be registered. \(error.localizedDescription)

            You can still start dictation by clicking "Start Dictation" in the Vox menu bar menu.
            """
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Break mutual recursion: dispatch retry to next run loop cycle
            DispatchQueue.main.async { [weak self] in
                self?.retryHotkeyRegistration()
            }
        case .alertSecondButtonReturn:
            showSettings()
        default:
            break
        }
    }
}
