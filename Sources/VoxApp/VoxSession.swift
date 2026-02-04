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

    private let recorder = AudioRecorder()
    private let prefs = PreferencesStore.shared
    private let hud = HUDController()
    private var levelTimer: Timer?

    public init() {}

    private func makePipeline() -> DictationPipeline {
        let openRouterKey = prefs.openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return DictationPipeline(
            stt: makeSTTProvider(),
            rewriter: OpenRouterClient(apiKey: openRouterKey),
            paster: ClipboardPaster(),
            prefs: prefs
        )
    }

    private func makeSTTProvider() -> STTProvider {
        // Build chain bottom-up: last fallback first
        var chain: STTProvider = AppleSpeechClient()

        // Optional: Whisper (OpenAI)
        let openAIKey = prefs.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !openAIKey.isEmpty {
            let whisper = WhisperClient(apiKey: openAIKey)
            let timed = TimeoutSTTProvider(provider: whisper, timeout: 20)
            let retried = RetryingSTTProvider(provider: timed, maxRetries: 2, baseDelay: 0.5)
            chain = FallbackSTTProvider(primary: retried, fallback: chain) { [weak self] in
                Task { @MainActor in self?.hud.showProcessing(message: "Switching to Apple Speech") }
            }
        }

        // Optional: Deepgram
        let deepgramKey = prefs.deepgramAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !deepgramKey.isEmpty {
            let deepgram = DeepgramClient(apiKey: deepgramKey)
            let timed = TimeoutSTTProvider(provider: deepgram, timeout: 20)
            let retried = RetryingSTTProvider(provider: timed, maxRetries: 2, baseDelay: 0.5)
            chain = FallbackSTTProvider(primary: retried, fallback: chain) { [weak self] in
                let next = openAIKey.isEmpty ? "Apple Speech" : "Whisper"
                Task { @MainActor in self?.hud.showProcessing(message: "Switching to \(next)") }
            }
        }

        // Optional: ElevenLabs (primary if configured)
        let elevenKey = prefs.elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !elevenKey.isEmpty {
            let eleven = ElevenLabsClient(apiKey: elevenKey)
            let timed = TimeoutSTTProvider(provider: eleven, timeout: 15)
            let retried = RetryingSTTProvider(provider: timed, maxRetries: 3, baseDelay: 0.5) { [weak self] attempt, maxRetries, delay in
                let delayStr = String(format: "%.1fs", delay)
                Task { @MainActor in
                    self?.hud.showProcessing(message: "Retrying \(attempt)/\(maxRetries) (\(delayStr))")
                }
            }
            chain = FallbackSTTProvider(primary: retried, fallback: chain) { [weak self] in
                let next = deepgramKey.isEmpty ? (openAIKey.isEmpty ? "Apple Speech" : "Whisper") : "Deepgram"
                Task { @MainActor in self?.hud.showProcessing(message: "Switching to \(next)") }
            }
        }

        return chain
    }

    public func toggleRecording() async {
        switch state {
        case .idle: await startRecording()
        case .recording: await stopRecording()
        case .processing: break
        }
    }

    private func preserveAudio(at url: URL) {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let recoveryDir = support.appendingPathComponent("Vox/recovery")
        try? fm.createDirectory(at: recoveryDir, withIntermediateDirectories: true)
        let dest = recoveryDir.appendingPathComponent(url.lastPathComponent)
        try? fm.moveItem(at: url, to: dest)
        print("[Vox] Audio preserved to \(dest.path)")
    }

    private func startRecording() async {
        let granted = await PermissionManager.requestMicrophoneAccess()
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

        var succeeded = false
        do {
            let pipeline = makePipeline()
            _ = try await pipeline.process(audioURL: url)
            succeeded = true
        } catch {
            presentError(error.localizedDescription)
        }

        if succeeded {
            try? FileManager.default.removeItem(at: url)
        } else {
            preserveAudio(at: url)
        }
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
}
