import AppKit
import Foundation
import VoxCore
import VoxMac
import VoxProviders

@MainActor
public final class VoxSession: ObservableObject {
    public enum State {
        case idle
        case recording
        case processing
    }

    public var onStateChange: ((State) -> Void)?

    @Published public private(set) var state: State = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    private let recorder: AudioRecording
    private let prefs: PreferencesStore
    private let hud: HUDDisplaying
    private let pipelineFactory: () -> DictationProcessing
    private let permissionRequest: () async -> Bool
    private let removeFile: (URL) -> Void
    private let validateKeys: () throws -> Void
    private var levelTimer: Timer?

    public convenience init(
        recorder: AudioRecording = AudioRecorder(),
        pipeline: DictationProcessing? = nil,
        hud: HUDDisplaying = HUDController(),
        prefs: PreferencesStore = .shared
    ) {
        self.init(
            recorder: recorder,
            pipeline: pipeline,
            hud: hud,
            prefs: prefs,
            permissionRequest: { await PermissionManager.requestMicrophoneAccess() },
            removeFile: { url in try? FileManager.default.removeItem(at: url) }
        )
    }

    init(
        recorder: AudioRecording,
        pipeline: DictationProcessing?,
        hud: HUDDisplaying,
        prefs: PreferencesStore,
        permissionRequest: @escaping () async -> Bool,
        removeFile: @escaping (URL) -> Void
    ) {
        self.recorder = recorder
        self.hud = hud
        self.prefs = prefs
        self.permissionRequest = permissionRequest
        self.removeFile = removeFile

        if let pipeline {
            self.pipelineFactory = { pipeline }
            self.validateKeys = {}
        } else {
            self.pipelineFactory = { Self.makeDefaultPipeline(prefs: prefs, hud: hud) }
            self.validateKeys = { try Self.validateKeys(prefs: prefs) }
        }
    }

    public func toggleRecording() async {
        switch state {
        case .idle: await startRecording()
        case .recording: await stopRecording()
        case .processing: break
        }
    }

    private func startRecording() async {
        let granted = await permissionRequest()
        guard granted else {
            presentError("Microphone permission is required.")
            return
        }

        do {
            try recorder.start()
            state = .recording
            hud.showRecording(average: 0, peak: 0)
            startLevelTimer()
        } catch {
            presentError(error.localizedDescription)
            state = .idle
        }
    }

    private func stopRecording() async {
        levelTimer?.invalidate()
        levelTimer = nil
        state = .processing
        hud.showProcessing()

        let url: URL
        do {
            url = try recorder.stop()
        } catch {
            presentError(error.localizedDescription)
            state = .idle
            hud.hide()
            return
        }

        do {
            try validateKeys()
            let pipeline = pipelineFactory()
            _ = try await pipeline.process(audioURL: url)
        } catch {
            presentError(error.localizedDescription)
        }

        removeFile(url)
        state = .idle
        hud.hide()
    }

    private func startLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let level = self.recorder.currentLevel()
                self.hud.updateLevels(average: level.average, peak: level.peak)
            }
        }
        RunLoop.main.add(levelTimer!, forMode: .common)
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Vox"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private static func validateKeys(prefs: PreferencesStore) throws {
        let elevenKey = prefs.elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !elevenKey.isEmpty else {
            throw VoxError.provider("ElevenLabs API key is missing.")
        }

        if prefs.processingLevel != .off {
            let openRouterKey = prefs.openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !openRouterKey.isEmpty else {
                throw VoxError.provider("OpenRouter API key is missing.")
            }
        }
    }

    private static func makeDefaultPipeline(
        prefs: PreferencesStore,
        hud: HUDDisplaying
    ) -> DictationPipeline {
        let elevenKey = prefs.elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let openRouterKey = prefs.openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return DictationPipeline(
            stt: makeSTTProvider(prefs: prefs, hud: hud, elevenKey: elevenKey),
            rewriter: OpenRouterClient(apiKey: openRouterKey),
            paster: ClipboardPaster(),
            prefs: prefs
        )
    }

    private static func makeSTTProvider(
        prefs: PreferencesStore,
        hud: HUDDisplaying,
        elevenKey: String
    ) -> STTProvider {
        let elevenLabs = ElevenLabsClient(apiKey: elevenKey)
        let retrying = RetryingSTTProvider(provider: elevenLabs) { attempt, maxRetries, delay in
            let delayStr = String(format: "%.1fs", delay)
            Task { @MainActor in
                hud.showProcessing(message: "Retrying \(attempt)/\(maxRetries) (\(delayStr))")
            }
        }

        let deepgramKey = prefs.deepgramAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !deepgramKey.isEmpty else { return retrying }

        let deepgram = DeepgramClient(apiKey: deepgramKey)
        return FallbackSTTProvider(primary: retrying, fallback: deepgram) {
            Task { @MainActor in
                hud.showProcessing(message: "Switching to Deepgram")
            }
        }
    }
}
