import AVFoundation
import Foundation
import Testing
@testable import VoxCore
@testable import VoxAppKit

// MARK: - Mocks

final class MockSTTProvider: STTProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _results: [Result<String, Error>] = []
    var results: [Result<String, Error>] {
        get { lock.withLock { _results } }
        set { lock.withLock { _results = newValue } }
    }
    private var _callCount = 0
    var callCount: Int { lock.withLock { _callCount } }
    private var _lastAudioURL: URL?
    var lastAudioURL: URL? { lock.withLock { _lastAudioURL } }
    private var _delay: TimeInterval = 0
    var delay: TimeInterval {
        get { lock.withLock { _delay } }
        set { lock.withLock { _delay = newValue } }
    }

    func transcribe(audioURL: URL) async throws -> String {
        let (index, currentDelay, resultsSnapshot) = lock.withLock {
            _callCount += 1
            let index = _callCount - 1
            _lastAudioURL = audioURL
            return (index, _delay, _results)
        }

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
        get { lock.withLock { _results } }
        set { lock.withLock { _results = newValue } }
    }
    private var _callCount = 0
    var callCount: Int { lock.withLock { _callCount } }
    private var _lastTranscript: String?
    var lastTranscript: String? { lock.withLock { _lastTranscript } }
    private var _lastPrompt: String?
    var lastPrompt: String? { lock.withLock { _lastPrompt } }
    private var _lastModel: String?
    var lastModel: String? { lock.withLock { _lastModel } }
    private var _delay: TimeInterval = 0
    var delay: TimeInterval {
        get { lock.withLock { _delay } }
        set { lock.withLock { _delay = newValue } }
    }

    func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        let (index, currentDelay, resultsSnapshot) = lock.withLock {
            _callCount += 1
            let index = _callCount - 1
            _lastTranscript = transcript
            _lastPrompt = systemPrompt
            _lastModel = model
            return (index, _delay, _results)
        }

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
    var callCount: Int { lock.withLock { _callCount } }
    private var _lastText: String?
    var lastText: String? { lock.withLock { _lastText } }
    private var _shouldThrow = false
    var shouldThrow: Bool {
        get { lock.withLock { _shouldThrow } }
        set { lock.withLock { _shouldThrow = newValue } }
    }

    @MainActor
    func paste(text: String) throws {
        let shouldFail = lock.withLock {
            _callCount += 1
            _lastText = text
            return _shouldThrow
        }

        if shouldFail {
            throw VoxError.insertionFailed
        }
    }
}

@MainActor
final class MockPreferences: PreferencesReading, @unchecked Sendable {
    var processingLevel: ProcessingLevel = .light
    var selectedInputDeviceUID: String? = nil
    var elevenLabsAPIKey: String = ""
    var openRouterAPIKey: String = ""
    var deepgramAPIKey: String = ""
    var openAIAPIKey: String = ""
}

final class MockAudioConverter: @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0
    var callCount: Int { lock.withLock { _callCount } }
    private var _lastInputURL: URL?
    var lastInputURL: URL? { lock.withLock { _lastInputURL } }
    let outputURL: URL

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    func convert(_ inputURL: URL) async throws -> URL {
        lock.withLock {
            _callCount += 1
            _lastInputURL = inputURL
        }
        return outputURL
    }
}

// MARK: - Tests

@Suite("DictationPipeline")
@MainActor
struct DictationPipelineTests {
    let audioURL = URL(fileURLWithPath: "/tmp/test-audio.caf")

    private func makeRewriteCache() -> RewriteResultCache {
        RewriteResultCache(maxEntries: 16, ttlSeconds: 60, maxCharacterCount: 1_024)
    }

