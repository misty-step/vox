import Foundation
import Testing
import VoxCore
@testable import VoxMac
@testable import VoxAppKit

// MARK: - Mocks

@MainActor
final class MockRecorder: AudioChunkStreaming {
    var startCallCount = 0
    var stopCallCount = 0
    var levelCallCount = 0
    var shouldThrowOnStart = false
    var shouldThrowOnStop = false
    var stopError: Error?
    private var recordingURL: URL?
    private var audioChunkHandler: (@Sendable (AudioChunk) -> Void)?

    func start(inputDeviceUID: String? = nil) throws {
        startCallCount += 1
        if shouldThrowOnStart {
            throw VoxError.internalError("Mock start failure")
        }
        recordingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mock-\(UUID().uuidString).caf")
        FileManager.default.createFile(atPath: recordingURL!.path, contents: Data())
    }

    func currentLevel() -> (average: Float, peak: Float) {
        levelCallCount += 1
        return (0.5, 0.7)
    }

    func stop() async throws -> URL {
        stopCallCount += 1
        if let stopError {
            throw stopError
        }
        if shouldThrowOnStop {
            throw VoxError.internalError("Mock stop failure")
        }
        guard let url = recordingURL else {
            throw VoxError.internalError("No active recording")
        }
        recordingURL = nil
        return url
    }

    func setAudioChunkHandler(_ handler: (@Sendable (AudioChunk) -> Void)?) {
        audioChunkHandler = handler
    }

    func emitChunk(_ chunk: AudioChunk) {
        audioChunkHandler?(chunk)
    }
}

@MainActor
final class MockEncryptedRecorder: AudioRecording, EncryptedAudioRecording, AudioChunkStreaming {
    var startCallCount = 0
    var stopCallCount = 0
    var levelCallCount = 0
    var shouldThrowOnStart = false
    var shouldThrowOnStop = false
    var stopError: Error?
    private var currentEncryptionKey: Data?
    private(set) var recordingURL: URL
    private var audioChunkHandler: (@Sendable (AudioChunk) -> Void)?
    var consumeEncryptionKeyCallCount = 0
    var discardEncryptionKeyCallCount = 0

    init(recordingURL: URL, encryptionKey: Data) {
        self.recordingURL = recordingURL
        self.currentEncryptionKey = encryptionKey
    }

    func start(inputDeviceUID: String?) throws {
        startCallCount += 1
        if shouldThrowOnStart {
            throw VoxError.internalError("Mock start failure")
        }
    }

    func currentLevel() -> (average: Float, peak: Float) {
        levelCallCount += 1
        return (0.5, 0.7)
    }

    func stop() async throws -> URL {
        stopCallCount += 1
        if let stopError {
            throw stopError
        }
        if shouldThrowOnStop {
            throw VoxError.internalError("Mock stop failure")
        }
        return recordingURL
    }

    func setAudioChunkHandler(_ handler: (@Sendable (AudioChunk) -> Void)?) {
        audioChunkHandler = handler
    }

    func emitChunk(_ chunk: AudioChunk) {
        audioChunkHandler?(chunk)
    }

    func consumeRecordingEncryptionKey() -> Data? {
        consumeEncryptionKeyCallCount += 1
        defer { currentEncryptionKey = nil }
        return currentEncryptionKey
    }

    func discardRecordingEncryptionKey() {
        discardEncryptionKeyCallCount += 1
        currentEncryptionKey = nil
    }

    func ensureKeyCleared() -> Bool {
        currentEncryptionKey == nil
    }
}

@MainActor
final class MockNonStreamingRecorder: AudioRecording {
    var startCallCount = 0
    var stopCallCount = 0
    var levelCallCount = 0
    var shouldThrowOnStart = false
    var shouldThrowOnStop = false
    var stopError: Error?
    private var recordingURL: URL?

    func start(inputDeviceUID: String?) throws {
        startCallCount += 1
        if shouldThrowOnStart {
            throw VoxError.internalError("Mock start failure")
        }
        recordingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mock-non-streaming-\(UUID().uuidString).caf")
        FileManager.default.createFile(atPath: recordingURL!.path, contents: Data())
    }

    func currentLevel() -> (average: Float, peak: Float) {
        levelCallCount += 1
        return (0.5, 0.7)
    }

    func stop() async throws -> URL {
        stopCallCount += 1
        if let stopError {
            throw stopError
        }
        if shouldThrowOnStop {
            throw VoxError.internalError("Mock stop failure")
        }
        guard let url = recordingURL else {
            throw VoxError.internalError("No active recording")
        }
        recordingURL = nil
        return url
    }
}

@MainActor
final class MockHUD: HUDDisplaying {
    var showRecordingCallCount = 0
    var showProcessingCallCount = 0
    var updateLevelsCallCount = 0
    var showSuccessCallCount = 0
    var hideCallCount = 0
    var lastProcessingMessage: String?

    func showRecording(average: Float, peak: Float) {
        showRecordingCallCount += 1
    }

    func updateLevels(average: Float, peak: Float) {
        updateLevelsCallCount += 1
    }

    func showProcessing(message: String) {
        showProcessingCallCount += 1
        lastProcessingMessage = message
    }

    func showSuccess() {
        showSuccessCallCount += 1
    }

    func hide() {
        hideCallCount += 1
    }
}

/// Minimal HUD conformer that does NOT override showSuccess — tests the protocol default.
@MainActor
final class DefaultShowSuccessHUD: HUDDisplaying {
    var hideCallCount = 0
    func showRecording(average: Float, peak: Float) {}
    func updateLevels(average: Float, peak: Float) {}
    func showProcessing(message: String) {}
    func hide() { hideCallCount += 1 }
}

