import Foundation
import Testing
@testable import VoxCore
@testable import VoxAppKit

// MARK: - Mocks

final class MockSTTProvider: STTProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _results: [Result<String, Error>] = []
    var results: [Result<String, Error>] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _results
        }
        set {
            lock.lock()
            _results = newValue
            lock.unlock()
        }
    }
    private var _callCount = 0
    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }
    private var _lastAudioURL: URL?
    var lastAudioURL: URL? {
        lock.lock()
        defer { lock.unlock() }
        return _lastAudioURL
    }
    private var _delay: TimeInterval = 0
    var delay: TimeInterval {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _delay
        }
        set {
            lock.lock()
            _delay = newValue
            lock.unlock()
        }
    }

    func transcribe(audioURL: URL) async throws -> String {
        lock.lock()
        _callCount += 1
        let index = _callCount - 1
        _lastAudioURL = audioURL
        let currentDelay = _delay
        let resultsSnapshot = _results
        lock.unlock()

        if currentDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
        }

        guard index < resultsSnapshot.count else {
            throw STTError.unknown("No more mock results")
        }
        switch resultsSnapshot[index] {
        case .success(let text):
            return text
        case .failure(let error):
            throw error
        }
    }
}

final class MockRewriteProvider: RewriteProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _results: [Result<String, Error>] = []
    var results: [Result<String, Error>] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _results
        }
        set {
            lock.lock()
            _results = newValue
            lock.unlock()
        }
    }
    private var _callCount = 0
    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }
    private var _lastTranscript: String?
    var lastTranscript: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastTranscript
    }
    private var _lastPrompt: String?
    var lastPrompt: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastPrompt
    }
    private var _lastModel: String?
    var lastModel: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastModel
    }
    private var _delay: TimeInterval = 0
    var delay: TimeInterval {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _delay
        }
        set {
            lock.lock()
            _delay = newValue
            lock.unlock()
        }
    }

    func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        lock.lock()
        _callCount += 1
        let index = _callCount - 1
        _lastTranscript = transcript
        _lastPrompt = systemPrompt
        _lastModel = model
        let currentDelay = _delay
        let resultsSnapshot = _results
        lock.unlock()

        if currentDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
        }

        guard index < resultsSnapshot.count else {
            throw RewriteError.unknown("No more mock results")
        }
        switch resultsSnapshot[index] {
        case .success(let text):
            return text
        case .failure(let error):
            throw error
        }
    }
}

final class MockTextPaster: TextPaster, @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0
    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }
    var lastText: String?
    var shouldThrow = false

    @MainActor
    func paste(text: String) throws {
        lock.lock()
        _callCount += 1
        lastText = text
        let shouldFail = shouldThrow
        lock.unlock()

        if shouldFail {
            throw VoxError.insertionFailed
        }
    }
}

final class MockPreferences: PreferencesReading, @unchecked Sendable {
    var processingLevel: ProcessingLevel = .light
    var customContext: String = ""
    var selectedInputDeviceUID: String? = nil
    var elevenLabsAPIKey: String = ""
    var openRouterAPIKey: String = ""
    var deepgramAPIKey: String = ""
    var openAIAPIKey: String = ""
}

// MARK: - Tests

@Suite("DictationPipeline")
struct DictationPipelineTests {
    let audioURL = URL(fileURLWithPath: "/tmp/test-audio.caf")

    // MARK: - Basic Flow Tests

