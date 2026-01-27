import AppKit
import Combine
import Foundation
import os
import VoxCore
import VoxMac

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var hotkeyMonitor: HotkeyMonitor?
    private var sessionOrchestrator: SessionOrchestrator?
    private var pipelineAdapter: DictationPipelineAdapter?
    private var entitlementCache: FileEntitlementCache?
    private var hudController: HUDController?
    private var audioRecorder: AudioRecorder?
    private var levelTimer: DispatchSourceTimer?
    private var lastSessionState: SessionState = .idle
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

            let env = ProcessInfo.processInfo.environment
            seedGatewayTokenIfNeeded(env: env)
            let gatewayClient = try makeGatewayClient(env: env, useDefaultGateway: useDefaultGateway)

            // Deep module graph.
            let tokenStorage = KeychainTokenStorage()
            let tokenRefresher = GatewayTokenRefresher(client: gatewayClient)
            let tokenService = TokenServiceImpl(storage: tokenStorage, refresher: tokenRefresher)

            let entitlementChecker = GatewayEntitlementChecker(client: gatewayClient)
            let entitlementCache = FileEntitlementCache()
            let accessGate = AccessGateImpl(
                tokenService: tokenService,
                entitlementChecker: entitlementChecker,
                cache: entitlementCache
            )

            let permissionCoordinator = PermissionCoordinatorImpl(checker: SystemPermissionChecker())

            let audioRecorder = AudioRecorder()
            let recorder = AudioRecorderAdapter(recorder: audioRecorder)
            let pipelineAdapter = DictationPipelineAdapter(
                pipeline: pipeline,
                historyStore: historyStore,
                metadataConfig: metadataConfig,
                processingLevel: processingLevel
            )
            let paster = ClipboardPasterAdapter(
                paster: ClipboardPaster(
                    restoreDelay: PasteOptions.restoreDelay,
                    shouldRestore: PasteOptions.shouldRestore
                )
            )

            let orchestrator = SessionOrchestratorImpl(
                accessGate: accessGate,
                permissionCoordinator: permissionCoordinator,
                recorder: recorder,
                pipeline: pipelineAdapter,
                paster: paster
            )

            let statusBar = StatusBarController(
                onToggle: {
                    Task { await orchestrator.toggle() }
                },
                onProcessingLevelChange: { [weak self] level in
                    Task {
                        await pipelineAdapter.updateProcessingLevel(level)
                        await MainActor.run { self?.persistProcessingLevel(level) }
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

            Task { [weak self, weak statusBar, weak hud] in
                await orchestrator.setStateObserver { state in
                    Task { @MainActor [weak self, weak statusBar, weak hud] in
                        self?.handleSessionState(state, statusBar: statusBar, hud: hud)
                    }
                }
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
                Task { await orchestrator.toggle() }
            }

            statusBarController = statusBar
            sessionOrchestrator = orchestrator
            self.pipelineAdapter = pipelineAdapter
            self.entitlementCache = entitlementCache
            self.audioRecorder = audioRecorder
            hudController = hud

            PermissionManager.promptForAccessibilityIfNeeded()

            // Initial entitlement check (background)
            Task { await entitlementManager.refresh() }
        } catch {
            logger.error("Startup failed: \(String(describing: error))")
            showStartupError(String(describing: error))
        }
    }

    @MainActor
    func application(_ application: NSApplication, open urls: [URL]) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for url in urls {
            guard url.scheme == "vox" else { continue }

            // Handle auth deep links: vox://auth?token=...
            if url.host == "auth" || url.path == "/auth" {
                authManager.handleDeepLink(url: url)
                Task { await entitlementCache?.clear() }
            }

            // Handle payment success deep links: vox://payment-success
            if url.host == "payment-success" || url.path == "/payment-success" {
                Diagnostics.info("Payment success deep link received")
                Task {
                    await entitlementCache?.clear()
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

    @MainActor
    private func handleSessionState(
        _ state: SessionState,
        statusBar: StatusBarController?,
        hud: HUDController?
    ) {
        let previous = lastSessionState
        defer { lastSessionState = state }

        if case .recording = state {
            if case .recording = previous {
                // no-op
            } else {
                startLevelMetering()
                let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                Task { await pipelineAdapter?.captureTargetApplication(bundleId: bundleId) }
            }
        } else if case .recording = previous {
            stopLevelMetering()
        }

        statusBar?.update(state: legacyState(for: state))

        switch state {
        case .idle:
            hud?.show(state: .hidden)
        case .requestingPermissions:
            hud?.show(state: .processing)
        case .recording:
            hud?.show(state: .recording)
        case .processing:
            hud?.show(state: .processing)
        case .blocked(let reason):
            hud?.show(state: .hidden)
            handleBlocked(reason: reason, statusBar: statusBar, hud: hud)
        }
    }

    private func legacyState(for state: SessionState) -> SessionController.State {
        switch state {
        case .idle, .blocked:
            return .idle
        case .requestingPermissions:
            return .processing
        case .recording:
            return .recording
        case .processing:
            return .processing
        }
    }

    @MainActor
    private func handleBlocked(reason: BlockReason, statusBar: StatusBarController?, hud: HUDController?) {
        switch reason {
        case .notAuthenticated:
            statusBar?.showMessage("Sign in required")
            hud?.showMessage("Sign in required")
            PaywallWindowController.show(for: .unauthenticated)
        case .notEntitled:
            statusBar?.showMessage("Subscription required")
            hud?.showMessage("Subscription required")
            PaywallWindowController.show(for: .expired)
        case .permissionDenied:
            statusBar?.showMessage("Permissions required")
            hud?.showMessage("Permissions required")
        case .networkError(let message):
            statusBar?.showMessage("Network error")
            hud?.showMessage("Network error")
            PaywallWindowController.show(for: .error(message))
        }
    }

    private static let levelMeterInterval: TimeInterval = 0.05

    @MainActor
    private func startLevelMetering() {
        guard levelTimer == nil, audioRecorder != nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: Self.levelMeterInterval)
        timer.setEventHandler { [weak self] in
            guard let self, let recorder = self.audioRecorder else { return }
            let levels = recorder.currentLevel()
            self.hudController?.updateInputLevels(average: levels.average, peak: levels.peak)
        }
        timer.resume()
        levelTimer = timer
    }

    @MainActor
    private func stopLevelMetering() {
        levelTimer?.cancel()
        levelTimer = nil
    }

    private func makeGatewayClient(env: [String: String], useDefaultGateway: Bool) throws -> GatewayClient {
        let baseURL: URL
        if let rawURL = trimmed(env["VOX_GATEWAY_URL"]) {
            guard let url = URL(string: rawURL), url.scheme != nil else {
                throw VoxError.internalError("Invalid VOX_GATEWAY_URL: \(rawURL)")
            }
            baseURL = url
        } else if useDefaultGateway, let url = GatewayURL.api, url.scheme != nil {
            baseURL = url
        } else if let url = GatewayURL.api, url.scheme != nil {
            baseURL = url
        } else {
            throw VoxError.internalError("Gateway URL not configured.")
        }

        let envToken = trimmed(env["VOX_GATEWAY_TOKEN"])
        let tokenProvider: @Sendable () -> String? = {
            KeychainHelper.sessionToken ?? envToken
        }
        return GatewayClient(baseURL: baseURL, tokenProvider: tokenProvider)
    }

    private func seedGatewayTokenIfNeeded(env: [String: String]) {
        guard let envToken = trimmed(env["VOX_GATEWAY_TOKEN"]) else { return }
        guard KeychainHelper.sessionToken == nil else { return }
        KeychainHelper.saveSessionToken(envToken)
    }

    private func trimmed(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