@MainActor
final class MockPipeline: DictationProcessing, TranscriptRecoveryProcessing {
    var processCallCount = 0
    var lastAudioURL: URL?
    var result: String = "mock transcript"
    var shouldThrow = false
    var errorToThrow: Error?
    var onProcessAudio: ((URL) async -> Void)?
    var processTranscriptCallCount = 0
    var processRecoveryCallCount = 0
    var lastTranscript: String?
    var lastRecoveryLevel: ProcessingLevel?
    var lastBypassRewriteCache: Bool?
    var transcriptResult: String = "mock transcript"
    var transcriptError: Error?

    func process(audioURL: URL) async throws -> String {
        processCallCount += 1
        lastAudioURL = audioURL
        if let onProcessAudio {
            await onProcessAudio(audioURL)
        }
        if let errorToThrow {
            throw errorToThrow
        }
        if shouldThrow {
            throw VoxError.noTranscript
        }
        return result
    }

    func process(transcript: String) async throws -> String {
        processTranscriptCallCount += 1
        lastTranscript = transcript
        if let transcriptError {
            throw transcriptError
        }
        return transcriptResult
    }

    func process(
        transcript: String,
        processingLevel: ProcessingLevel,
        bypassRewriteCache: Bool
    ) async throws -> String {
        processRecoveryCallCount += 1
        processTranscriptCallCount += 1
        lastTranscript = transcript
        lastRecoveryLevel = processingLevel
        lastBypassRewriteCache = bypassRewriteCache
        if let transcriptError {
            throw transcriptError
        }
        return transcriptResult
    }
}

@MainActor
final class MockSessionExtension: SessionExtension {
    var authorizeCallCount = 0
    var shouldRejectAuthorize = false
    var completionEvents: [DictationUsageEvent] = []
    var failureReasons: [String] = []

    func authorizeRecordingStart() async throws {
        authorizeCallCount += 1
        if shouldRejectAuthorize {
            throw VoxError.internalError("Not authorized")
        }
    }

    func didCompleteDictation(event: DictationUsageEvent) async {
        completionEvents.append(event)
    }

    func didFailDictation(reason: String) async {
        failureReasons.append(reason)
    }
}

@MainActor
final class MockPreferencesStore: PreferencesReading {
    let processingLevel: ProcessingLevel = .clean
    let selectedInputDeviceUID: String? = nil
    let elevenLabsAPIKey: String = ""
    let openRouterAPIKey: String = ""
    let deepgramAPIKey: String = ""
    let geminiAPIKey: String = ""
}

final class MockStreamingSession: StreamingSTTSession, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<PartialTranscript>.Continuation?
    let partialTranscripts: AsyncStream<PartialTranscript>
    private var _sentChunks: [AudioChunk] = []
    var sentChunks: [AudioChunk] { lock.withLock { _sentChunks } }
    var finishResult: Result<String, Error> = .success("streamed transcript")
    var finishDelay: TimeInterval?
    /// When true, finishDelay uses Thread.sleep (blocks cooperative thread pool, ignores Swift
    /// task cancellation) to simulate non-cooperative I/O like a hung WebSocket drain.
    var finishBlockingThread: Bool = false
    private var _expectedChunkCountAtFinish: Int?
    var expectedChunkCountAtFinish: Int? {
        get { lock.withLock { _expectedChunkCountAtFinish } }
        set { lock.withLock { _expectedChunkCountAtFinish = newValue } }
    }
    private var _cancelCallCount = 0
    var cancelCallCount: Int { lock.withLock { _cancelCallCount } }

    init() {
        var continuation: AsyncStream<PartialTranscript>.Continuation?
        self.partialTranscripts = AsyncStream<PartialTranscript> { streamContinuation in
            continuation = streamContinuation
        }
        self.continuation = continuation
    }

    func sendAudioChunk(_ chunk: AudioChunk) async throws {
        lock.withLock {
            _sentChunks.append(chunk)
        }
    }

    func finish() async throws -> String {
        let expectedChunkCount = lock.withLock { _expectedChunkCountAtFinish }
        if let expectedChunkCount {
            let sentCount = lock.withLock { _sentChunks.count }
            if sentCount < expectedChunkCount {
                throw StreamingSTTError.invalidState(
                    "finish before queued chunks drained (\(sentCount)/\(expectedChunkCount))"
                )
            }
        }
        if let finishDelay {
            if finishBlockingThread {
                // Simulate non-cooperative I/O: uses DispatchQueue (not Swift concurrency),
                // so Swift task cancellation is ignored. The delay runs to completion
                // regardless of whether the calling Task is cancelled.
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + finishDelay) {
                        continuation.resume()
                    }
                }
            } else {
                try await Task.sleep(nanoseconds: UInt64(finishDelay * 1_000_000_000))
            }
        }
        continuation?.finish()
        switch finishResult {
        case .success(let transcript):
            return transcript
        case .failure(let error):
            throw error
        }
    }

    func emitPartial(text: String, isFinal: Bool = false) {
        continuation?.yield(PartialTranscript(text: text, isFinal: isFinal))
    }

    func cancel() async {
        lock.withLock {
            _cancelCallCount += 1
        }
        continuation?.finish()
    }
}