    @Test("Process with STT only - processing level off")
    func process_sttOnly_offLevel() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .off

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "hello world")
        #expect(stt.callCount == 1)
        #expect(rewriter.callCount == 0)
        #expect(paster.callCount == 1)
    }

    @Test("Process with light processing - rewrite succeeds")
    func process_lightRewriteSucceeds() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("Hello, world!")]

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "Hello, world!")
        #expect(stt.callCount == 1)
        #expect(rewriter.callCount == 1)
        #expect(paster.callCount == 1)
    }

    @Test("Process with aggressive processing - rewrite succeeds")
    func process_aggressiveRewriteSucceeds() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("um like hello world um")]

        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("Hello, world.")]

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .aggressive

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "Hello, world.")
        #expect(stt.callCount == 1)
        #expect(rewriter.callCount == 1)
    }

    @Test("Process with enhance processing - rewrite succeeds")
    func process_enhanceRewriteSucceeds() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("meeting notes")]

        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("# Meeting Notes\n\n- Key point 1\n- Key point 2")]

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .enhance

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "# Meeting Notes\n\n- Key point 1\n- Key point 2")
        #expect(stt.callCount == 1)
        #expect(rewriter.callCount == 1)
    }

    // MARK: - Error Handling Tests

    @Test("STT failure propagates error")
    func process_sttFailure_propagatesError() async {
        let stt = MockSTTProvider()
        stt.results = [.failure(STTError.network("connection lost"))]

        let rewriter = MockRewriteProvider()
        let paster = MockTextPaster()
        let prefs = MockPreferences()

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            #expect(Bool(false), "Expected error to be thrown")
        } catch let error as STTError {
            #expect(error == .network("connection lost"))
        } catch {
            #expect(Bool(false), "Expected STTError, got \(error)")
        }

        #expect(stt.callCount == 1)
        #expect(rewriter.callCount == 0)
        #expect(paster.callCount == 0)
    }

    @Test("Empty transcript throws noTranscript")
    func process_emptyTranscript_throwsNoTranscript() async {
        let stt = MockSTTProvider()
        stt.results = [.success("   ")]

        let rewriter = MockRewriteProvider()
        let paster = MockTextPaster()
        let prefs = MockPreferences()

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            #expect(Bool(false), "Expected error to be thrown")
        } catch let error as VoxError {
            #expect(error == .noTranscript)
        } catch {
            #expect(Bool(false), "Expected VoxError.noTranscript, got \(error)")
        }
    }

    @Test("Rewrite failure falls back to raw transcript")
    func process_rewriteFailure_usesRawTranscript() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        rewriter.results = [.failure(RewriteError.network("timeout"))]

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "hello world")
        #expect(stt.callCount == 1)
        #expect(rewriter.callCount == 1)
        #expect(paster.callCount == 1)
    }

    @Test("Rewrite quality gate rejection uses raw transcript")
    func process_rewriteQualityGateRejection_usesRawTranscript() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        // Light processing requires 0.6 ratio, "hi" is only 0.4 of "hello world"
        rewriter.results = [.success("hi")]

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "hello world")
        #expect(stt.callCount == 1)
        #expect(rewriter.callCount == 1)
        #expect(paster.callCount == 1)
    }

    @Test("Paster failure propagates error")
    func process_pasterFailure_propagatesError() async {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        let paster = MockTextPaster()
        paster.shouldThrow = true
        let prefs = MockPreferences()
        prefs.processingLevel = .off

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            #expect(Bool(false), "Expected error to be thrown")
        } catch let error as VoxError {
            #expect(error == .insertionFailed)
        } catch {
            #expect(Bool(false), "Expected VoxError.insertionFailed, got \(error)")
        }
    }

    // MARK: - Timeout Tests

    @Test("STT timeout throws pipelineTimeout")
    func process_sttTimeout_throwsTimeout() async {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]
        stt.delay = 0.5  // 500ms delay

        let rewriter = MockRewriteProvider()
        let paster = MockTextPaster()
        let prefs = MockPreferences()

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            sttTimeout: 0.1,  // 100ms timeout
            rewriteTimeout: 10,
            totalTimeout: 60
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            #expect(Bool(false), "Expected error to be thrown")
        } catch let error as VoxError {
            if case .pipelineTimeout(let stage) = error {
                #expect(stage == .stt)
            } else {
                #expect(Bool(false), "Expected pipelineTimeout, got \(error)")
            }
        } catch {
            #expect(Bool(false), "Expected VoxError, got \(error)")
        }
    }

    @Test("Rewrite timeout returns raw transcript")
    func process_rewriteTimeout_returnsRawTranscript() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("should not complete")]
        rewriter.delay = 0.5  // 500ms delay

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            sttTimeout: 10,
            rewriteTimeout: 0.1,  // 100ms timeout
            totalTimeout: 60
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "hello world")
        #expect(stt.callCount == 1)
        #expect(rewriter.callCount == 1)
        #expect(paster.callCount == 1)
    }

    @Test("Total pipeline timeout throws pipelineTimeout")
    func process_totalTimeout_throwsTimeout() async {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]
        stt.delay = 0.5  // 500ms delay

        let rewriter = MockRewriteProvider()
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .off

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            sttTimeout: 10,
            rewriteTimeout: 10,
            totalTimeout: 0.1  // 100ms total timeout
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            #expect(Bool(false), "Expected error to be thrown")
        } catch let error as VoxError {
            if case .pipelineTimeout(let stage) = error {
                #expect(stage == .fullPipeline)
            } else {
                #expect(Bool(false), "Expected pipelineTimeout, got \(error)")
            }
        } catch {
            #expect(Bool(false), "Expected VoxError, got \(error)")
        }
    }

    // MARK: - Custom Context Tests

    @Test("Custom context is included in prompt")
    func process_customContext_includesInPrompt() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("Hello, world!")]

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light
        prefs.customContext = "This is a formal email"

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        _ = try await pipeline.process(audioURL: audioURL)

        #expect(rewriter.lastPrompt?.contains("This is a formal email") == true)
        #expect(rewriter.lastPrompt?.contains("Context:") == true)
    }

    @Test("Empty custom context excludes context section")
    func process_emptyContext_excludesContextSection() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("Hello, world!")]

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light
        prefs.customContext = "   "  // whitespace only

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        _ = try await pipeline.process(audioURL: audioURL)

        #expect(rewriter.lastPrompt?.contains("Context:") == false)
    }

    // MARK: - Cancellation Tests

    @Test("Cancellation propagates correctly")
    func process_cancellation_propagates() async {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]
        stt.delay = 0.5

        let rewriter = MockRewriteProvider()
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        let task = Task {
            try await pipeline.process(audioURL: audioURL)
        }

        task.cancel()

        do {
            _ = try await task.value
            #expect(Bool(false), "Expected cancellation error")
        } catch is CancellationError {
            // Expected
        } catch {
            #expect(Bool(false), "Expected CancellationError, got \(error)")
        }
    }

    // MARK: - Edge Cases

    @Test("Rewrite produces empty result uses raw transcript")
    func process_rewriteEmptyResult_usesRawTranscript() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("")]

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "hello world")
    }

    @Test("Rewrite produces whitespace-only result uses raw transcript")
    func process_rewriteWhitespaceResult_usesRawTranscript() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("   \n\t  ")]

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "hello world")
    }

    @Test("Model is passed correctly for each processing level")
    func process_processingLevel_passesCorrectModel() async throws {
        let testCases: [(ProcessingLevel, String)] = [
            (.light, ProcessingLevel.light.defaultModel),
            (.aggressive, ProcessingLevel.aggressive.defaultModel),
            (.enhance, ProcessingLevel.enhance.defaultModel),
        ]

        for (level, expectedModel) in testCases {
            let stt = MockSTTProvider()
            stt.results = [.success("test")]

            let rewriter = MockRewriteProvider()
            rewriter.results = [.success("Test result")]

            let paster = MockTextPaster()
            let prefs = MockPreferences()
            prefs.processingLevel = level

            let pipeline = DictationPipeline(
                stt: stt,
                rewriter: rewriter,
                paster: paster,
                prefs: prefs
            )

            _ = try await pipeline.process(audioURL: audioURL)

            #expect(rewriter.lastModel == expectedModel, "Failed for level: \(level)")
        }
    }
}