    private func makeCAF(frameCount: AVAudioFrameCount) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pipeline-\(UUID().uuidString).caf")
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1) else {
            throw VoxError.internalError("Failed to create test audio format")
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw VoxError.internalError("Failed to create test audio buffer")
        }
        buffer.frameLength = frameCount
        try file.write(from: buffer)
        return url
    }

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
            prefs: prefs,
            enableOpus: false
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "hello world")
        #expect(stt.callCount == 1)
        #expect(rewriter.callCount == 0)
        #expect(paster.callCount == 1)
    }

    @Test("Process precomputed transcript keeps rewrite and paste semantics")
    func process_precomputedTranscript_rewritesAndPastes() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("unused")]
        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("Hello, world!")]
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            enableOpus: false
        )

        let result = try await pipeline.process(transcript: "hello world")

        #expect(result == "Hello, world!")
        #expect(stt.callCount == 0)
        #expect(rewriter.callCount == 1)
        #expect(paster.callCount == 1)
    }

    @Test("Process converts CAF to OGG before STT")
    func process_enableOpus_passesOggToSTT() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .off
        let convertedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("converted-\(UUID().uuidString)")
            .appendingPathExtension("ogg")
        FileManager.default.createFile(atPath: convertedURL.path, contents: Data([0x4F, 0x67, 0x67, 0x53]))
        let converter = MockAudioConverter(outputURL: convertedURL)

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            enableOpus: true,
            convertCAFToOpus: { inputURL in
                try await converter.convert(inputURL)
            },
            opusBypassThreshold: 0
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "hello world")
        #expect(converter.callCount == 1)
        #expect(converter.lastInputURL == audioURL)
        #expect(stt.callCount == 1)
        #expect(stt.lastAudioURL == convertedURL)
        #expect(stt.lastAudioURL?.pathExtension.lowercased() == "ogg")
    }

    @Test("Opus skipped when file size below threshold")
    func process_opusSkipped_whenFileBelowThreshold() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .off

        let converter = MockAudioConverter(
            outputURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("unused-\(UUID().uuidString).ogg")
        )
        let smallCAF = try makeCAF(frameCount: 800)
        defer { try? FileManager.default.removeItem(at: smallCAF) }

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            enableOpus: true,
            convertCAFToOpus: { inputURL in
                try await converter.convert(inputURL)
            },
            opusBypassThreshold: 500_000
        )

        let result = try await pipeline.process(audioURL: smallCAF)

        #expect(result == "hello world")
        #expect(converter.callCount == 0)
        #expect(stt.lastAudioURL == smallCAF)
    }

    @Test("Opus applied when file size above threshold")
    func process_opusApplied_whenFileAboveThreshold() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .off

        let convertedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("converted-\(UUID().uuidString).ogg")
        FileManager.default.createFile(atPath: convertedURL.path, contents: Data([0x4F, 0x67, 0x67, 0x53]))
        defer { try? FileManager.default.removeItem(at: convertedURL) }
        let converter = MockAudioConverter(outputURL: convertedURL)
        let largeCAF = try makeCAF(frameCount: 8_000)
        defer { try? FileManager.default.removeItem(at: largeCAF) }

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            enableOpus: true,
            convertCAFToOpus: { inputURL in
                try await converter.convert(inputURL)
            },
            opusBypassThreshold: 5_000
        )

        let result = try await pipeline.process(audioURL: largeCAF)

        #expect(result == "hello world")
        #expect(converter.callCount == 1)
        #expect(stt.lastAudioURL == convertedURL)
    }

    @Test("Process falls back to CAF when Opus output is empty")
    func process_enableOpus_emptyOutput_fallsBackToCAF() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .off
        let convertedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("converted-empty-\(UUID().uuidString)")
            .appendingPathExtension("ogg")
        FileManager.default.createFile(atPath: convertedURL.path, contents: Data())
        let converter = MockAudioConverter(outputURL: convertedURL)

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            enableOpus: true,
            convertCAFToOpus: { inputURL in
                try await converter.convert(inputURL)
            },
            opusBypassThreshold: 0
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "hello world")
        #expect(converter.callCount == 1)
        #expect(stt.callCount == 1)
        #expect(stt.lastAudioURL == audioURL)
        #expect(!FileManager.default.fileExists(atPath: convertedURL.path))
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
            prefs: prefs,
            enableOpus: false
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "Hello, world!")
        #expect(stt.callCount == 1)
        #expect(rewriter.callCount == 1)
        #expect(paster.callCount == 1)
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
            prefs: prefs,
            enableOpus: false
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            Issue.record("Expected error to be thrown")
        } catch let error as STTError {
            #expect(error == .network("connection lost"))
        } catch {
            Issue.record("Expected STTError, got \(error)")
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
            prefs: prefs,
            enableOpus: false
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            Issue.record("Expected error to be thrown")
        } catch let error as VoxError {
            #expect(error == .noTranscript)
        } catch {
            Issue.record("Expected VoxError.noTranscript, got \(error)")
        }
    }

    @Test("Header-only CAF fails fast before STT")
    func process_headerOnlyCAF_throwsEmptyCapture() async {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        let paster = MockTextPaster()
        let prefs = MockPreferences()

        let headerOnlyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("header-only-\(UUID().uuidString).caf")
        let created = FileManager.default.createFile(
            atPath: headerOnlyURL.path,
            contents: Data(count: 4096)
        )
        #expect(created)
        defer { try? FileManager.default.removeItem(at: headerOnlyURL) }

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            enableOpus: false
        )

        do {
            _ = try await pipeline.process(audioURL: headerOnlyURL)
            Issue.record("Expected error to be thrown")
        } catch let error as VoxError {
            #expect(error == .emptyCapture)
        } catch {
            Issue.record("Expected VoxError.emptyCapture, got \(error)")
        }

        #expect(stt.callCount == 0)
        #expect(rewriter.callCount == 0)
        #expect(paster.callCount == 0)
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
            prefs: prefs,
            enableOpus: false
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
        rewriter.results = [.success("hi")]

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            enableOpus: false
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
            prefs: prefs,
            enableOpus: false
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            Issue.record("Expected error to be thrown")
        } catch let error as VoxError {
            #expect(error == .insertionFailed)
        } catch {
            Issue.record("Expected VoxError.insertionFailed, got \(error)")
        }
    }

    // MARK: - Timeout Tests

    @Test("Pipeline timeout throws pipelineTimeout")
    func process_pipelineTimeout_throwsTimeout() async {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]
        stt.delay = 0.5

        let rewriter = MockRewriteProvider()
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .off

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            enableOpus: false,
            pipelineTimeout: 0.1
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            Issue.record("Expected error to be thrown")
        } catch let error as VoxError {
            #expect(error == .pipelineTimeout)
        } catch {
            Issue.record("Expected VoxError.pipelineTimeout, got \(error)")
        }
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
            prefs: prefs,
            enableOpus: false
        )

        let task = Task {
            try await pipeline.process(audioURL: audioURL)
        }

        // Give the task time to enter the pipeline before cancelling
        try? await Task.sleep(nanoseconds: 10_000_000)
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation error")
        } catch is CancellationError {
            // Expected
        } catch {
            Issue.record("Expected CancellationError, got \(error)")
        }
    }

    @Test("Invalid timeout (zero) throws internalError")
    func process_zeroTimeout_throwsInternalError() async {
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
            prefs: prefs,
            enableOpus: false,
            pipelineTimeout: 0
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            Issue.record("Expected error to be thrown")
        } catch let error as VoxError {
            if case .internalError = error {
                // Expected
            } else {
                Issue.record("Expected VoxError.internalError, got \(error)")
            }
        } catch {
            Issue.record("Expected VoxError, got \(error)")
        }
    }

    @Test("Invalid timeout (negative) throws internalError")
    func process_negativeTimeout_throwsInternalError() async {
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
            prefs: prefs,
            enableOpus: false,
            pipelineTimeout: -5
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            Issue.record("Expected error to be thrown")
        } catch let error as VoxError {
            if case .internalError = error {
                // Expected
            } else {
                Issue.record("Expected VoxError.internalError, got \(error)")
            }
        } catch {
            Issue.record("Expected VoxError, got \(error)")
        }
    }

    @Test("Invalid timeout (NaN) throws internalError")
    func process_nanTimeout_throwsInternalError() async {
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
            prefs: prefs,
            enableOpus: false,
            pipelineTimeout: .nan
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            Issue.record("Expected error to be thrown")
        } catch let error as VoxError {
            if case .internalError = error {
                // Expected
            } else {
                Issue.record("Expected VoxError.internalError, got \(error)")
            }
        } catch {
            Issue.record("Expected VoxError, got \(error)")
        }
    }

    @Test("Invalid timeout (infinity) throws internalError")
    func process_infinityTimeout_throwsInternalError() async {
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
            prefs: prefs,
            enableOpus: false,
            pipelineTimeout: .infinity
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            Issue.record("Expected error to be thrown")
        } catch let error as VoxError {
            if case .internalError = error {
                // Expected
            } else {
                Issue.record("Expected VoxError.internalError, got \(error)")
            }
        } catch {
            Issue.record("Expected VoxError, got \(error)")
        }
    }

    @Test("Invalid timeout (excessive) throws internalError")
    func process_excessiveTimeout_throwsInternalError() async {
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
            prefs: prefs,
            enableOpus: false,
            pipelineTimeout: .greatestFiniteMagnitude
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            Issue.record("Expected error to be thrown")
        } catch let error as VoxError {
            if case .internalError = error {
                // Expected
            } else {
                Issue.record("Expected VoxError.internalError, got \(error)")
            }
        } catch {
            Issue.record("Expected VoxError, got \(error)")
        }
    }

    @Test("Invalid timeout (UInt64 boundary) throws internalError")
    func process_uint64BoundaryTimeout_throwsInternalError() async {
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
            prefs: prefs,
            enableOpus: false,
            pipelineTimeout: Double(UInt64.max) / 1_000_000_000
        )

        do {
            _ = try await pipeline.process(audioURL: audioURL)
            Issue.record("Expected error to be thrown")
        } catch let error as VoxError {
            if case .internalError = error {
                // Expected
            } else {
                Issue.record("Expected VoxError.internalError, got \(error)")
            }
        } catch {
            Issue.record("Expected VoxError, got \(error)")
        }
    }

    @Test("Cancellation during rewrite propagates correctly")
    func process_cancellationDuringRewrite_propagates() async {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]

        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("Hello, world!")]
        rewriter.delay = 0.5

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            enableOpus: false
        )

        let task = Task {
            try await pipeline.process(audioURL: audioURL)
        }

        // Give the task time to pass STT and enter rewrite before cancelling
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation error")
        } catch is CancellationError {
            // Expected
        } catch {
            Issue.record("Expected CancellationError, got \(error)")
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
            prefs: prefs,
            enableOpus: false
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
            prefs: prefs,
            enableOpus: false
        )

        let result = try await pipeline.process(audioURL: audioURL)

        #expect(result == "hello world")
    }

    @Test("Rewrite cache hit skips second rewrite call")
    func process_rewriteCacheHit_skipsSecondRewriteCall() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("cache phrase one"), .success("cache phrase one")]

        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("Cache phrase one.")]

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            rewriteCache: makeRewriteCache(),
            enableRewriteCache: true,
            enableOpus: false
        )

        let first = try await pipeline.process(audioURL: audioURL)
        let second = try await pipeline.process(audioURL: audioURL)

        #expect(first == "Cache phrase one.")
        #expect(second == "Cache phrase one.")
        #expect(stt.callCount == 2)
        #expect(rewriter.callCount == 1)
        #expect(paster.callCount == 2)
    }

    @Test("Rewrite cache key includes processing level/model")
    func process_rewriteCache_levelChange_missesCache() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("cache phrase two"), .success("cache phrase two")]

        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("Hello, world!"), .success("HELLO WORLD!")]

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            rewriteCache: makeRewriteCache(),
            enableRewriteCache: true,
            enableOpus: false
        )

        let first = try await pipeline.process(audioURL: audioURL)
        prefs.processingLevel = .aggressive
        let second = try await pipeline.process(audioURL: audioURL)

        #expect(first == "Hello, world!")
        #expect(second == "HELLO WORLD!")
        #expect(rewriter.callCount == 2)
    }

    @Test("Rewrite cache skips long transcripts")
    func process_rewriteCache_longTranscript_skipsCache() async throws {
        let transcript = String(repeating: "a", count: 1_100)
        let rewrittenOne = String(repeating: "b", count: 1_100)
        let rewrittenTwo = String(repeating: "c", count: 1_100)

        let stt = MockSTTProvider()
        stt.results = [.success(transcript), .success(transcript)]

        let rewriter = MockRewriteProvider()
        rewriter.results = [.success(rewrittenOne), .success(rewrittenTwo)]

        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .light

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            rewriteCache: makeRewriteCache(),
            enableRewriteCache: true,
            enableOpus: false
        )

        let first = try await pipeline.process(audioURL: audioURL)
        let second = try await pipeline.process(audioURL: audioURL)

        #expect(first == rewrittenOne)
        #expect(second == rewrittenTwo)
        #expect(rewriter.callCount == 2)
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
                prefs: prefs,
                enableOpus: false
            )

            _ = try await pipeline.process(audioURL: audioURL)

            #expect(rewriter.lastModel == expectedModel, "Failed for level: \(level)")
        }
    }
}