final class MockStreamingProvider: StreamingSTTProvider, @unchecked Sendable {
    private let lock = NSLock()
    var makeSessionError: Error?
    var makeSessionDelay: TimeInterval?
    var session: MockStreamingSession
    private var _makeSessionCallCount = 0
    var makeSessionCallCount: Int { lock.withLock { _makeSessionCallCount } }

    init(session: MockStreamingSession = MockStreamingSession()) {
        self.session = session
    }

    func makeSession() async throws -> any StreamingSTTSession {
        lock.withLock {
            _makeSessionCallCount += 1
        }
        if let delay = makeSessionDelay {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if let makeSessionError {
            throw makeSessionError
        }
        return session
    }
}

// MARK: - Tests

@Suite("VoxSession DI")
struct VoxSessionDITests {

    @Test("Default init compiles without arguments")
    @MainActor func defaultInit() {
        // Verify the default init still works (no arguments required)
        // We can't fully exercise it without real audio hardware,
        // but compilation + instantiation proves backward compat
        let session = VoxSession()
        #expect(session.state == .idle)
    }

    @Test("Streaming kill switch parsing")
    func streamingKillSwitchParsing() {
        #expect(VoxSession.isStreamingAllowed(environment: [:]))
        #expect(!VoxSession.isStreamingAllowed(environment: ["VOX_DISABLE_STREAMING_STT": "1"]))
        #expect(!VoxSession.isStreamingAllowed(environment: ["VOX_DISABLE_STREAMING_STT": " true "]))
        #expect(!VoxSession.isStreamingAllowed(environment: ["VOX_DISABLE_STREAMING_STT": "YES"]))
        #expect(VoxSession.isStreamingAllowed(environment: ["VOX_DISABLE_STREAMING_STT": "0"]))
    }

    @Test("Hedged routing opt-in parsing")
    func hedgedRoutingParsing() {
        #expect(!VoxSession.isHedgedRoutingSelected(environment: [:]))
        #expect(VoxSession.isHedgedRoutingSelected(environment: ["VOX_STT_ROUTING": "hedged"]))
        #expect(VoxSession.isHedgedRoutingSelected(environment: ["VOX_STT_ROUTING": " HEDGED "]))
        #expect(!VoxSession.isHedgedRoutingSelected(environment: ["VOX_STT_ROUTING": "sequential"]))
        #expect(!VoxSession.isHedgedRoutingSelected(environment: ["VOX_STT_ROUTING": ""]))
    }

    @Test("Recorder backend selection parsing")
    func recorderBackendParsing() {
        #expect(!VoxSession.isRecorderBackendSelected(environment: [:]))
        #expect(VoxSession.isRecorderBackendSelected(environment: ["VOX_AUDIO_BACKEND": "recorder"]))
        #expect(VoxSession.isRecorderBackendSelected(environment: ["VOX_AUDIO_BACKEND": " RECORDER "]))
        #expect(!VoxSession.isRecorderBackendSelected(environment: ["VOX_AUDIO_BACKEND": "engine"]))
        #expect(!VoxSession.isRecorderBackendSelected(environment: ["VOX_AUDIO_BACKEND": "something-else"]))
    }

    @Test("Injected recorder is used")
    @MainActor func injectedRecorder() {
        let recorder = MockRecorder()
        let session = VoxSession(recorder: recorder)
        #expect(session.state == .idle)
        // Recorder is stored — verified by the fact that injection compiles
        // Actual recording requires microphone permission (can't unit test)
    }

    @Test("Injected HUD is used")
    @MainActor func injectedHUD() {
        let hud = MockHUD()
        let session = VoxSession(hud: hud)
        #expect(session.state == .idle)
    }

    @Test("Injected pipeline is used")
    @MainActor func injectedPipeline() {
        let pipeline = MockPipeline()
        let session = VoxSession(pipeline: pipeline)
        #expect(session.state == .idle)
    }

    @Test("Full injection with all dependencies")
    @MainActor func fullInjection() {
        let recorder = MockRecorder()
        let hud = MockHUD()
        let pipeline = MockPipeline()
        let prefs = MockPreferencesStore()
        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: hud,
            prefs: prefs
        )
        #expect(session.state == .idle)
    }

    @Test("Injected preferences are used")
    @MainActor func injectedPreferences() {
        let prefs = MockPreferencesStore()
        let session = VoxSession(prefs: prefs)
        #expect(session.state == .idle)
    }

    @Test("HUDDisplaying default showProcessing message")
    @MainActor func hudDefaultMessage() {
        let hud = MockHUD()
        hud.showProcessing()
        #expect(hud.lastProcessingMessage == "Transcribing")
    }

    @Test("HUDDisplaying default showSuccess calls hide")
    @MainActor func hudDefaultShowSuccess() {
        // Verify protocol default: showSuccess() falls back to hide()
        // MockHUD overrides showSuccess, so use a minimal conformer
        let hud = DefaultShowSuccessHUD()
        hud.showSuccess()
        #expect(hud.hideCallCount == 1)
    }

    @Test("DictationPipeline conforms to DictationProcessing")
    func pipelineConformance() {
        // Verify at compile time that DictationPipeline conforms
        let _: DictationProcessing.Type = DictationPipeline.self
    }

    @Test("SessionExtension receives usage event on successful dictation")
    @MainActor func sessionExtensionCompletion() async {
        let recorder = MockRecorder()
        let hud = MockHUD()
        let pipeline = MockPipeline()
        pipeline.result = "hello world"
        let prefs = MockPreferencesStore()
        let sessionExtension = MockSessionExtension()
        var errors: [String] = []

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: hud,
            prefs: prefs,
            sessionExtension: sessionExtension,
            requestMicrophoneAccess: { true },
            errorPresenter: { errors.append($0) }
        )

