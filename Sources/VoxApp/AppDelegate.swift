import AppKit
import Combine
import Foundation
import os
import VoxCore
import VoxMac
import VoxProviders

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Deep modules
    private var auth: VoxAuth!
    private var gateway: VoxGateway?
    private var session: VoxSession!

    // UI
    private var statusBar: StatusBarController!
    private var hudController: HUDController!

    // Infra
    private var hotkeyMonitor: HotkeyMonitor?
    private var audioRecorder: AudioRecorder?
    private var processor: DictationProcessor?
    private var levelTimer: DispatchSourceTimer?
    private var lastSessionState: VoxSession.State = .idle
    private var cancellables = Set<AnyCancellable>()
    private var appConfig: AppConfig?
    private var configSource: ConfigLoader.Source?
    private var processingLevelOverride: ProcessingLevelOverride?
    private let logger = Logger(subsystem: "vox", category: "app")

    @MainActor
    static func currentAuth() -> VoxAuth? {
        (NSApp.delegate as? AppDelegate)?.auth
    }

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        SingleInstanceGuard.acquireOrExit()
        Diagnostics.info("Vox starting.")

        do {
            let loaded = try ConfigLoader.load()
            let config = loaded.config
            appConfig = config
            configSource = loaded.source
            processingLevelOverride = loaded.processingLevelOverride
            Diagnostics.info("Config source: \(loaded.source)")

            let useDefaultGateway = loaded.source == .defaults
            let gatewayBaseURL = try gatewayBaseURL(useDefaultGateway: useDefaultGateway)

            auth = VoxAuth(gateway: gatewayBaseURL.map(AppAuthGateway.init))
            if let token = trimmed(ProcessInfo.processInfo.environment["VOX_GATEWAY_TOKEN"]) {
                Task { await auth.seedTokenIfNeeded(token) }
            }

            if let gatewayBaseURL {
                gateway = VoxGateway(baseURL: gatewayBaseURL, auth: auth)
            } else {
                gateway = nil
                Diagnostics.info("Gateway disabled. Running in local mode.")
            }

            let contextURL = URL(fileURLWithPath: config.contextPath ?? AppConfig.defaultContextPath)
            let locale = config.stt.languageCode ?? Locale.current.identifier
            let initialLevel = config.processingLevel ?? .light
            Diagnostics.info("Processing level: \(initialLevel.rawValue)")

            let providers = try makeProviders(config: config, gateway: gateway)
            let processor = DictationProcessor(
                stt: providers.stt,
                rewrite: providers.rewrite,
                contextURL: contextURL,
                locale: locale,
                sttModelId: config.stt.modelId,
                level: initialLevel
            )
            self.processor = processor

            let permissionCoordinator = PermissionCoordinatorImpl(checker: SystemPermissionChecker())
            let audioRecorder = AudioRecorder()
            let recorder = AudioRecorderSessionAdapter(recorder: audioRecorder)
            let paster = ClipboardPasterSessionAdapter(
                paster: ClipboardPaster(
                    restoreDelay: PasteOptions.restoreDelay,
                    shouldRestore: PasteOptions.shouldRestore
                )
            )

            session = VoxSession(
                auth: auth,
                permissionCoordinator: permissionCoordinator,
                recorder: recorder,
                processor: processor,
                paster: paster
            )

            statusBar = StatusBarController(
                onToggle: { [weak self] in
                    self?.session.toggle()
                },
                onProcessingLevelChange: { [weak self] level in
                    guard let self else { return }
                    Task {
                        await processor.updateProcessingLevel(level)
                        await MainActor.run { self.persistProcessingLevel(level) }
                    }
                },
                onProcessingLevelOverrideAttempt: { [weak self] in
                    self?.showProcessingLevelOverrideMessage()
                },
                onQuit: { NSApplication.shared.terminate(nil) },
                processingLevel: initialLevel,
                processingLevelOverride: processingLevelOverride
            )
            hudController = HUDController()
            self.audioRecorder = audioRecorder

            observeSessionState()
            observeAuthState()

            let hotkey = config.hotkey ?? .default
            let modifiers = HotkeyParser.modifiers(from: hotkey.modifiers)
            hotkeyMonitor = try HotkeyMonitor(keyCode: hotkey.keyCode, modifiers: modifiers) { [weak self] in
                self?.session.toggle()
            }

            PermissionManager.promptForAccessibilityIfNeeded()
            Task { await auth.check() }
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
            if url.host == "auth" || url.path == "/auth" {
                auth.handleDeepLink(url)
                continue
            }
            if url.host == "payment-success" || url.path == "/payment-success" {
                Diagnostics.info("Payment success deep link received.")
                Task {
                    await auth.refresh(force: true)
                    if auth.isAllowed {
                        await MainActor.run { PaywallWindowController.hide() }
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
                statusBar.showMessage("Failed to save processing level")
                hudController.showMessage("Failed to save processing level")
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
        statusBar?.showMessage(message)
        hudController?.showMessage(message)
    }

    @MainActor
    private func handleSessionState(_ state: VoxSession.State) {
        let previous = lastSessionState
        defer { lastSessionState = state }

        if case .recording = state, previous != .recording {
            startLevelMetering()
        } else if case .recording = previous {
            stopLevelMetering()
        }

        statusBar.update(state: sessionState(for: state))

        switch state {
        case .idle:
            hudController.show(state: .hidden)
        case .recording:
            hudController.show(state: .recording)
        case .processing:
            hudController.show(state: .processing)
        case .blocked(let reason):
            hudController.show(state: .hidden)
            handleBlocked(reason: reason)
        }
    }

    private func sessionState(for state: VoxSession.State) -> SessionController.State {
        switch state {
        case .idle, .blocked:
            return .idle
        case .recording:
            return .recording
        case .processing:
            return .processing
        }
    }

    @MainActor
    private func handleBlocked(reason: String) {
        let message = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        statusBar.showMessage(message)
        hudController.showMessage(message)

        let paywallState: EntitlementState?
        switch auth.state {
        case .needsAuth:
            paywallState = .unauthenticated
        case .needsSubscription:
            paywallState = .expired
        case .error(let errorMessage):
            paywallState = .error(errorMessage)
        default:
            paywallState = nil
        }

        if let paywallState {
            PaywallWindowController.show(for: paywallState)
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

    @MainActor
    private func observeSessionState() {
        session.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleSessionState(state)
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func observeAuthState() {
        auth.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let entitlementState = self.entitlementState(for: state)
                    self.statusBar.updateEntitlementState(entitlementState)
                    if entitlementState == .entitled {
                        PaywallWindowController.hide()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func entitlementState(for state: VoxAuth.State) -> EntitlementState {
        switch state {
        case .allowed:
            return .entitled
        case .needsAuth:
            return .unauthenticated
        case .needsSubscription:
            return .expired
        case .error(let message):
            return .error(message)
        case .unknown, .checking:
            return .unknown
        }
    }

    private func gatewayBaseURL(useDefaultGateway: Bool) throws -> URL? {
        let env = ProcessInfo.processInfo.environment
        if let rawURL = trimmed(env["VOX_GATEWAY_URL"]) {
            guard let url = URL(string: rawURL), url.scheme != nil else {
                throw VoxError.internalError("Invalid VOX_GATEWAY_URL: \(rawURL)")
            }
            return url
        }
        guard useDefaultGateway else { return nil }
        return GatewayURL.api
    }

    private func makeProviders(
        config: AppConfig,
        gateway: VoxGateway?
    ) throws -> (stt: STTProvider, rewrite: RewriteProvider?) {
        if let gateway {
            Diagnostics.info("Gateway enabled.")
            return (
                stt: VoxGatewaySTTProvider(gateway: gateway),
                rewrite: VoxGatewayRewriteProvider(gateway: gateway)
            )
        }

        let sttProvider = ElevenLabsSTTProvider(
            config: ElevenLabsSTTConfig(
                apiKey: config.stt.apiKey,
                modelId: config.stt.modelId,
                languageCode: config.stt.languageCode,
                fileFormat: config.stt.fileFormat,
                enableLogging: nil
            )
        )

        let rewriteSelection = try RewriteConfigResolver.resolve(config.rewrite)
        let temperature = rewriteSelection.temperature ?? 0.2
        let rewriteProvider: RewriteProvider?
        switch rewriteSelection.id {
        case "gemini":
            let maxTokens = GeminiModelPolicy.effectiveMaxOutputTokens(
                requested: rewriteSelection.maxOutputTokens,
                modelId: rewriteSelection.modelId
            )
            rewriteProvider = GeminiRewriteProvider(
                config: GeminiConfig(
                    apiKey: rewriteSelection.apiKey,
                    modelId: rewriteSelection.modelId,
                    temperature: temperature,
                    maxOutputTokens: maxTokens,
                    thinkingLevel: rewriteSelection.thinkingLevel
                )
            )
        case "openrouter":
            rewriteProvider = OpenRouterRewriteProvider(
                config: OpenRouterConfig(
                    apiKey: rewriteSelection.apiKey,
                    modelId: rewriteSelection.modelId,
                    temperature: temperature,
                    maxOutputTokens: rewriteSelection.maxOutputTokens
                )
            )
        default:
            rewriteProvider = nil
        }

        return (sttProvider, rewriteProvider)
    }

    private func trimmed(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

// MARK: - Deep Module Adapters

private struct AppAuthGateway: VoxAuthGateway {
    let baseURL: URL

    func getEntitlements(token: String) async throws -> EntitlementResponse {
        let client = GatewayClient(baseURL: baseURL, token: token)
        return try await client.getEntitlements()
    }
}

private struct VoxGatewaySTTProvider: STTProvider, @unchecked Sendable {
    let id = "vox-gateway-stt"
    private let gateway: VoxGateway

    init(gateway: VoxGateway) {
        self.gateway = gateway
    }

    func transcribe(_ request: TranscriptionRequest) async throws -> Transcript {
        let audio = try Data(contentsOf: request.audioFileURL)
        let text = try await gateway.transcribe(audio)
        return Transcript(sessionId: request.sessionId, text: text, language: request.locale)
    }
}

private struct VoxGatewayRewriteProvider: RewriteProvider, @unchecked Sendable {
    let id = "vox-gateway-rewrite"
    private let gateway: VoxGateway

    init(gateway: VoxGateway) {
        self.gateway = gateway
    }

    func rewrite(_ request: RewriteRequest) async throws -> RewriteResponse {
        let text = try await gateway.rewrite(request.transcript.text, level: request.processingLevel)
        return RewriteResponse(finalText: text)
    }
}

/// Adapter wrapping `AudioRecorder` for `SessionRecorder`.
private final class AudioRecorderSessionAdapter: SessionRecorder, @unchecked Sendable {
    private let recorder: AudioRecorder

    init(recorder: AudioRecorder) {
        self.recorder = recorder
    }

    func start() async throws {
        try recorder.start()
    }

    func stop() async throws -> Data {
        let url = try recorder.stop()
        defer {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                Diagnostics.warning("Failed to remove temp audio: \(String(describing: error))")
            }
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            Diagnostics.error("Failed to read recorded audio: \(String(describing: error))")
            throw error
        }
    }
}

/// Adapter wrapping `ClipboardPaster` for `SessionPaster`.
private final class ClipboardPasterSessionAdapter: SessionPaster, @unchecked Sendable {
    private let paster: ClipboardPaster

    init(paster: ClipboardPaster) {
        self.paster = paster
    }

    func paste(_ text: String) async throws {
        try paster.paste(text: text)
    }
}

/// Session processor that hides provider details and quality gates.
private actor DictationProcessor: VoxSessionProcessing {
    private let stt: STTProvider
    private let rewrite: RewriteProvider?
    private let contextURL: URL
    private let locale: String
    private let sttModelId: String?
    private var level: ProcessingLevel

    init(
        stt: STTProvider,
        rewrite: RewriteProvider?,
        contextURL: URL,
        locale: String,
        sttModelId: String?,
        level: ProcessingLevel
    ) {
        self.stt = stt
        self.rewrite = rewrite
        self.contextURL = contextURL
        self.locale = locale
        self.sttModelId = sttModelId
        self.level = level
    }

    var processingLevel: ProcessingLevel { level }

    func updateProcessingLevel(_ newLevel: ProcessingLevel) {
        level = newLevel
    }

    func transcribe(audio: Data) async throws -> String {
        let sessionId = UUID()
        let audioURL = try writeTemporaryAudio(audio, sessionId: sessionId)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let request = TranscriptionRequest(
            sessionId: sessionId,
            audioFileURL: audioURL,
            locale: locale,
            modelId: sttModelId
        )
        let transcript = try await stt.transcribe(request)
        return transcript.text
    }

    func rewrite(_ transcript: String) async throws -> String {
        guard level != .off else { return transcript }
        guard let rewrite else { return transcript }

        let context = (try? String(contentsOf: contextURL)) ?? ""
        let sessionId = UUID()
        let request = RewriteRequest(
            sessionId: sessionId,
            locale: locale,
            transcript: TranscriptPayload(text: transcript),
            context: context,
            processingLevel: level
        )

        let response = try await rewrite.rewrite(request)
        let candidate = response.finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return transcript }

        let evaluation = RewriteQualityGate.evaluate(
            raw: transcript,
            candidate: candidate,
            level: level
        )
        return evaluation.isAcceptable ? candidate : transcript
    }

    private func writeTemporaryAudio(_ audio: Data, sessionId: UUID) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vox-\(sessionId.uuidString).caf")
        do {
            try audio.write(to: url, options: .atomic)
            return url
        } catch {
            Diagnostics.error("Failed to write temp audio: \(String(describing: error))")
            throw error
        }
    }
}

// MARK: - Legacy UI Types

enum SessionController {
    enum State {
        case idle
        case recording
        case processing
    }
}

enum EntitlementState: Equatable {
    case unknown
    case entitled
    case gracePeriod
    case expired
    case unauthenticated
    case error(String)
}
