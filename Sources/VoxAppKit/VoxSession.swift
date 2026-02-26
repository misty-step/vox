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
    public var onRecoveryAvailabilityChange: ((Bool) -> Void)?

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
    private let copyRawTranscriptToClipboard: (String) -> Void
    private let recoveryStore: LastDictationRecoveryStore
    private let pipeline: DictationProcessing?
    private let streamingSTTProvider: StreamingSTTProvider?
    private let debugSink: DebugWorkbenchSink?
    private var streamingSetupTask: Task<Void, Never>?
    private var activeDictationID: String?
    private let streamingSetupTimeout: TimeInterval
    private let streamingFinalizeTimeout: TimeInterval
    private var levelTimer: Timer?
    private var recordingStartTime: CFAbsoluteTime?
    private var activeStreamingBridge: StreamingAudioBridge?
    private static let noRecentDictationError = VoxError.internalError("No recent dictation available.")

    public convenience init(
        recorder: AudioRecording? = nil,
        pipeline: DictationProcessing? = nil,
        hud: HUDDisplaying? = nil,
        prefs: PreferencesReading? = nil,
        sessionExtension: SessionExtension? = nil,
        requestMicrophoneAccess: (() async -> Bool)? = nil,
        errorPresenter: ((String) -> Void)? = nil,
        copyRawTranscriptToClipboard: ((String) -> Void)? = nil,
        streamingSTTProvider: StreamingSTTProvider? = nil,
        streamingSetupTimeout: TimeInterval = 3.0,
        streamingFinalizeTimeout: TimeInterval = 90.0
    ) {
        self.init(
            recorder: recorder,
            pipeline: pipeline,
            hud: hud,
            prefs: prefs,
            sessionExtension: sessionExtension,
            requestMicrophoneAccess: requestMicrophoneAccess,
            errorPresenter: errorPresenter,
            copyRawTranscriptToClipboard: copyRawTranscriptToClipboard,
            recoveryStore: .shared,
            streamingSTTProvider: streamingSTTProvider,
            streamingSetupTimeout: streamingSetupTimeout,
            streamingFinalizeTimeout: streamingFinalizeTimeout,
            debugSink: nil
        )
    }

    init(
        recorder: AudioRecording? = nil,
        pipeline: DictationProcessing? = nil,
        hud: HUDDisplaying? = nil,
        prefs: PreferencesReading? = nil,
        sessionExtension: SessionExtension? = nil,
        requestMicrophoneAccess: (() async -> Bool)? = nil,
        errorPresenter: ((String) -> Void)? = nil,
        copyRawTranscriptToClipboard: ((String) -> Void)? = nil,
        recoveryStore: LastDictationRecoveryStore,
        streamingSTTProvider: StreamingSTTProvider? = nil,
        streamingSetupTimeout: TimeInterval = 3.0,
        streamingFinalizeTimeout: TimeInterval = 90.0,
        debugSink: DebugWorkbenchSink? = nil
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
        self.copyRawTranscriptToClipboard = copyRawTranscriptToClipboard ?? { text in
            ClipboardPaster().copy(text: text, restoreAfter: nil)
        }
        self.recoveryStore = recoveryStore
        self.streamingSTTProvider = streamingSTTProvider
        self.streamingSetupTimeout = streamingSetupTimeout
        self.streamingFinalizeTimeout = streamingFinalizeTimeout
        self.debugSink = debugSink
    }

    private var hasCloudProviders: Bool {
        let keys = [
            prefs.elevenLabsAPIKey,
            prefs.deepgramAPIKey,
        ]
        return keys.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func makePipeline() -> DictationProcessing {
        makePipeline(dictationID: UUID().uuidString)
    }

    private func makePipeline(dictationID: String) -> DictationProcessing {
        let recoveryStore = self.recoveryStore
        let config = assemblyConfig(dictationID: dictationID)
        return DictationPipeline(
            stt: makeSTTProvider(config: config),
            rewriter: makeRewriteProvider(config: config),
            paster: ClipboardPaster(),
            prefs: prefs,
            rewriteCache: .shared,
            enableRewriteCache: true,
            enableOpus: hasCloudProviders,
            timingHandler: { timing in
                let totalStageMs = Int((timing.encodeTime + timing.sttTime + timing.rewriteTime + timing.pasteTime) * 1000)
                var fields: [String: DiagnosticsValue] = [
                    "processing_level": .string(timing.processingLevel?.rawValue ?? ""),
                    "total_ms": .int(Int(timing.totalTime * 1000)),
                    "total_stage_ms": .int(totalStageMs),
                    "encode_ms": .int(Int(timing.encodeTime * 1000)),
                    "stt_ms": .int(Int(timing.sttTime * 1000)),
                    "rewrite_ms": .int(Int(timing.rewriteTime * 1000)),
                    "paste_ms": .int(Int(timing.pasteTime * 1000)),
                    "original_bytes": .int(timing.originalSizeBytes),
                    "encoded_bytes": .int(timing.encodedSizeBytes),
                ]
                if timing.finalizeTimeInterval > 0 {
                    fields["finalize_ms"] = .int(Int(timing.finalizeTimeInterval * 1000))
                }
                DiagnosticsStore.recordAsync(
                    name: "pipeline_timing",
                    sessionID: dictationID,
                    fields: fields
                )
            },
            onProcessedTranscript: { rawTranscript, outputText, processingLevel in
                await recoveryStore.store(
                    rawTranscript: rawTranscript,
                    finalText: outputText,
                    processingLevel: processingLevel
                )
            },
            onRawTranscript: { [debugSink] rawTranscript in
                debugSink?.setRawTranscript(requestID: dictationID, text: rawTranscript)
            },
            onRewriteResult: { [debugSink] level, outputText in
                debugSink?.setRewrite(requestID: dictationID, level: level, text: outputText)
            },
            onPipelineLog: { [debugSink] message in
                debugSink?.log(requestID: dictationID, message: message)
            }
        )
    }

    private func makeRewriteProvider(config: ProviderAssemblyConfig) -> RewriteProvider {
        let cloudRewrite = ProviderAssembly.makeRewriteProvider(config: config)

        if cloudRewrite is OpenRouterClient, prefs.openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            prefs.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("[Vox] Warning: No rewrite API keys configured (GEMINI_API_KEY or OPENROUTER_API_KEY). Rewriting will fail.")
        }
        return cloudRewrite
    }

    private func makeSTTProvider(config: ProviderAssemblyConfig) -> STTProvider {
        // macOS 26+: SpeechTranscriber (on-device, newer API) with AppleSpeechClient fallback.
        // SpeechTranscriber requires the macOS 26 SDK (Xcode 26+); gate with canImport(FoundationModels)
        // as a proxy for that SDK being present.
        let appleSTT: STTProvider
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            appleSTT = FallbackSTTProvider(
                primary: SpeechTranscriberClient(),
                fallback: AppleSpeechClient(),
                primaryName: "SpeechTranscriber"
            )
        } else {
            appleSTT = AppleSpeechClient()
        }
        #else
        appleSTT = AppleSpeechClient()
        #endif

        let cloudResult = ProviderAssembly.makeCloudSTTProvider(config: config)

        let chain: STTProvider
        if cloudResult.entries.isEmpty {
            chain = appleSTT
        } else if Self.isHedgedRoutingSelected(environment: ProcessInfo.processInfo.environment) {
            // Opt-in: parallel cloud race with stagger delays
            var hedgedEntries: [HedgedSTTProvider.Entry] = [
                .init(name: "Apple Speech", provider: appleSTT, delay: 0),
            ]
            let delays: [TimeInterval] = [0, 5, 10]
            for (i, entry) in cloudResult.entries.enumerated() {
                hedgedEntries.append(.init(name: entry.name, provider: entry.provider, delay: delays[min(i, delays.count - 1)]))
            }
            chain = HedgedSTTProvider(entries: hedgedEntries)
        } else {
            // Default: sequential cloud chain → Apple Speech safety net
            let cloudChain = ProviderAssembly.buildFallbackChain(from: cloudResult.entries)!
            chain = FallbackSTTProvider(
                primary: cloudChain,
                fallback: appleSTT,
                primaryName: ProviderAssembly.chainLabel(for: cloudResult.entries)
            )
        }

        return ConcurrencyLimitedSTTProvider(
            provider: chain,
            maxConcurrent: maxConcurrentSTTRequests()
        )
    }

    private func assemblyConfig(dictationID: String) -> ProviderAssemblyConfig {
        ProviderAssemblyConfig(
            elevenLabsAPIKey: prefs.elevenLabsAPIKey,
            deepgramAPIKey: prefs.deepgramAPIKey,
            geminiAPIKey: prefs.geminiAPIKey,
            openRouterAPIKey: prefs.openRouterAPIKey,
            openRouterOnModelUsed: { model, isFallback in
                DiagnosticsStore.recordAsync(
                    name: DiagnosticsEventNames.rewriteModelUsed,
                    sessionID: dictationID,
                    fields: [
                        "provider": .string("openrouter"),
                        "served_model": .string(model),
                        "is_fallback_model": .bool(isFallback),
                    ]
                )

                #if DEBUG
                print("[RewriteDiag] provider=openrouter event=model_used served_model=\(model) fallback_model=\(isFallback)")
                #endif
            },
            openRouterOnDiagnostic: { diagnostic in
                var fields: [String: DiagnosticsValue] = [
                    "provider": .string("openrouter"),
                    "outcome": .string(diagnostic.outcome.rawValue),
                    "requested_model": .string(diagnostic.requestedModel),
                    "router_model": .string(diagnostic.routerModel),
                    "attempt": .int(diagnostic.attempt),
                    "is_fallback_model": .bool(diagnostic.isFallbackModel),
                    "routing_mode": .string(diagnostic.routingMode.rawValue),
                ]
                if let servedModel = diagnostic.servedModel {
                    fields["served_model"] = .string(servedModel)
                }
                if let elapsedMs = diagnostic.elapsedMs {
                    fields["elapsed_ms"] = .int(elapsedMs)
                }
                if let httpStatusCode = diagnostic.httpStatusCode {
                    fields["http_status"] = .int(httpStatusCode)
                }
                if let errorCode = diagnostic.errorCode {
                    fields["error_code"] = .string(errorCode)
                }
                if let errorMessage = diagnostic.errorMessage {
                    fields["error_message"] = .string(errorMessage)
                }

                DiagnosticsStore.recordAsync(
                    name: DiagnosticsEventNames.rewriteOpenRouterAttempt,
                    sessionID: dictationID,
                    fields: fields
                )

                #if DEBUG
                var logParts: [String] = [
                    "provider=openrouter",
                    "event=attempt",
                    "outcome=\(diagnostic.outcome.rawValue)",
                    "requested=\(diagnostic.requestedModel)",
                    "router=\(diagnostic.routerModel)",
                    "attempt=\(diagnostic.attempt)",
                    "fallback_model=\(diagnostic.isFallbackModel)",
                    "routing=\(diagnostic.routingMode.rawValue)",
                ]
                if let servedModel = diagnostic.servedModel {
                    logParts.append("served=\(servedModel)")
                }
                if let elapsedMs = diagnostic.elapsedMs {
                    logParts.append("elapsed_ms=\(elapsedMs)")
                }
                if let httpStatusCode = diagnostic.httpStatusCode {
                    logParts.append("http_status=\(httpStatusCode)")
                }
                if let errorCode = diagnostic.errorCode {
                    logParts.append("error_code=\(errorCode)")
                }
                print("[RewriteDiag] " + logParts.joined(separator: " "))
                #endif
            }
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

    public func copyLastRawTranscript() async {
        do {
            let rawTranscript = try await latestRawTranscriptForRecovery()
            copyRawTranscriptToClipboard(rawTranscript)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    public func retryLastRewrite() async {
        do {
            try await retryLastRewriteOrThrow()
        } catch {
            presentError(error.localizedDescription)
            state = .idle
            hud.hide()
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
        let appName = Bundle.main.bundleIdentifier?.components(separatedBy: ".").last ?? "Vox"
        let recoveryDir = support.appendingPathComponent("\(appName)/recovery")
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
        let requestID = UUID().uuidString
        activeDictationID = requestID
        debugSink?.startRequest(id: requestID, processingLevel: prefs.processingLevel)
        debugSink?.updateStatus(id: requestID, status: .recording)
        debugSink?.log(requestID: requestID, message: "recording authorization requested")

        do {
            try await sessionExtension.authorizeRecordingStart()
        } catch {
            debugSink?.updateStatus(id: requestID, status: .failed)
            debugSink?.log(requestID: requestID, message: "recording authorization failed: \(error.localizedDescription)")
            presentError(error.localizedDescription)
            return
        }

        let granted = await requestMicrophoneAccess()
        guard granted else {
            await sessionExtension.didFailDictation(reason: "microphone_permission_denied")
            debugSink?.updateStatus(id: requestID, status: .failed)
            debugSink?.log(requestID: requestID, message: "microphone permission denied")
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
            debugSink?.updateStatus(id: requestID, status: .recording)
            debugSink?.log(requestID: requestID, message: "recording started")
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
            debugSink?.updateStatus(id: requestID, status: .failed)
            debugSink?.log(requestID: requestID, message: "recording start failed: \(error.localizedDescription)")
            presentError(error.localizedDescription)
            state = .idle
            activeDictationID = nil
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

        let dictationID = activeDictationID ?? UUID().uuidString
        activeDictationID = nil
        let processingLevelAtStop = prefs.processingLevel.rawValue
        let hadStreamingBridgeAtStop = activeStreamingBridge != nil
        debugSink?.startRequest(id: dictationID, processingLevel: prefs.processingLevel)
        debugSink?.updateStatus(id: dictationID, status: .processing)
        debugSink?.log(requestID: dictationID, message: "recording duration \(String(format: "%.2f", recordingDuration))s")
        debugSink?.log(requestID: dictationID, message: "recording stopped; processing started (level=\(processingLevelAtStop))")
        DiagnosticsStore.recordAsync(
            name: "processing_started",
            sessionID: dictationID,
            fields: [
                "processing_level": .string(processingLevelAtStop),
                "recording_s": .double(recordingDuration),
                "had_streaming_bridge": .bool(hadStreamingBridgeAtStop),
            ]
        )

        let url: URL
        do {
            url = try await recorder.stop()
        } catch {
            await cancelAndAwaitStreamingSetup()
            let streamingBridge = detachStreamingBridge()
            await streamingBridge?.cancel()
            (recorder as? EncryptedAudioRecording)?.discardRecordingEncryptionKey()

            let reason: String
            if let voxError = error as? VoxError {
                switch voxError {
                case .audioCaptureFailed:
                    reason = "recording_tap_failed"
                default:
                    reason = "recording_stop_failed"
                }
            } else {
                reason = "recording_stop_failed"
            }

            await sessionExtension.didFailDictation(reason: reason)
            presentError(error.localizedDescription)
            DiagnosticsStore.recordAsync(
                name: "recording_stop_failed",
                sessionID: dictationID,
                fields: DiagnosticsStore.errorFields(for: error)
            )
            debugSink?.updateStatus(id: dictationID, status: .failed)
            debugSink?.log(requestID: dictationID, message: "recording stop failed: \(error.localizedDescription)")
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
        var decryptionKey = (recorder as? EncryptedAudioRecording)?.consumeRecordingEncryptionKey()
        var temporaryBatchAudioURL: URL?

        defer {
            if var key = decryptionKey {
                AudioFileEncryption.zeroizeKey(&key)
            }
            if let temporaryBatchAudioURL {
                SecureFileDeleter.delete(at: temporaryBatchAudioURL)
            }
        }

        do {
            let active = pipeline ?? makePipeline(dictationID: dictationID)
            let output: String
            if let streamingBridge {
                output = try await processWithStreamingFallback(
                    bridge: streamingBridge,
                    batchPipeline: active,
                    audioURL: url,
                    recordingDurationSeconds: recordingDuration,
                    dictationID: dictationID,
                    decryptionKey: &decryptionKey,
                    temporaryBatchAudioURL: &temporaryBatchAudioURL
                )
            } else if AudioFileEncryption.isEncrypted(url: url) {
                let prepared = try await prepareBatchAudioURL(from: url, decryptionKey: &decryptionKey)
                temporaryBatchAudioURL = prepared.temporaryAudioURL
                output = try await active.process(audioURL: prepared.batchAudioURL)
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
            debugSink?.updateStatus(id: dictationID, status: .succeeded)
            debugSink?.log(requestID: dictationID, message: "processing succeeded (output_chars=\(output.count))")
            let processingLevelOnSuccess = prefs.processingLevel.rawValue
            let outputChars = output.count
            DiagnosticsStore.recordAsync(
                name: "processing_succeeded",
                sessionID: dictationID,
                fields: [
                    "processing_level": .string(processingLevelOnSuccess),
                    "output_chars": .int(outputChars),
                ]
            )
        } catch is CancellationError {
            print("[Vox] Processing cancelled")
            await sessionExtension.didFailDictation(reason: "processing_cancelled")
            SecureFileDeleter.delete(at: url)
            DiagnosticsStore.recordAsync(name: "processing_cancelled", sessionID: dictationID)
            debugSink?.updateStatus(id: dictationID, status: .cancelled)
            debugSink?.log(requestID: dictationID, message: "processing cancelled")
        } catch {
            print("[Vox] Processing failed: \(error.localizedDescription)")
            await sessionExtension.didFailDictation(reason: "processing_failed")
            let preservedURL = await preserveRecoverableAudio(
                recordedURL: url,
                decryptionKey: &decryptionKey,
                temporaryBatchAudioURL: temporaryBatchAudioURL
            )
            let preserved = preservedURL != nil
            if let saved = preservedURL {
                presentError("\(error.localizedDescription)\n\nYour audio was saved to:\n\(saved.path)")
            } else {
                presentError(error.localizedDescription)
            }
            let processingLevelOnError = prefs.processingLevel.rawValue
            DiagnosticsStore.recordAsync(
                name: "processing_failed",
                sessionID: dictationID,
                fields: DiagnosticsStore.errorFields(
                    for: error,
                    additional: [
                        "processing_level": .string(processingLevelOnError),
                        "audio_preserved": .bool(preserved),
                    ]
                )
            )
            debugSink?.updateStatus(id: dictationID, status: .failed)
            debugSink?.log(requestID: dictationID, message: "processing failed: \(error.localizedDescription)")
        }

        if succeeded {
            SecureFileDeleter.delete(at: url)
            onRecoveryAvailabilityChange?(true)
            Task {
                await runDebugShadowRewritesIfNeeded(dictationID: dictationID)
            }
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
        dictationID: String,
        decryptionKey: inout Data?,
        temporaryBatchAudioURL: inout URL?
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
            var fields: [String: DiagnosticsValue] = [
                "outcome": .string(outcome),
                "reason": .string(reason),
                "waited_ms": .int(waitedMs),
                "recording_s": .double(recordingDurationSeconds),
            ]
            if let transcriptChars {
                fields["transcript_chars"] = .int(transcriptChars)
            }
            DiagnosticsStore.recordAsync(
                name: "streaming_finalize",
                sessionID: dictationID,
                fields: fields
            )
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
            let finalizeTimeout = streamingFinalizeTimeout
            let transcript = try await withStreamingFinalizeTimeout(seconds: finalizeTimeout) {
                try await bridge.finish()
            }
            let normalizedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedTranscript.isEmpty else {
                throw VoxError.noTranscript
            }
            let finalizeElapsed = CFAbsoluteTimeGetCurrent() - finalizeStart
            if let dictationPipeline = batchPipeline as? DictationPipeline {
                // Use extended API so the pipeline summary includes finalize time.
                logFinalize(outcome: "success", reason: "ok", transcriptChars: normalizedTranscript.count)
                return try await dictationPipeline.process(
                    transcript: normalizedTranscript,
                    streamingFinalizeTimeInterval: finalizeElapsed
                )
            }
            if let transcriptPipeline = batchPipeline as? TranscriptProcessing {
                logFinalize(outcome: "success", reason: "ok", transcriptChars: normalizedTranscript.count)
                return try await transcriptPipeline.process(transcript: normalizedTranscript)
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
        let preparedAudio = try await prepareBatchAudioURL(from: audioURL, decryptionKey: &decryptionKey)
        temporaryBatchAudioURL = preparedAudio.temporaryAudioURL
        return try await batchPipeline.process(audioURL: preparedAudio.batchAudioURL)
    }

    private func prepareBatchAudioURL(
        from recordedURL: URL,
        decryptionKey: inout Data?
    ) async throws -> (batchAudioURL: URL, temporaryAudioURL: URL?) {
        guard AudioFileEncryption.isEncrypted(url: recordedURL) else {
            return (recordedURL, nil)
        }

        guard var key = decryptionKey else {
            throw VoxError.internalError("Missing decryption key for encrypted recording.")
        }

        let plainURL = recordedURL.deletingPathExtension()
        defer {
            AudioFileEncryption.zeroizeKey(&key)
            decryptionKey = nil
        }

        do {
            try await AudioFileEncryption.decrypt(encryptedURL: recordedURL, outputURL: plainURL, key: key)
        } catch {
            SecureFileDeleter.delete(at: plainURL)
            throw error
        }
        return (plainURL, plainURL)
    }

    /// Persists audio for troubleshooting while keeping it usable (decryptable) when encrypted recording is enabled.
    private func preserveRecoverableAudio(
        recordedURL: URL,
        decryptionKey: inout Data?,
        temporaryBatchAudioURL: URL?
    ) async -> URL? {
        guard AudioFileEncryption.isEncrypted(url: recordedURL) else {
            return preserveAudio(at: recordedURL)
        }

        if let temporaryBatchAudioURL {
            if let preservedPlain = preserveAudio(at: temporaryBatchAudioURL) {
                SecureFileDeleter.delete(at: recordedURL)
                return preservedPlain
            }
            return preserveAudio(at: recordedURL)
        }

        if var key = decryptionKey {
            let plainURL = recordedURL.deletingPathExtension()
            defer {
                AudioFileEncryption.zeroizeKey(&key)
                decryptionKey = nil
            }

            do {
                try await AudioFileEncryption.decrypt(encryptedURL: recordedURL, outputURL: plainURL, key: key)
            } catch {
                SecureFileDeleter.delete(at: plainURL)
                return preserveAudio(at: recordedURL)
            }

            if let preservedPlain = preserveAudio(at: plainURL) {
                SecureFileDeleter.delete(at: recordedURL)
                return preservedPlain
            }

            SecureFileDeleter.delete(at: plainURL)
            return preserveAudio(at: recordedURL)
        }

        return preserveAudio(at: recordedURL)
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

    private func latestRawTranscriptForRecovery() async throws -> String {
        guard let rawTranscript = await recoveryStore.latestRawTranscript() else {
            onRecoveryAvailabilityChange?(false)
            throw Self.noRecentDictationError
        }
        let normalized = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            onRecoveryAvailabilityChange?(false)
            throw Self.noRecentDictationError
        }
        return normalized
    }

    private func retryLastRewriteOrThrow() async throws {
        guard state == .idle else {
            throw VoxError.internalError("Retry rewrite is unavailable while dictation is active.")
        }
        guard let snapshot = await recoveryStore.latestSnapshot() else {
            onRecoveryAvailabilityChange?(false)
            throw Self.noRecentDictationError
        }
        let normalizedRaw = snapshot.rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRaw.isEmpty else {
            onRecoveryAvailabilityChange?(false)
            throw Self.noRecentDictationError
        }

        state = .processing
        hud.showProcessing(message: "Retrying rewrite")
        let active = pipeline ?? makePipeline(dictationID: UUID().uuidString)
        guard let recoveryPipeline = active as? TranscriptRecoveryProcessing else {
            throw VoxError.internalError("Retry rewrite is unavailable with the current pipeline.")
        }
        _ = try await recoveryPipeline.process(
            transcript: normalizedRaw,
            processingLevel: snapshot.processingLevel,
            bypassRewriteCache: true
        )
        state = .idle
        hud.showSuccess()
    }

    private func runDebugShadowRewritesIfNeeded(dictationID: String) async {
        guard let debugSink else { return }
        guard let snapshot = await recoveryStore.latestSnapshot() else {
            debugSink.log(requestID: dictationID, message: "shadow rewrite skipped: no recovery snapshot")
            return
        }

        let rawTranscript = snapshot.rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawTranscript.isEmpty else {
            debugSink.log(requestID: dictationID, message: "shadow rewrite skipped: empty raw transcript")
            return
        }

        let levelsToRun: [ProcessingLevel]
        switch snapshot.processingLevel {
        case .raw:
            levelsToRun = [.clean, .polish]
        case .clean:
            levelsToRun = [.polish]
        case .polish:
            levelsToRun = [.clean]
        }

        guard !levelsToRun.isEmpty else { return }

        let provider = makeRewriteProvider(config: assemblyConfig(dictationID: dictationID))
        for level in levelsToRun {
            let model = level.defaultModel
            debugSink.log(requestID: dictationID, message: "shadow rewrite start (level=\(level.rawValue), model=\(model))")
            let prompt = RewritePrompts.prompt(for: level, transcript: rawTranscript)
            do {
                let rewritten = try await provider.rewrite(
                    transcript: rawTranscript,
                    systemPrompt: prompt,
                    model: model
                )
                let normalized = rewritten.trimmingCharacters(in: .whitespacesAndNewlines)
                if normalized.isEmpty {
                    debugSink.setRewriteFailure(requestID: dictationID, level: level, reason: "empty")
                    debugSink.log(requestID: dictationID, message: "shadow rewrite empty (level=\(level.rawValue))")
                } else {
                    debugSink.setRewrite(requestID: dictationID, level: level, text: rewritten)
                    debugSink.log(requestID: dictationID, message: "shadow rewrite success (level=\(level.rawValue), chars=\(normalized.count))")
                }
            } catch {
                debugSink.setRewriteFailure(
                    requestID: dictationID,
                    level: level,
                    reason: DiagnosticsStore.errorCode(for: error)
                )
                debugSink.log(requestID: dictationID, message: "shadow rewrite failed (level=\(level.rawValue)): \(error.localizedDescription)")
            }
        }
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

/// Ensures a `CheckedContinuation` is resumed exactly once when racing two tasks.
private final class _FinalizeOnceState<T: Sendable>: @unchecked Sendable {
    private let continuation: CheckedContinuation<T, Error>
    private var done = false
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<T, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        continuation.resume(with: result)
    }
}

private func withStreamingFinalizeTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let timeoutNanoseconds: UInt64
    do {
        timeoutNanoseconds = try validatedStreamingTimeoutNanoseconds(seconds: seconds)
    } catch {
        throw StreamingSTTError.finalizationTimeout
    }
    // Use unstructured Tasks rather than withThrowingTaskGroup. TaskGroup waits for all
    // children to drain before returning — so if operation() is stuck in non-cancellation-
    // cooperative I/O (e.g. bridge.finish() blocked on a WebSocket drain), the group would
    // block indefinitely even after the timeout fires. Unstructured Tasks let us abandon
    // the hung operation and return control to the caller immediately on timeout.
    return try await withCheckedThrowingContinuation { continuation in
        let state = _FinalizeOnceState(continuation)
        // operationTask may outlive the continuation if operation() is non-cooperative.
        // The caller's fallback path calls bridge.cancel(), which tears down the
        // underlying WebSocket and unblocks the hung operation eventually.
        let operationTask = Task {
            do {
                state.resume(with: .success(try await operation()))
            } catch {
                state.resume(with: .failure(error))
            }
        }
        Task {
            defer { operationTask.cancel() }
            do {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                state.resume(with: .failure(StreamingSTTError.finalizationTimeout))
            } catch {
                state.resume(with: .failure(error))
            }
        }
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