        await session.toggleRecording()
        await session.toggleRecording()

        #expect(sessionExtension.authorizeCallCount == 1)
        #expect(sessionExtension.completionEvents.count == 1)
        #expect(sessionExtension.failureReasons.isEmpty)
        #expect(errors.isEmpty)

        if let event = sessionExtension.completionEvents.first {
            #expect(event.processingLevel == .clean)
            #expect(event.outputCharacterCount == pipeline.result.count)
            #expect(event.recordingDuration >= 0)
        }
    }

    @Test("SessionExtension observes microphone denial")
    @MainActor func sessionExtensionMicrophoneDenied() async {
        let recorder = MockRecorder()
        let sessionExtension = MockSessionExtension()
        var errors: [String] = []

        let session = VoxSession(
            recorder: recorder,
            pipeline: MockPipeline(),
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            sessionExtension: sessionExtension,
            requestMicrophoneAccess: { false },
            errorPresenter: { errors.append($0) }
        )

        await session.toggleRecording()

        #expect(sessionExtension.authorizeCallCount == 1)
        #expect(sessionExtension.failureReasons == ["microphone_permission_denied"])
        #expect(recorder.startCallCount == 0)
        #expect(errors.count == 1)
        #expect(session.state == .idle)
    }

    @Test("SessionExtension observes processing cancellation")
    @MainActor func sessionExtensionProcessingCancellation() async {
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        pipeline.errorToThrow = CancellationError()
        let sessionExtension = MockSessionExtension()
        var errors: [String] = []

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            sessionExtension: sessionExtension,
            requestMicrophoneAccess: { true },
            errorPresenter: { errors.append($0) }
        )

        await session.toggleRecording()
        await session.toggleRecording()

        #expect(sessionExtension.failureReasons.contains("processing_cancelled"))
        #expect(sessionExtension.completionEvents.isEmpty)
        #expect(errors.isEmpty)
        #expect(session.state == .idle)
    }

    @Test("SessionExtension observes recording tap failure separately")
    @MainActor func sessionExtensionRecordingTapFailure() async {
        let recorder = MockRecorder()
        recorder.stopError = VoxError.audioCaptureFailed("Audio capture failed: tap conversion/write error")
        let pipeline = MockPipeline()
        let sessionExtension = MockSessionExtension()
        var errors: [String] = []

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            sessionExtension: sessionExtension,
            requestMicrophoneAccess: { true },
            errorPresenter: { errors.append($0) }
        )

        await session.toggleRecording()
        await session.toggleRecording()

        #expect(sessionExtension.failureReasons.contains("recording_tap_failed"))
        #expect(!sessionExtension.failureReasons.contains("recording_stop_failed"))
        #expect(errors.count == 1)
        #expect(pipeline.processCallCount == 0)
        #expect(session.state == .idle)
    }

    @Test("SessionExtension can deny start before microphone request")
    @MainActor func sessionExtensionAuthorizeFailure() async {
        let recorder = MockRecorder()
        let sessionExtension = MockSessionExtension()
        sessionExtension.shouldRejectAuthorize = true
        var errors: [String] = []
        var permissionChecks = 0

        let session = VoxSession(
            recorder: recorder,
            pipeline: MockPipeline(),
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            sessionExtension: sessionExtension,
            requestMicrophoneAccess: {
                permissionChecks += 1
                return true
            },
            errorPresenter: { errors.append($0) }
        )

        await session.toggleRecording()

        #expect(sessionExtension.authorizeCallCount == 1)
        #expect(permissionChecks == 0)
        #expect(recorder.startCallCount == 0)
        #expect(errors.count == 1)
        #expect(session.state == .idle)
    }

    @Test("Streaming finalize success uses transcript processing path")
    @MainActor func test_streamingFinalizeSuccess_usesTranscriptProcessing() async {
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        pipeline.result = "batch transcript"
        pipeline.transcriptResult = "streamed transcript output"
        let streamingSession = MockStreamingSession()
        streamingSession.finishResult = .success("streamed transcript")
        let streamingProvider = MockStreamingProvider(session: streamingSession)

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            streamingSTTProvider: streamingProvider
        )

        await session.toggleRecording()
        recorder.emitChunk(AudioChunk(pcm16LEData: Data([0x00, 0x01])))
        await session.toggleRecording()

        #expect(streamingProvider.makeSessionCallCount == 1)
        #expect(streamingSession.sentChunks.count == 1)
        #expect(pipeline.processTranscriptCallCount == 1)
        #expect(pipeline.lastTranscript == "streamed transcript")
        #expect(pipeline.processCallCount == 0)
        #expect(session.state == .idle)
    }

    @Test("Recorder without chunk streaming uses batch path even with streaming provider")
    @MainActor func test_nonStreamingRecorder_skipsStreamingAndUsesBatchPath() async {
        let recorder = MockNonStreamingRecorder()
        let pipeline = MockPipeline()
        pipeline.result = "batch transcript"
        let streamingSession = MockStreamingSession()
        let streamingProvider = MockStreamingProvider(session: streamingSession)

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            streamingSTTProvider: streamingProvider
        )

        await session.toggleRecording()
        await session.toggleRecording()

        #expect(streamingProvider.makeSessionCallCount == 0)
        #expect(pipeline.processCallCount == 1)
        #expect(pipeline.processTranscriptCallCount == 0)
        #expect(session.state == .idle)
    }

    @Test("Streaming finalize uses latest partial transcript when final is empty")
    @MainActor func test_streamingFinalizeEmptyFinal_usesLatestPartialTranscript() async {
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        pipeline.transcriptResult = "partial fallback output"
        let streamingSession = MockStreamingSession()
        streamingSession.finishResult = .success("   ")
        let streamingProvider = MockStreamingProvider(session: streamingSession)

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            streamingSTTProvider: streamingProvider
        )

        await session.toggleRecording()
        recorder.emitChunk(AudioChunk(pcm16LEData: Data([0x00, 0x01])))
        streamingSession.emitPartial(text: "draft")
        streamingSession.emitPartial(text: "stable partial transcript", isFinal: true)
        await session.toggleRecording()

        #expect(streamingProvider.makeSessionCallCount == 1)
        #expect(pipeline.processTranscriptCallCount == 1)
        #expect(pipeline.lastTranscript == "stable partial transcript")
        #expect(pipeline.processCallCount == 0)
        #expect(session.state == .idle)
    }

    @Test("Streaming finalize failure falls back to batch processing")
    @MainActor func test_streamingFinalizeFailure_fallsBackToBatch() async {
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        pipeline.result = "batch fallback transcript"
        let streamingSession = MockStreamingSession()
        streamingSession.finishResult = .failure(StreamingSTTError.finalizationTimeout)
        let streamingProvider = MockStreamingProvider(session: streamingSession)

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            streamingSTTProvider: streamingProvider
        )

        await session.toggleRecording()
        recorder.emitChunk(AudioChunk(pcm16LEData: Data([0x00, 0x01])))
        await session.toggleRecording()

        #expect(streamingProvider.makeSessionCallCount == 1)
        #expect(pipeline.processCallCount == 1)
        #expect(pipeline.processTranscriptCallCount == 0)
        #expect(streamingSession.cancelCallCount == 1)
        #expect(session.state == .idle)
    }

    @Test("Streaming finalize timeout falls back to batch processing")
    @MainActor func test_streamingFinalizeTimeout_fallsBackToBatch() async {
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        pipeline.result = "batch timeout fallback transcript"
        let streamingSession = MockStreamingSession()
        streamingSession.finishDelay = 5.0
        streamingSession.finishResult = .success("late streamed transcript")
        let streamingProvider = MockStreamingProvider(session: streamingSession)
        let startTime = CFAbsoluteTimeGetCurrent()

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            streamingSTTProvider: streamingProvider,
            streamingFinalizeTimeout: 0.1
        )

        await session.toggleRecording()
        recorder.emitChunk(AudioChunk(pcm16LEData: Data([0x00, 0x01])))
        await session.toggleRecording()
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(streamingProvider.makeSessionCallCount == 1)
        #expect(pipeline.processCallCount == 1)
        #expect(pipeline.processTranscriptCallCount == 0)
        #expect(streamingSession.cancelCallCount == 1)
        #expect(elapsed < 2.0)
        #expect(session.state == .idle)
    }

    @Test("Streaming finalize timeout unblocks when operation cannot be cancelled")
    @MainActor func test_streamingFinalizeTimeout_unblocksNonCooperativeOperation() async {
        // Verifies that withStreamingFinalizeTimeout uses unstructured Tasks (not
        // withThrowingTaskGroup) so the caller is unblocked even when bridge.finish()
        // ignores task cancellation (e.g. blocked in synchronous C/WebSocket I/O).
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        pipeline.result = "batch timeout fallback transcript"
        let streamingSession = MockStreamingSession()
        streamingSession.finishDelay = 3.0
        streamingSession.finishBlockingThread = true  // Thread.sleep; ignores Swift cancellation
        let streamingProvider = MockStreamingProvider(session: streamingSession)
        let startTime = CFAbsoluteTimeGetCurrent()

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            streamingSTTProvider: streamingProvider,
            streamingFinalizeTimeout: 0.1
        )

        await session.toggleRecording()
        recorder.emitChunk(AudioChunk(pcm16LEData: Data([0x00, 0x01])))
        await session.toggleRecording()
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(pipeline.processCallCount == 1)
        #expect(elapsed < 2.0)
        #expect(session.state == .idle)
    }

    @Test("Streaming finalize drains queued chunks before finish")
    @MainActor func test_streamingFinalize_drainsQueuedChunksBeforeFinish() async {
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        pipeline.transcriptResult = "streamed transcript output"
        let streamingSession = MockStreamingSession()
        streamingSession.expectedChunkCountAtFinish = 6
        streamingSession.finishResult = .success("streamed transcript")
        let streamingProvider = MockStreamingProvider(session: streamingSession)

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            streamingSTTProvider: streamingProvider
        )

        await session.toggleRecording()
        for index in 0..<6 {
            let value = UInt8(index)
            recorder.emitChunk(AudioChunk(pcm16LEData: Data([value, value &+ 1])))
        }
        await session.toggleRecording()

        #expect(streamingSession.sentChunks.count == 6)
        #expect(pipeline.processTranscriptCallCount == 1)
        #expect(streamingSession.cancelCallCount == 0)
        #expect(session.state == .idle)
    }

    @Test("Streaming setup buffers chunks during slow session creation")
    @MainActor func test_streamingSetupBuffering_chunksBufferedAndFlushed() async {
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        pipeline.transcriptResult = "buffered transcript output"
        let streamingSession = MockStreamingSession()
        streamingSession.expectedChunkCountAtFinish = 3
        streamingSession.finishResult = .success("buffered transcript")
        let streamingProvider = MockStreamingProvider(session: streamingSession)
        streamingProvider.makeSessionDelay = 0.2

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            streamingSTTProvider: streamingProvider,
            streamingSetupTimeout: 2.0
        )

        await session.toggleRecording()

        for i in 0..<3 {
            let val = UInt8(i)
            recorder.emitChunk(AudioChunk(pcm16LEData: Data([val, val &+ 1])))
        }

        await session.toggleRecording()

        #expect(streamingProvider.makeSessionCallCount == 1)
        #expect(streamingSession.sentChunks.count == 3)
        #expect(pipeline.processTranscriptCallCount == 1)
        #expect(pipeline.lastTranscript == "buffered transcript")
        #expect(session.state == .idle)
    }

    @Test("Streaming setup failure falls back to batch processing")
    @MainActor func test_streamingSetupFailure_fallsBackToBatch() async {
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        pipeline.result = "batch fallback"
        let streamingSession = MockStreamingSession()
        let streamingProvider = MockStreamingProvider(session: streamingSession)
        streamingProvider.makeSessionError = StreamingSTTError.connectionFailed("test error")

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            streamingSTTProvider: streamingProvider,
            streamingSetupTimeout: 1.0
        )

        await session.toggleRecording()
        recorder.emitChunk(AudioChunk(pcm16LEData: Data([0x00, 0x01])))
        await session.toggleRecording()

        #expect(streamingProvider.makeSessionCallCount == 1)
        #expect(pipeline.processCallCount == 1)
        #expect(pipeline.processTranscriptCallCount == 0)
        #expect(session.state == .idle)
    }

    @Test("Streaming setup timeout falls back to batch processing")
    @MainActor func test_streamingSetupTimeout_fallsBackToBatch() async {
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        pipeline.result = "batch timeout fallback"
        let streamingSession = MockStreamingSession()
        let streamingProvider = MockStreamingProvider(session: streamingSession)
        streamingProvider.makeSessionDelay = 5.0

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            streamingSTTProvider: streamingProvider,
            streamingSetupTimeout: 0.1
        )

        await session.toggleRecording()
        recorder.emitChunk(AudioChunk(pcm16LEData: Data([0x00, 0x01])))
        await session.toggleRecording()

        #expect(streamingProvider.makeSessionCallCount == 1)
        #expect(pipeline.processCallCount == 1)
        #expect(pipeline.processTranscriptCallCount == 0)
        #expect(session.state == .idle)
    }

    @Test("Batch processing decrypts encrypted recordings before transcription")
    @MainActor func test_batchProcessing_decryptsEncryptedRecordingBeforeTranscription() async throws {
        let plainURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vox-session-test-\(UUID().uuidString).caf")
        let encryptionKey = Data(repeating: 0xA1, count: 32)
        let encryptedURL = plainURL.appendingPathExtension(AudioFileEncryption.encryptedFileExtension)

        defer {
            try? FileManager.default.removeItem(at: plainURL)
            try? FileManager.default.removeItem(at: encryptedURL)
        }

        try Data([0x01, 0x02, 0x03]).write(to: plainURL)
        try await AudioFileEncryption.encrypt(plainURL: plainURL, outputURL: encryptedURL, key: encryptionKey)
        try? FileManager.default.removeItem(at: plainURL)

        let recorder = MockEncryptedRecorder(recordingURL: encryptedURL, encryptionKey: encryptionKey)
        let pipeline = MockPipeline()
        pipeline.result = "decrypted transcript"
        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in }
        )

        await session.toggleRecording()
        await session.toggleRecording()

        #expect(pipeline.processCallCount == 1)
        #expect(pipeline.lastAudioURL == plainURL)
        #expect(AudioFileEncryption.isEncrypted(url: pipeline.lastAudioURL ?? URL(fileURLWithPath: "")) == false)
        #expect(!FileManager.default.fileExists(atPath: plainURL.path))
        #expect(!FileManager.default.fileExists(atPath: encryptedURL.path))
        #expect(recorder.ensureKeyCleared())
        #expect(recorder.consumeEncryptionKeyCallCount == 1)
        #expect(session.state == .idle)
    }

    @Test("Batch processing failure zeroizes encryption key")
    @MainActor func test_batchProcessingFailure_zeroizesEncryptionKey() async throws {
        let plainURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vox-session-failure-\(UUID().uuidString).caf")
        let encryptionKey = Data(repeating: 0xB2, count: 32)
        let encryptedURL = plainURL.appendingPathExtension(AudioFileEncryption.encryptedFileExtension)

        defer {
            try? FileManager.default.removeItem(at: plainURL)
            try? FileManager.default.removeItem(at: encryptedURL)
        }

        try Data([0x10, 0x11, 0x12]).write(to: plainURL)
        try await AudioFileEncryption.encrypt(plainURL: plainURL, outputURL: encryptedURL, key: encryptionKey)
        try? FileManager.default.removeItem(at: plainURL)

        let recorder = MockEncryptedRecorder(recordingURL: encryptedURL, encryptionKey: encryptionKey)
        let pipeline = MockPipeline()
        pipeline.errorToThrow = VoxError.internalError("stt failed")
        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in }
        )

        await session.toggleRecording()
        await session.toggleRecording()

        #expect(recorder.ensureKeyCleared())
        #expect(recorder.consumeEncryptionKeyCallCount == 1)
        #expect(session.state == .idle)
    }

    @Test("Streaming fallback decrypts encrypted recording before batch transcription")
    @MainActor func test_streamingFallback_decryptsEncryptedRecordingBeforeBatchTranscription() async throws {
        let plainURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vox-session-streaming-fallback-\(UUID().uuidString).caf")
        let encryptionKey = Data(repeating: 0xC3, count: 32)
        let encryptedURL = plainURL.appendingPathExtension(AudioFileEncryption.encryptedFileExtension)

        defer {
            try? FileManager.default.removeItem(at: plainURL)
            try? FileManager.default.removeItem(at: encryptedURL)
        }

        try Data([0x21, 0x22, 0x23]).write(to: plainURL)
        try await AudioFileEncryption.encrypt(plainURL: plainURL, outputURL: encryptedURL, key: encryptionKey)
        try? FileManager.default.removeItem(at: plainURL)

        let recorder = MockEncryptedRecorder(recordingURL: encryptedURL, encryptionKey: encryptionKey)
        let pipeline = MockPipeline()
        pipeline.result = "batch fallback transcript"
        let streamingSession = MockStreamingSession()
        streamingSession.finishResult = .failure(StreamingSTTError.finalizationTimeout)
        let streamingProvider = MockStreamingProvider(session: streamingSession)
        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            streamingSTTProvider: streamingProvider
        )

        await session.toggleRecording()
        recorder.emitChunk(AudioChunk(pcm16LEData: Data([0x00, 0x01])))
        await session.toggleRecording()

        #expect(streamingProvider.makeSessionCallCount == 1)
        #expect(pipeline.processCallCount == 1)
        #expect(pipeline.lastAudioURL == plainURL)
        #expect(streamingSession.cancelCallCount == 1)
        #expect(session.state == .idle)
    }

    @Test("Batch processing with missing decryption key throws error")
    @MainActor func test_batchProcessingMissingKey_handlesErrorWithoutRunningPipeline() async throws {
        let plainURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vox-session-missing-key-\(UUID().uuidString).caf")
        let encryptionKey = Data(repeating: 0xD4, count: 32)
        let encryptedURL = plainURL.appendingPathExtension(AudioFileEncryption.encryptedFileExtension)

        defer {
            try? FileManager.default.removeItem(at: plainURL)
            try? FileManager.default.removeItem(at: encryptedURL)
        }

        try Data([0x31, 0x32, 0x33]).write(to: plainURL)
        try await AudioFileEncryption.encrypt(plainURL: plainURL, outputURL: encryptedURL, key: encryptionKey)
        try? FileManager.default.removeItem(at: plainURL)

        let recorder = MockEncryptedRecorder(recordingURL: encryptedURL, encryptionKey: encryptionKey)
        recorder.discardRecordingEncryptionKey()
        let pipeline = MockPipeline()
        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in }
        )

        await session.toggleRecording()
        await session.toggleRecording()

        #expect(session.state == .idle)
        #expect(pipeline.processCallCount == 0)
    }

    @Test("Encrypted recorder stop failure discards encryption key")
    @MainActor func test_encryptedRecorderStopFailure_discardsEncryptionKey() async throws {
        let encryptedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vox-stop-fail-\(UUID().uuidString).caf.enc")
        FileManager.default.createFile(atPath: encryptedURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: encryptedURL) }

        let recorder = MockEncryptedRecorder(
            recordingURL: encryptedURL,
            encryptionKey: AudioFileEncryption.randomKey()
        )
        recorder.stopError = VoxError.internalError("stop failed")
        var errors: [String] = []
        let session = VoxSession(
            recorder: recorder,
            pipeline: MockPipeline(),
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { errors.append($0) }
        )

        await session.toggleRecording()
        await session.toggleRecording()

        #expect(recorder.discardEncryptionKeyCallCount == 1)
        #expect(recorder.consumeEncryptionKeyCallCount == 0)
        #expect(recorder.ensureKeyCleared())
        #expect(errors.count == 1)
        #expect(session.state == .idle)
    }

    @Test("Streaming bridge cleanup runs when recorder stop fails")
    @MainActor func test_streamingStopFailure_cleansUpBridge() async throws {
        let recorder = MockRecorder()
        recorder.stopError = VoxError.internalError("stop failed")
        let pipeline = MockPipeline()
        let streamingSession = MockStreamingSession()
        let streamingProvider = MockStreamingProvider(session: streamingSession)
        var errors: [String] = []

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { errors.append($0) },
            streamingSTTProvider: streamingProvider
        )

        await session.toggleRecording()
        recorder.emitChunk(AudioChunk(pcm16LEData: Data([0x10, 0x11])))
        // Allow streaming setup task to complete before stopping
        try await Task.sleep(nanoseconds: 50_000_000)
        await session.toggleRecording()

        let sentBefore = streamingSession.sentChunks.count
        recorder.emitChunk(AudioChunk(pcm16LEData: Data([0x20, 0x21])))

        #expect(streamingProvider.makeSessionCallCount == 1)
        #expect(streamingSession.cancelCallCount == 1)
        #expect(streamingSession.sentChunks.count == sentBefore)
        #expect(pipeline.processCallCount == 0)
        #expect(errors.count == 1)
        #expect(session.state == .idle)
    }

    @Test("Copy last raw transcript uses recovery snapshot")
    @MainActor func copyLastRawTranscript_usesRecoverySnapshot() async {
        let recoveryStore = LastDictationRecoveryStore(ttlSeconds: 600)
        await recoveryStore.store(
            rawTranscript: "raw transcript text",
            finalText: "formatted output text",
            processingLevel: .polish
        )

        var copiedText: String?
        var errors: [String] = []
        let session = VoxSession(
            recorder: MockRecorder(),
            pipeline: MockPipeline(),
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { errors.append($0) },
            copyRawTranscriptToClipboard: { copiedText = $0 },
            recoveryStore: recoveryStore
        )

        await session.copyLastRawTranscript()

        #expect(copiedText == "raw transcript text")
        #expect(errors.isEmpty)
    }

    @Test("Copy last raw transcript shows error when unavailable")
    @MainActor func copyLastRawTranscript_missingSnapshot_showsError() async {
        let recoveryStore = LastDictationRecoveryStore(ttlSeconds: 600)

        var copiedText: String?
        var errors: [String] = []
        let session = VoxSession(
            recorder: MockRecorder(),
            pipeline: MockPipeline(),
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { errors.append($0) },
            copyRawTranscriptToClipboard: { copiedText = $0 },
            recoveryStore: recoveryStore
        )

        await session.copyLastRawTranscript()

        #expect(copiedText == nil)
        #expect(errors.count == 1)
    }

    @Test("Retry last rewrite uses stored level and bypasses rewrite cache")
    @MainActor func retryLastRewrite_usesStoredLevelAndBypassesCache() async {
        let recoveryStore = LastDictationRecoveryStore(ttlSeconds: 600)
        await recoveryStore.store(
            rawTranscript: "retry transcript text",
            finalText: "previous output",
            processingLevel: .polish
        )

        let pipeline = MockPipeline()
        pipeline.transcriptResult = "retried output"
        let hud = MockHUD()
        var errors: [String] = []
        let session = VoxSession(
            recorder: MockRecorder(),
            pipeline: pipeline,
            hud: hud,
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { errors.append($0) },
            recoveryStore: recoveryStore
        )

        await session.retryLastRewrite()

        #expect(pipeline.processRecoveryCallCount == 1)
        #expect(pipeline.lastTranscript == "retry transcript text")
        #expect(pipeline.lastRecoveryLevel == .polish)
        #expect(pipeline.lastBypassRewriteCache == true)
        #expect(hud.showProcessingCallCount == 1)
        #expect(hud.showSuccessCallCount == 1)
        #expect(errors.isEmpty)
        #expect(session.state == .idle)
    }

    @Test("Retry last rewrite shows error when unavailable")
    @MainActor func retryLastRewrite_missingSnapshot_showsError() async {
        let recoveryStore = LastDictationRecoveryStore(ttlSeconds: 600)
        let hud = MockHUD()
        var errors: [String] = []
        let session = VoxSession(
            recorder: MockRecorder(),
            pipeline: MockPipeline(),
            hud: hud,
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { errors.append($0) },
            recoveryStore: recoveryStore
        )

        await session.retryLastRewrite()

        #expect(errors.count == 1)
        #expect(hud.hideCallCount == 1)
        #expect(session.state == .idle)
    }

    @Test("onRecoveryAvailabilityChange called true after successful dictation")
    @MainActor func test_onRecoveryAvailabilityChange_calledTrue_afterSuccessfulDictation() async {
        let recoveryStore = LastDictationRecoveryStore(ttlSeconds: 600)
        let pipeline = MockPipeline()
        pipeline.onProcessAudio = { _ in
            await recoveryStore.store(
                rawTranscript: "raw transcript",
                finalText: "processed transcript",
                processingLevel: .clean
            )
        }

        var recoveryAvailabilityEvents: [Bool] = []
        let session = VoxSession(
            recorder: MockRecorder(),
            pipeline: pipeline,
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            recoveryStore: recoveryStore
        )
        session.onRecoveryAvailabilityChange = { available in
            recoveryAvailabilityEvents.append(available)
        }

        await session.toggleRecording()
        await session.toggleRecording()

        #expect(recoveryAvailabilityEvents == [true])
    }

    @Test("onRecoveryAvailabilityChange fires false when copyLastRawTranscript finds empty store")
    @MainActor func test_onRecoveryAvailabilityChange_calledFalse_onCopyWithEmptyStore() async {
        let recoveryStore = LastDictationRecoveryStore(ttlSeconds: 600)
        var recoveryAvailabilityEvents: [Bool] = []
        let session = VoxSession(
            recorder: MockRecorder(),
            pipeline: MockPipeline(),
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            recoveryStore: recoveryStore
        )
        session.onRecoveryAvailabilityChange = { available in
            recoveryAvailabilityEvents.append(available)
        }

        await session.copyLastRawTranscript()

        #expect(recoveryAvailabilityEvents == [false])
    }

    @Test("onRecoveryAvailabilityChange fires false when retryLastRewrite finds empty store")
    @MainActor func test_onRecoveryAvailabilityChange_calledFalse_onRetryWithEmptyStore() async {
        let recoveryStore = LastDictationRecoveryStore(ttlSeconds: 600)
        var recoveryAvailabilityEvents: [Bool] = []
        let session = VoxSession(
            recorder: MockRecorder(),
            pipeline: MockPipeline(),
            hud: MockHUD(),
            prefs: MockPreferencesStore(),
            requestMicrophoneAccess: { true },
            errorPresenter: { _ in },
            recoveryStore: recoveryStore
        )
        session.onRecoveryAvailabilityChange = { available in
            recoveryAvailabilityEvents.append(available)
        }

        await session.retryLastRewrite()

        #expect(recoveryAvailabilityEvents == [false])
    }
}
