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
    private let prefs: PreferencesReading
    private let hud: HUDDisplaying
    private let sessionExtension: SessionExtension
    private let requestMicrophoneAccess: () async -> Bool
    private let errorPresenter: (String) -> Void
    private let pipeline: DictationProcessing?
    private var levelTimer: Timer?
    private var recordingStartTime: CFAbsoluteTime?

    public init(
        recorder: AudioRecording? = nil,
        pipeline: DictationProcessing? = nil,
        hud: HUDDisplaying? = nil,
        prefs: PreferencesReading? = nil,
        sessionExtension: SessionExtension? = nil,
        requestMicrophoneAccess: (() async -> Bool)? = nil,
        errorPresenter: ((String) -> Void)? = nil
    ) {
        self.recorder = recorder ?? AudioRecorder()
        self.pipeline = pipeline
        self.hud = hud ?? HUDController()
        self.prefs = prefs ?? PreferencesStore.shared
        self.sessionExtension = sessionExtension ?? NoopSessionExtension()
        self.requestMicrophoneAccess = requestMicrophoneAccess ?? {
            await PermissionManager.requestMicrophoneAccess()
        }
        self.errorPresenter = errorPresenter ?? { message in
            let alert = NSAlert()
            alert.messageText = "Vox"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func makePipeline() -> DictationProcessing {
        let openRouterKey = prefs.openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return DictationPipeline(
            stt: makeSTTProvider(),
            rewriter: OpenRouterClient(apiKey: openRouterKey),
            paster: ClipboardPaster(),
            prefs: prefs,
            enableRewriteCache: true
        )
    }

    private func makeSTTProvider() -> STTProvider {
        // Build chain bottom-up: last fallback first
        var chain: STTProvider = AppleSpeechClient()

        // Optional: Whisper (OpenAI)
        let openAIKey = prefs.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !openAIKey.isEmpty {
            let whisper = WhisperClient(apiKey: openAIKey)
            let timed = TimeoutSTTProvider(provider: whisper, baseTimeout: 30, secondsPerMB: 2)
            let retried = RetryingSTTProvider(provider: timed, maxRetries: 2, baseDelay: 0.5, name: "Whisper")
            chain = FallbackSTTProvider(primary: retried, fallback: chain, primaryName: "Whisper") { [weak self] in
                Task { @MainActor in self?.hud.showProcessing(message: "Switching to Apple Speech") }
            }
        }

        // Optional: Deepgram
        let deepgramKey = prefs.deepgramAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !deepgramKey.isEmpty {
            let deepgram = DeepgramClient(apiKey: deepgramKey)
            let timed = TimeoutSTTProvider(provider: deepgram, baseTimeout: 30, secondsPerMB: 2)
            let retried = RetryingSTTProvider(provider: timed, maxRetries: 2, baseDelay: 0.5, name: "Deepgram")
            chain = FallbackSTTProvider(primary: retried, fallback: chain, primaryName: "Deepgram") { [weak self] in
                let next = openAIKey.isEmpty ? "Apple Speech" : "Whisper"
                Task { @MainActor in self?.hud.showProcessing(message: "Switching to \(next)") }
            }
        }

        // Optional: ElevenLabs (primary if configured)
        let elevenKey = prefs.elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !elevenKey.isEmpty {
            let eleven = ElevenLabsClient(apiKey: elevenKey)
            let timed = TimeoutSTTProvider(provider: eleven, baseTimeout: 30, secondsPerMB: 2)
            let retried = RetryingSTTProvider(provider: timed, maxRetries: 3, baseDelay: 0.5, name: "ElevenLabs") { [weak self] attempt, maxRetries, delay in
                let delayStr = String(format: "%.1fs", delay)
                Task { @MainActor in
                    self?.hud.showProcessing(message: "Retrying \(attempt)/\(maxRetries) (\(delayStr))")
                }
            }
            chain = FallbackSTTProvider(primary: retried, fallback: chain, primaryName: "ElevenLabs") { [weak self] in
                let next: String
                if !deepgramKey.isEmpty {
                    next = "Deepgram"
                } else if !openAIKey.isEmpty {
                    next = "Whisper"
                } else {
                    next = "Apple Speech"
                }
                Task { @MainActor in self?.hud.showProcessing(message: "Switching to \(next)") }
            }
        }

        return ConcurrencyLimitedSTTProvider(
            provider: chain,
            maxConcurrent: maxConcurrentSTTRequests()
        )
    }

    private func maxConcurrentSTTRequests() -> Int {
        let defaultLimit = 8
        let raw = ProcessInfo.processInfo.environment["VOX_MAX_CONCURRENT_STT"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else {
            return defaultLimit
        }
        guard let parsed = Int(raw), parsed > 0 else {
            print("[Vox] Invalid VOX_MAX_CONCURRENT_STT=\(raw), using default \(defaultLimit)")
            return defaultLimit
        }
        return parsed
    }

    public func toggleRecording() async {
        switch state {
        case .idle: await startRecording()
        case .recording: await stopRecording()
        case .processing: break
        }
    }

    /// Moves the recorded audio to a recovery directory. Returns the destination path on success.
    @discardableResult
    private func preserveAudio(at url: URL) -> URL? {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("[Vox] Failed to preserve audio: no application support directory")
            return nil
        }
        let recoveryDir = support.appendingPathComponent("Vox/recovery")
        do {
            try fm.createDirectory(at: recoveryDir, withIntermediateDirectories: true)
            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let dest = recoveryDir.appendingPathComponent("\(timestamp)_\(url.lastPathComponent)")
            try fm.moveItem(at: url, to: dest)
            print("[Vox] Audio preserved to \(dest.path)")
            return dest
        } catch {
            print("[Vox] Failed to preserve audio: \(error.localizedDescription)")
            return nil
        }
    }

    private func startRecording() async {
        do {
            try await sessionExtension.authorizeRecordingStart()
        } catch {
            presentError(error.localizedDescription)
            return
        }

        let granted = await requestMicrophoneAccess()
        guard granted else {
            await sessionExtension.didFailDictation(reason: "microphone_permission_denied")
            presentError("Microphone permission is required.")
            return
        }

        if let uid = prefs.selectedInputDeviceUID,
           let deviceID = AudioDeviceManager.deviceID(forUID: uid) {
            AudioDeviceManager.setDefaultInputDevice(deviceID)
        }

        do {
            try recorder.start()
            recordingStartTime = CFAbsoluteTimeGetCurrent()
            state = .recording
            hud.showRecording(average: 0, peak: 0)
            startLevelTimer()
        } catch {
            await sessionExtension.didFailDictation(reason: "recording_start_failed")
            presentError(error.localizedDescription)
            state = .idle
        }
    }

    private func stopRecording() async {
        levelTimer?.invalidate()
        levelTimer = nil
        state = .processing
        hud.showProcessing()

        // Calculate recording duration
        let recordingDuration: TimeInterval
        if let startTime = recordingStartTime {
            recordingDuration = CFAbsoluteTimeGetCurrent() - startTime
            recordingStartTime = nil
            print("[Vox] Recording duration: \(String(format: "%.2f", recordingDuration))s")
        } else {
            recordingDuration = 0
        }

        let url: URL
        do {
            url = try recorder.stop()
        } catch {
            await sessionExtension.didFailDictation(reason: "recording_stop_failed")
            presentError(error.localizedDescription)
            state = .idle
            hud.hide()
            return
        }

        var succeeded = false
        do {
            let active = pipeline ?? makePipeline()
            let output = try await active.process(audioURL: url)
            await sessionExtension.didCompleteDictation(
                event: DictationUsageEvent(
                    recordingDuration: recordingDuration,
                    outputCharacterCount: output.count,
                    processingLevel: prefs.processingLevel
                )
            )
            succeeded = true
        } catch is CancellationError {
            print("[Vox] Processing cancelled")
            await sessionExtension.didFailDictation(reason: "processing_cancelled")
            SecureFileDeleter.delete(at: url)
        } catch {
            print("[Vox] Processing failed: \(error.localizedDescription)")
            await sessionExtension.didFailDictation(reason: "processing_failed")
            if let saved = preserveAudio(at: url) {
                presentError("\(error.localizedDescription)\n\nYour audio was saved to:\n\(saved.path)")
            } else {
                presentError(error.localizedDescription)
            }
        }

        if succeeded {
            SecureFileDeleter.delete(at: url)
            state = .idle
            hud.showSuccess()
        } else {
            state = .idle
            hud.hide()
        }
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
        errorPresenter(message)
    }
}
