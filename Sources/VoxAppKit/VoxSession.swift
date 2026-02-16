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
    private let streamingSTTProvider: StreamingSTTProvider?
    private var streamingSetupTask: Task<Void, Never>?
    private let streamingSetupTimeout: TimeInterval
    private var levelTimer: Timer?
    private var recordingStartTime: CFAbsoluteTime?
    private var activeStreamingBridge: StreamingAudioBridge?

    public init(
        recorder: AudioRecording? = nil,
        pipeline: DictationProcessing? = nil,
        hud: HUDDisplaying? = nil,
        prefs: PreferencesReading? = nil,
        sessionExtension: SessionExtension? = nil,
        requestMicrophoneAccess: (() async -> Bool)? = nil,
        errorPresenter: ((String) -> Void)? = nil,
        streamingSTTProvider: StreamingSTTProvider? = nil,
        streamingSetupTimeout: TimeInterval = 3.0
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
        self.streamingSTTProvider = streamingSTTProvider
        self.streamingSetupTimeout = streamingSetupTimeout
    }

    private var hasCloudProviders: Bool {
        let keys = [
            prefs.elevenLabsAPIKey,
            prefs.deepgramAPIKey,
            prefs.openAIAPIKey,
        ]
        return keys.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func makePipeline() -> DictationProcessing {
        makePipeline(dictationID: UUID().uuidString)
    }

    private func makePipeline(dictationID: String) -> DictationProcessing {
        DictationPipeline(
            stt: makeSTTProvider(),
            rewriter: makeRewriteProvider(),
            paster: ClipboardPaster(),
            prefs: prefs,
            rewriteCache: .shared,
            enableRewriteCache: true,
            enableOpus: hasCloudProviders,
            timingHandler: { timing in
                Task {
                    await DiagnosticsStore.shared.record(
                        name: "pipeline_timing",
                        sessionID: dictationID,
                        fields: [
                            "total_ms": .int(Int(timing.totalTime * 1000)),
                            "encode_ms": .int(Int(timing.encodeTime * 1000)),
                            "stt_ms": .int(Int(timing.sttTime * 1000)),
                            "rewrite_ms": .int(Int(timing.rewriteTime * 1000)),
                            "paste_ms": .int(Int(timing.pasteTime * 1000)),
                            "original_bytes": .int(timing.originalSizeBytes),
                            "encoded_bytes": .int(timing.encodedSizeBytes),
                        ]
                    )
                }
            }
        )
    }

    private func makeRewriteProvider() -> RewriteProvider {
        let geminiKey = prefs.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let openRouterKey = prefs.openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let gemini: GeminiClient? = geminiKey.isEmpty ? nil : GeminiClient(apiKey: geminiKey)

        // OpenRouter supports non-Google polish models (e.g. "x-ai/grok-4.1-fast") and also acts as a
        // resilient fallback when direct Gemini is unavailable.
        let openRouter: OpenRouterClient? = openRouterKey.isEmpty ? nil : OpenRouterClient(
            apiKey: openRouterKey,
            fallbackModels: [
                // Keep the chain cheap and fast; polish defaults can still be premium via primary model id.
                "google/gemini-2.5-flash",
                "google/gemini-2.0-flash-001",
            ]
        )

        guard gemini != nil || openRouter != nil else {
            // No keys — return a bare OpenRouter client (will fail on auth)
            print("[Vox] Warning: No rewrite API keys configured (GEMINI_API_KEY or OPENROUTER_API_KEY). Rewriting will fail.")
            return OpenRouterClient(apiKey: openRouterKey)
        }

        if let gemini, let openRouter {
            return ModelRoutedRewriteProvider(
                gemini: gemini,
                openRouter: openRouter,
                fallbackGeminiModel: ProcessingLevel.defaultCleanRewriteModel
            )
        }

        if let gemini {
            return ModelRoutedRewriteProvider(
                gemini: gemini,
                openRouter: openRouter,
                fallbackGeminiModel: ProcessingLevel.defaultCleanRewriteModel
            )
        }

        return openRouter!
    }

    private func makeSTTProvider() -> STTProvider {
        let appleSpeech = AppleSpeechClient()

        // Build decorated cloud providers in preference order
        var cloudProviders: [(name: String, provider: STTProvider)] = []

        let elevenKey = prefs.elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !elevenKey.isEmpty {
            let eleven = ElevenLabsClient(apiKey: elevenKey)
            let retried = RetryingSTTProvider(provider: eleven, maxRetries: 3, baseDelay: 0.5, name: "ElevenLabs")
            cloudProviders.append((name: "ElevenLabs", provider: retried))
        }

        let deepgramKey = prefs.deepgramAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !deepgramKey.isEmpty {
            let deepgram = DeepgramClient(apiKey: deepgramKey)
            let retried = RetryingSTTProvider(provider: deepgram, maxRetries: 2, baseDelay: 0.5, name: "Deepgram")
            cloudProviders.append((name: "Deepgram", provider: retried))
        }

        let openAIKey = prefs.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !openAIKey.isEmpty {
            let whisper = WhisperClient(apiKey: openAIKey)
            let retried = RetryingSTTProvider(provider: whisper, maxRetries: 2, baseDelay: 0.5, name: "Whisper")
            cloudProviders.append((name: "Whisper", provider: retried))
        }

        let chain: STTProvider
        if cloudProviders.isEmpty {
            chain = appleSpeech
        } else if Self.isHedgedRoutingSelected(environment: ProcessInfo.processInfo.environment) {
            // Opt-in: parallel cloud race with stagger delays
            var hedgedEntries: [HedgedSTTProvider.Entry] = [
                .init(name: "Apple Speech", provider: appleSpeech, delay: 0),
            ]
            let delays: [TimeInterval] = [0, 5, 10]
            for (i, cp) in cloudProviders.enumerated() {
                hedgedEntries.append(.init(name: cp.name, provider: cp.provider, delay: delays[min(i, delays.count - 1)]))
            }
            chain = HedgedSTTProvider(entries: hedgedEntries)
        } else {
            // Default: sequential primary → fallback → Apple Speech safety net
            let allProviders = cloudProviders + [(name: "Apple Speech", provider: appleSpeech as STTProvider)]
            chain = allProviders.dropFirst().reduce(allProviders[0]) { accumulated, next in
                let wrapper = FallbackSTTProvider(
                    primary: accumulated.provider,
                    fallback: next.provider,
                    primaryName: accumulated.name
                )
                return (name: "\(accumulated.name) + \(next.name)", provider: wrapper as STTProvider)
            }.provider
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

    private func resolveStreamingProvider() -> StreamingSTTProvider? {
        if let streamingSTTProvider {
            return streamingSTTProvider
        }
        guard Self.isStreamingAllowed(environment: ProcessInfo.processInfo.environment) else {
            return nil
        }
        // Prefer ElevenLabs (150ms latency, guaranteed commit response)
        let elevenLabsKey = prefs.elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !elevenLabsKey.isEmpty {
            return ElevenLabsStreamingClient(apiKey: elevenLabsKey)
        }
        // Fall back to Deepgram streaming
        let deepgramKey = prefs.deepgramAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !deepgramKey.isEmpty {
            return DeepgramStreamingClient(apiKey: deepgramKey)
        }
        return nil
    }

    nonisolated static func isHedgedRoutingSelected(environment: [String: String]) -> Bool {
        environment["VOX_STT_ROUTING"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "hedged"
    }

    nonisolated static func isStreamingAllowed(environment: [String: String]) -> Bool {
        let raw = environment["VOX_DISABLE_STREAMING_STT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let disabled = raw == "1" || raw == "true" || raw == "yes"
        return !disabled
    }

    private func recorderSupportsStreaming() -> Bool {
        guard recorder is AudioChunkStreaming else {
            return false
        }
        if recorder is AudioRecorder {
            return !Self.isRecorderBackendSelected(environment: ProcessInfo.processInfo.environment)
        }
        return true
    }

    nonisolated static func isRecorderBackendSelected(environment: [String: String]) -> Bool {
        environment["VOX_AUDIO_BACKEND"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "recorder"
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

        // Compatibility fallback: set system default input before starting capture.
        // This was the pre-AVAudioEngine behavior and remains the most reliable path
        // for some Bluetooth devices (for example certain AirPods routing states).
        if let uid = prefs.selectedInputDeviceUID,
           let deviceID = AudioDeviceManager.deviceID(forUID: uid),
           !AudioDeviceManager.setDefaultInputDevice(deviceID) {
            print("[Vox] Failed to set default input device for UID \(uid), continuing")
        }

        // Create streaming bridge and install chunk handler BEFORE starting recorder.
        // Session connects asynchronously; chunks buffer until ready.
        let bridge: StreamingAudioBridge?
        if recorderSupportsStreaming(), let provider = resolveStreamingProvider() {
            let newBridge = StreamingAudioBridge()
            bridge = newBridge
            if let streamingRecorder = recorder as? AudioChunkStreaming {
                streamingRecorder.setAudioChunkHandler(nil)
                streamingRecorder.setAudioChunkHandler { chunk in
                    newBridge.enqueue(chunk)
                }
            }
            let setupTimeout = streamingSetupTimeout
            streamingSetupTask = Task {
                do {
                    let session = try await withStreamingSetupTimeout(seconds: setupTimeout) {
                        try await provider.makeSession()
                    }
                    guard !Task.isCancelled else {
                        await session.cancel()
                        newBridge.markFailed()
                        return
                    }
                    newBridge.attachSession(session)
                } catch {
                    print("[Vox] Streaming setup failed, batch fallback: \(error.localizedDescription)")
                    newBridge.markFailed()
                }
            }
        } else {
            bridge = nil
        }

        do {
            try recorder.start(inputDeviceUID: prefs.selectedInputDeviceUID)
            activeStreamingBridge = bridge
            recordingStartTime = CFAbsoluteTimeGetCurrent()
            state = .recording
            hud.showRecording(average: 0, peak: 0)
            startLevelTimer()
        } catch {
            await cancelAndAwaitStreamingSetup()
            await bridge?.cancel()
            activeStreamingBridge = nil
            if let streamingRecorder = recorder as? AudioChunkStreaming {
                streamingRecorder.setAudioChunkHandler(nil)
            }
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

        let dictationID = UUID().uuidString
        await DiagnosticsStore.shared.record(
            name: "processing_started",
            sessionID: dictationID,
            fields: [
                "processing_level": .string(prefs.processingLevel.rawValue),
                "recording_s": .double(recordingDuration),
                "had_streaming_bridge": .bool(activeStreamingBridge != nil),
            ]
        )

        let url: URL
        do {
            url = try recorder.stop()
        } catch let error as VoxError {
            await cancelAndAwaitStreamingSetup()
            let streamingBridge = detachStreamingBridge()
            await streamingBridge?.cancel()
            switch error {
            case .audioCaptureFailed:
                await sessionExtension.didFailDictation(reason: "recording_tap_failed")
            default:
                await sessionExtension.didFailDictation(reason: "recording_stop_failed")
            }
            presentError(error.localizedDescription)
            await DiagnosticsStore.shared.record(
                name: "recording_stop_failed",
                sessionID: dictationID,
                fields: [
                    "error_code": .string(DiagnosticsStore.errorCode(for: error)),
                    "error_type": .string(String(describing: type(of: error))),
                ]
            )
            state = .idle
            hud.hide()
            return
        } catch {
            await cancelAndAwaitStreamingSetup()
            let streamingBridge = detachStreamingBridge()
            await streamingBridge?.cancel()
            await sessionExtension.didFailDictation(reason: "recording_stop_failed")
            presentError(error.localizedDescription)
            await DiagnosticsStore.shared.record(
                name: "recording_stop_failed",
                sessionID: dictationID,
                fields: [
                    "error_code": .string(DiagnosticsStore.errorCode(for: error)),
                    "error_type": .string(String(describing: type(of: error))),
                ]
            )
            state = .idle
            hud.hide()
            return
        }

        // Wait for streaming setup to complete before detaching bridge
        if let setupTask = streamingSetupTask {
            await setupTask.value
            streamingSetupTask = nil
        }

        let streamingBridge = detachStreamingBridge()

        var succeeded = false
        do {
            let active = pipeline ?? makePipeline(dictationID: dictationID)
            let output: String
            if let streamingBridge {
                output = try await processWithStreamingFallback(
                    bridge: streamingBridge,
                    batchPipeline: active,
                    audioURL: url,
                    recordingDurationSeconds: recordingDuration,
                    dictationID: dictationID
                )
            } else {
                output = try await active.process(audioURL: url)
            }
            await sessionExtension.didCompleteDictation(
                event: DictationUsageEvent(
                    recordingDuration: recordingDuration,
                    outputCharacterCount: output.count,
                    processingLevel: prefs.processingLevel
                )
            )
            succeeded = true
            await DiagnosticsStore.shared.record(
                name: "processing_succeeded",
                sessionID: dictationID,
                fields: [
                    "processing_level": .string(prefs.processingLevel.rawValue),
                    "output_chars": .int(output.count),
                ]
            )
        } catch is CancellationError {
            print("[Vox] Processing cancelled")
            await sessionExtension.didFailDictation(reason: "processing_cancelled")
            SecureFileDeleter.delete(at: url)
            await DiagnosticsStore.shared.record(name: "processing_cancelled", sessionID: dictationID)
        } catch {
            print("[Vox] Processing failed: \(error.localizedDescription)")
            await sessionExtension.didFailDictation(reason: "processing_failed")
            let preservedURL = preserveAudio(at: url)
            let preserved = preservedURL != nil
            if let saved = preservedURL {
                presentError("\(error.localizedDescription)\n\nYour audio was saved to:\n\(saved.path)")
            } else {
                presentError(error.localizedDescription)
            }
            await DiagnosticsStore.shared.record(
                name: "processing_failed",
                sessionID: dictationID,
                fields: [
                    "processing_level": .string(prefs.processingLevel.rawValue),
                    "error_code": .string(DiagnosticsStore.errorCode(for: error)),
                    "error_type": .string(String(describing: type(of: error))),
                    "audio_preserved": .bool(preserved),
                ]
            )
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

    private func processWithStreamingFallback(
        bridge: StreamingAudioBridge,
        batchPipeline: DictationProcessing,
        audioURL: URL,
        recordingDurationSeconds: TimeInterval,
        dictationID: String
    ) async throws -> String {
        let finalizeStart = CFAbsoluteTimeGetCurrent()
        func logFinalize(outcome: String, reason: String, transcriptChars: Int? = nil) {
            let waitedMs = Int((CFAbsoluteTimeGetCurrent() - finalizeStart) * 1000)
            let durationStr = String(format: "%.2f", recordingDurationSeconds)
            if let transcriptChars {
                print("[Vox] Streaming finalize outcome=\(outcome) waited_ms=\(waitedMs) recording_s=\(durationStr) reason=\(reason) transcript_chars=\(transcriptChars)")
            } else {
                print("[Vox] Streaming finalize outcome=\(outcome) waited_ms=\(waitedMs) recording_s=\(durationStr) reason=\(reason)")
            }
            Task {
                var fields: [String: DiagnosticsValue] = [
                    "outcome": .string(outcome),
                    "reason": .string(reason),
                    "waited_ms": .int(waitedMs),
                    "recording_s": .double(recordingDurationSeconds),
                ]
                if let transcriptChars {
                    fields["transcript_chars"] = .int(transcriptChars)
                }
                await DiagnosticsStore.shared.record(
                    name: "streaming_finalize",
                    sessionID: dictationID,
                    fields: fields
                )
            }
        }
        func reasonCode(for error: Error) -> String {
            if let streamingError = error as? StreamingSTTError {
                switch streamingError {
                case .finalizationTimeout:
                    return "finalization_timeout"
                case .connectionFailed:
                    return "connection_failed"
                case .sendFailed:
                    return "send_failed"
                case .receiveFailed:
                    return "receive_failed"
                case .provider:
                    return "provider_error"
                case .cancelled:
                    return "cancelled"
                case .invalidState:
                    return "invalid_state"
                }
            }
            if let voxError = error as? VoxError {
                switch voxError {
                case .noTranscript:
                    return "no_transcript"
                default:
                    return "vox_error"
                }
            }
            return "unknown"
        }
        do {
            let transcript = try await bridge.finish()
            let normalized = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                throw VoxError.noTranscript
            }
            if let transcriptPipeline = batchPipeline as? TranscriptProcessing {
                #if DEBUG
                print("[Vox] Streaming transcript finalized (\(normalized.count) chars)")
                #endif
                logFinalize(outcome: "success", reason: "ok", transcriptChars: normalized.count)
                return try await transcriptPipeline.process(transcript: normalized)
            }
            logFinalize(outcome: "batch_fallback", reason: "missing_transcript_pipeline")
            print("[Vox] Streaming finalized, but pipeline lacks TranscriptProcessing; falling back to batch STT")
        } catch let streamingError as StreamingSTTError
            where !streamingError.isFallbackEligible {
            logFinalize(outcome: "error", reason: reasonCode(for: streamingError))
            await bridge.cancel()
            throw streamingError
        } catch {
            logFinalize(outcome: "batch_fallback", reason: reasonCode(for: error))
            print("[Vox] Streaming finalize failed, falling back to batch STT: \(error.localizedDescription)")
        }

        await bridge.cancel()
        return try await batchPipeline.process(audioURL: audioURL)
    }

    private func detachStreamingBridge() -> StreamingAudioBridge? {
        if let streamingRecorder = recorder as? AudioChunkStreaming {
            streamingRecorder.setAudioChunkHandler(nil)
        }
        let bridge = activeStreamingBridge
        activeStreamingBridge = nil
        return bridge
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

    private func cancelAndAwaitStreamingSetup() async {
        guard let setupTask = streamingSetupTask else { return }
        setupTask.cancel()
        await setupTask.value
        streamingSetupTask = nil
    }

    private func presentError(_ message: String) {
        errorPresenter(message)
    }
}

private final class StreamingAudioBridge: @unchecked Sendable {
    private var pump: StreamingSessionPump?
    private let queueLock = NSLock()
    private var pendingChunks: [AudioChunk] = []
    private var drainTask: Task<Void, Never>?
    private var acceptsChunks = true

    init() {
        pendingChunks.reserveCapacity(50)
    }

    /// Attach a streaming session after async setup completes.
    /// Starts draining any buffered chunks immediately.
    func attachSession(_ session: any StreamingSTTSession) {
        queueLock.withLock {
            pump = StreamingSessionPump(session: session)
            if !pendingChunks.isEmpty && drainTask == nil {
                drainTask = Task { [weak self] in
                    await self?.drainLoop()
                }
            }
        }
    }

    /// Mark the bridge as failed (setup didn't succeed).
    /// Stops accepting chunks and clears the buffer.
    func markFailed() {
        queueLock.withLock {
            acceptsChunks = false
            pendingChunks.removeAll()
        }
    }

    func enqueue(_ chunk: AudioChunk) {
        queueLock.withLock {
            guard acceptsChunks else { return }
            pendingChunks.append(chunk)
            // Only start drain if pump is already attached
            if drainTask == nil && pump != nil {
                drainTask = Task { [weak self] in
                    await self?.drainLoop()
                }
            }
        }
    }

    func finish() async throws -> String {
        let (activeDrain, capturedPump) = queueLock.withLock {
            () -> (Task<Void, Never>?, StreamingSessionPump?) in
            acceptsChunks = false
            return (drainTask, pump)
        }
        if let activeDrain {
            await activeDrain.value
        }
        guard let capturedPump else {
            throw StreamingSTTError.connectionFailed("Streaming session was not established")
        }
        return try await capturedPump.finish()
    }

    func cancel() async {
        let (activeDrain, capturedPump) = queueLock.withLock {
            () -> (Task<Void, Never>?, StreamingSessionPump?) in
            acceptsChunks = false
            pendingChunks.removeAll()
            return (drainTask, pump)
        }
        activeDrain?.cancel()
        if let activeDrain {
            _ = await activeDrain.result
        }
        await capturedPump?.cancel()
    }

    private func drainLoop() async {
        let capturedPump = queueLock.withLock { pump }
        guard let capturedPump else {
            queueLock.withLock {
                drainTask = nil
            }
            return
        }
        while true {
            if Task.isCancelled {
                queueLock.withLock {
                    drainTask = nil
                }
                return
            }

            let next = queueLock.withLock { () -> AudioChunk? in
                guard !pendingChunks.isEmpty else {
                    drainTask = nil
                    return nil
                }
                return pendingChunks.removeFirst()
            }
            guard let next else {
                return
            }
            await capturedPump.enqueue(next)
        }
    }
}

private actor StreamingSessionPump {
    private enum LifecycleState {
        case open
        case finishing
        case closed
    }

    private let session: any StreamingSTTSession
    private var partialReader: Task<Void, Never>?
    private var latestTranscript: String = ""
    private var sendError: Error?
    private var state: LifecycleState = .open

    init(session: any StreamingSTTSession) {
        self.session = session
        Task {
            await ensurePartialReaderStarted()
        }
    }

    private func ensurePartialReaderStarted() {
        guard partialReader == nil else {
            return
        }
        partialReader = Task { [weak self] in
            guard let self else { return }
            for await partial in session.partialTranscripts {
                let trimmed = partial.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                await self.recordPartial(trimmed)
            }
        }
    }

    func enqueue(_ chunk: AudioChunk) async {
        ensurePartialReaderStarted()
        guard state == .open, sendError == nil else {
            return
        }
        do {
            try await session.sendAudioChunk(chunk)
        } catch {
            sendError = error
        }
    }

    func finish() async throws -> String {
        ensurePartialReaderStarted()
        guard state == .open else {
            throw StreamingSTTError.invalidState("Streaming pump already finished")
        }
        state = .finishing
        if let sendError {
            throw sendError
        }

        // Session handles its own finalization timeout + transcript recovery.
        // No outer timeout race — single timeout avoids discarding recovered transcripts.
        let transcript = try await session.finish()

        state = .closed
        let normalized = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            return normalized
        }
        let fallback = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback
    }

    func cancel() async {
        ensurePartialReaderStarted()
        guard state != .closed else {
            return
        }
        state = .closed
        partialReader?.cancel()
        await session.cancel()
    }

    private func recordPartial(_ transcript: String) {
        latestTranscript = transcript
    }
}

private func withStreamingSetupTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let timeoutNanoseconds: UInt64
    do {
        timeoutNanoseconds = try validatedStreamingTimeoutNanoseconds(seconds: seconds)
    } catch {
        throw StreamingSTTError.connectionFailed("Streaming setup timeout must be positive and finite")
    }
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: timeoutNanoseconds)
            throw StreamingSTTError.connectionFailed("Streaming setup timed out")
        }
        guard let result = try await group.next() else {
            throw StreamingSTTError.connectionFailed("Streaming setup timed out")
        }
        group.cancelAll()
        return result
    }
}

private func validatedStreamingTimeoutNanoseconds(seconds: TimeInterval) throws -> UInt64 {
    guard seconds > 0, seconds.isFinite else {
        throw StreamingSTTError.invalidState("Invalid streaming finalize timeout: \(seconds)")
    }
    let nanoseconds = seconds * 1_000_000_000
    guard nanoseconds.isFinite, nanoseconds >= 0, nanoseconds < Double(UInt64.max) else {
        throw StreamingSTTError.invalidState("Invalid streaming finalize timeout: \(seconds)")
    }
    return UInt64(nanoseconds)
}
