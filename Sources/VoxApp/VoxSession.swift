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

    /// Creates pipeline with current API keys from preferences (trimmed)
    private func makePipeline() -> DictationPipeline {
        let elevenKey = prefs.elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let openRouterKey = prefs.openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return DictationPipeline(
            stt: ElevenLabsClient(apiKey: elevenKey),
            rewriter: OpenRouterClient(apiKey: openRouterKey),
            paster: ClipboardPaster(),
            prefs: prefs
        )
    }

    public func toggleRecording() async {
        switch state {
        case .idle: await startRecording()
        case .recording: await stopRecording()
        case .processing: break
        }
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

        do {
            // Validate required API keys before processing
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

            let pipeline = makePipeline()
            _ = try await pipeline.process(audioURL: url)
        } catch {
            presentError(error.localizedDescription)
        }

        try? FileManager.default.removeItem(at: url)
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
