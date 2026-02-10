import Foundation
import Testing
import VoxCore
import VoxAppKit

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

    func stop() throws -> URL {
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
final class MockPipeline: DictationProcessing, TranscriptProcessing {
    var processCallCount = 0
    var lastAudioURL: URL?
    var result: String = "mock transcript"
    var shouldThrow = false
    var errorToThrow: Error?
    var processTranscriptCallCount = 0
    var lastTranscript: String?
    var transcriptResult: String = "mock transcript"
    var transcriptError: Error?

    func process(audioURL: URL) async throws -> String {
        processCallCount += 1
        lastAudioURL = audioURL
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
    let processingLevel: ProcessingLevel = .light
    let selectedInputDeviceUID: String? = nil
    let elevenLabsAPIKey: String = ""
    let openRouterAPIKey: String = ""
    let deepgramAPIKey: String = ""
    let openAIAPIKey: String = ""
}

final class MockStreamingSession: StreamingSTTSession, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<PartialTranscript>.Continuation?
    let partialTranscripts: AsyncStream<PartialTranscript>
    private var _sentChunks: [AudioChunk] = []
    var sentChunks: [AudioChunk] { lock.withLock { _sentChunks } }
    var finishResult: Result<String, Error> = .success("streamed transcript")
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
        continuation?.finish()
        switch finishResult {
        case .success(let transcript):
            return transcript
        case .failure(let error):
            throw error
        }
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
            #expect(event.processingLevel == .light)
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
            streamingSTTProvider: streamingProvider,
            streamingFinalizeTimeout: 0.5
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
            streamingSTTProvider: streamingProvider,
            streamingFinalizeTimeout: 0.1
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
            streamingSTTProvider: streamingProvider,
            streamingFinalizeTimeout: 0.5
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
            streamingFinalizeTimeout: 1.0,
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
            streamingFinalizeTimeout: 0.5,
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
            streamingFinalizeTimeout: 0.5,
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

    @Test("Streaming bridge cleanup runs when recorder stop fails")
    @MainActor func test_streamingStopFailure_cleansUpBridge() async {
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
            streamingSTTProvider: streamingProvider,
            streamingFinalizeTimeout: 0.1
        )

        await session.toggleRecording()
        recorder.emitChunk(AudioChunk(pcm16LEData: Data([0x10, 0x11])))
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
}
