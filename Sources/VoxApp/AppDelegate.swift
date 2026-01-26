import AppKit
import Combine
import Foundation
import os
import VoxCore
import VoxMac

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var hotkeyMonitor: HotkeyMonitor?
    private var sessionController: SessionController?
    private var hudController: HUDController?
    private var appConfig: AppConfig?
    private var configSource: ConfigLoader.Source?
    private var processingLevelOverride: ProcessingLevelOverride?
    private let authManager = AuthManager.shared
    private let entitlementManager = EntitlementManager.shared
    private var entitlementCancellable: AnyCancellable?
    private let logger = Logger(subsystem: "vox", category: "app")

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.info("Vox starting.")
        do {
            let loaded = try ConfigLoader.load()
            let config = loaded.config
            configSource = loaded.source
            processingLevelOverride = loaded.processingLevelOverride
            Diagnostics.info("Config source: \(loaded.source)")
            appConfig = config
            let useDefaultGateway = loaded.source == .defaults
            let sttProvider = try ProviderFactory.makeSTT(config: config.stt, useDefaultGateway: useDefaultGateway)
            let rewriteSelection = try RewriteConfigResolver.resolve(config.rewrite)
            let rewriteProvider = try ProviderFactory.makeRewrite(
                selection: rewriteSelection,
                useDefaultGateway: useDefaultGateway
            )

            let contextURL = URL(fileURLWithPath: config.contextPath ?? AppConfig.defaultContextPath)
            let locale = config.stt.languageCode ?? Locale.current.identifier
            let processingLevel = config.processingLevel ?? .light
            Diagnostics.info("Processing level: \(processingLevel.rawValue)")
            let historyStore = HistoryStore()
            let rewriteTemperature = rewriteSelection.temperature ?? 0.2
            let rewriteMaxTokens: Int? = {
                if rewriteSelection.id == "gemini" {
                    return GeminiModelPolicy.effectiveMaxOutputTokens(
                        requested: rewriteSelection.maxOutputTokens,
                        modelId: rewriteSelection.modelId
                    )
                }
                return rewriteSelection.maxOutputTokens
            }()
            let metadataConfig = SessionMetadataConfig(
                locale: locale,
                sttModelId: config.stt.modelId,
                rewriteModelId: rewriteSelection.modelId,
                maxOutputTokens: rewriteMaxTokens,
                temperature: rewriteTemperature,
                thinkingLevel: rewriteSelection.thinkingLevel,
                contextPath: contextURL.path
            )
            let pipeline = DictationPipeline(
                sttProvider: sttProvider,
                rewriteProvider: rewriteProvider,
                contextURL: contextURL,
                locale: locale,
                modelId: config.stt.modelId
            )
            let session = SessionController(
                pipeline: pipeline,
                processingLevel: processingLevel,
                historyStore: historyStore,
                metadataConfig: metadataConfig
            )

            let statusBar = StatusBarController(
                onToggle: {
                    Task { @MainActor in
                        session.toggle()
                    }
                },
                onProcessingLevelChange: { [weak self, weak session] level in
                    Task { @MainActor in
                        guard let session else { return }
                        session.updateProcessingLevel(level)
                        self?.persistProcessingLevel(level)
                    }
                },
                onProcessingLevelOverrideAttempt: { [weak self] in
                    self?.showProcessingLevelOverrideMessage()
                },
                onQuit: { NSApplication.shared.terminate(nil) },
                processingLevel: processingLevel,
                processingLevelOverride: processingLevelOverride
            )
            let hud = HUDController()

            session.stateDidChange = { [weak statusBar, weak hud] state in
                statusBar?.update(state: state)
                switch state {
                case .idle:
                    hud?.show(state: .hidden)
                case .recording:
                    hud?.show(state: .recording)
                case .processing:
                    hud?.show(state: .processing)
                }
            }
            session.statusDidChange = { [weak statusBar, weak hud] message in
                statusBar?.showMessage(message)
                hud?.showMessage(message)
            }
            session.inputLevelDidChange = { [weak hud] average, peak in
                hud?.updateInputLevels(average: average, peak: peak)
            }
            session.entitlementBlocked = { state in
                PaywallWindowController.show(for: state)
            }

            // Observe entitlement state changes for status bar badge
            entitlementCancellable = entitlementManager.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak statusBar] state in
                    statusBar?.updateEntitlementState(state)
                }

            let hotkey = config.hotkey ?? .default
            let modifiers = HotkeyParser.modifiers(from: hotkey.modifiers)
            hotkeyMonitor = try HotkeyMonitor(keyCode: hotkey.keyCode, modifiers: modifiers) {
                Task { @MainActor in
                    session.toggle()
                }
            }

            statusBarController = statusBar
            sessionController = session
            hudController = hud

            PermissionManager.promptForAccessibilityIfNeeded()
            Task { _ = await PermissionManager.requestMicrophoneAccess() }

            // Initial entitlement check (background)
            Task { await entitlementManager.refresh() }
        } catch {
            logger.error("Startup failed: \(String(describing: error))")
            showStartupError(String(describing: error))
        }
    }

    @MainActor
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "vox" else { continue }

            // Handle auth deep links: vox://auth?token=...
            if url.host == "auth" || url.path == "/auth" {
                authManager.handleDeepLink(url: url)
            }

            // Handle payment success deep links: vox://payment-success
            if url.host == "payment-success" || url.path == "/payment-success" {
                Diagnostics.info("Payment success deep link received")
                Task {
                    await entitlementManager.refresh()
                    if entitlementManager.isAllowed {
                        PaywallWindowController.hide()
                    }
                }
            }
        }
    }

    private func persistProcessingLevel(_ level: ProcessingLevel) {
        guard var config = appConfig else { return }
        config.processingLevel = level
        appConfig = config
        switch configSource {
        case .envLocal:
            ProcessingLevelStore.save(level)
            Diagnostics.info("Saved processing level to preferences.")
        case .file:
            do {
                try ConfigLoader.save(config)
            } catch {
                Diagnostics.error("Failed to save processing level: \(String(describing: error))")
                statusBarController?.showMessage("Failed to save processing level")
                hudController?.showMessage("Failed to save processing level")
            }
        case .defaults:
            ProcessingLevelStore.save(level)
            Diagnostics.info("Saved processing level to preferences.")
        case .none:
            break
        }
    }

    private func showStartupError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Vox failed to start"
        alert.informativeText = message
        alert.addButton(withTitle: "Quit")
        alert.runModal()
        NSApplication.shared.terminate(nil)
    }

    private func showProcessingLevelOverrideMessage() {
        guard let override = processingLevelOverride else { return }
        let message = "Processing locked by \(override.sourceKey). Edit .env.local to change."
        statusBarController?.showMessage(message)
        hudController?.showMessage(message)
    }
}
