import AppKit
import Foundation
import VoxLocalMac

@MainActor
public final class VoxLocalSession: ObservableObject {
    public enum State {
        case idle
        case recording
        case processing
    }

    @Published public private(set) var state: State = .idle

    private let recorder = AudioRecorder()
    private let pipeline = DictationPipeline()
    private let hud = HUDController()
    private var levelTimer: Timer?

    public init() {}

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
        alert.messageText = "VoxLocal"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
