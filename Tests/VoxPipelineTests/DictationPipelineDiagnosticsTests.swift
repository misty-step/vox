import AVFoundation
import Foundation
import Testing
@testable import VoxCore
@testable import VoxPipeline

/// Thread-safe spy for `onDiagnosticsLog` callback events.
private final class DiagnosticsLogSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [(name: String, message: String)] = []

    var events: [(name: String, message: String)] {
        lock.withLock { _events }
    }

    func record(name: String, message: String) {
        lock.withLock { _events.append((name, message)) }
    }
}

// MARK: - Mocks (duplicated subset — pipeline tests are in a separate target)

private final class StubSTT: STTProvider, @unchecked Sendable {
    var result: String = "hello world"
    func transcribe(audioURL: URL) async throws -> String { result }
}

private final class StubRewriter: RewriteProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _results: [Result<String, Error>] = []
    var results: [Result<String, Error>] {
        get { lock.withLock { _results } }
        set { lock.withLock { _results = newValue } }
    }
    private var _delay: TimeInterval = 0
    var delay: TimeInterval {
        get { lock.withLock { _delay } }
        set { lock.withLock { _delay = newValue } }
    }
    private var _callIndex = 0

    func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        let (index, currentDelay, snapshot) = lock.withLock {
            let i = _callIndex
            _callIndex += 1
            return (i, _delay, _results)
        }
        if currentDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
        }
        guard index < snapshot.count else {
            throw RewriteError.unknown("no mock result")
        }
        return try snapshot[index].get()
    }
}

private final class StubPaster: TextPaster, @unchecked Sendable {
    @MainActor func paste(text: String) throws {}
}

@MainActor
private final class StubPrefs: PreferencesReading, @unchecked Sendable {
    var processingLevel: ProcessingLevel = .clean
    var selectedInputDeviceUID: String? = nil
    var elevenLabsAPIKey: String = ""
    var openRouterAPIKey: String = ""
    var deepgramAPIKey: String = ""
    var geminiAPIKey: String = ""
}

// MARK: - Tests

@Suite("DictationPipeline onDiagnosticsLog callback")
@MainActor
struct DictationPipelineDiagnosticsTests {
    let audioURL = URL(fileURLWithPath: "/tmp/test-diag-audio.caf")

    private func makeRewriteCache() -> RewriteResultCache {
        RewriteResultCache(maxEntries: 16, ttlSeconds: 60, maxCharacterCount: 1_024)
    }

    private func makeCAF(frameCount: AVAudioFrameCount) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("diag-\(UUID().uuidString).caf")
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

    // MARK: - Opus conversion fallback fires diagnostics

    @Test("Opus conversion failure fires opus_conversion_fallback event")
    func opusConversionFailure_firesDiagnosticsLog() async throws {
        let spy = DiagnosticsLogSpy()
        let largeCAF = try makeCAF(frameCount: 8_000)
        defer { try? FileManager.default.removeItem(at: largeCAF) }

        let prefs = StubPrefs()
        prefs.processingLevel = .raw

        let pipeline = DictationPipeline(
            stt: StubSTT(),
            rewriter: StubRewriter(),
            paster: StubPaster(),
            prefs: prefs,
            rewriteCache: makeRewriteCache(),
            enableOpus: true,
            isOpusConversionEnabled: { true },
            convertCAFToOpus: { _ in throw AudioConversionError.conversionFailed(exitCode: 1, stderr: "test") },
            opusBypassThreshold: 0,
            onDiagnosticsLog: { name, message in spy.record(name: name, message: message) }
        )

        _ = try await pipeline.process(audioURL: largeCAF)

        #expect(spy.events.count == 1)
        #expect(spy.events[0].name == "opus_conversion_fallback")
        #expect(spy.events[0].message.contains("conversion_stage=opus"))
    }

    // MARK: - Rewrite stage outcome: success

    @Test("Successful rewrite fires rewrite_stage_outcome with outcome=success")
    func rewriteSuccess_firesDiagnosticsLog() async throws {
        let spy = DiagnosticsLogSpy()
        let rewriter = StubRewriter()
        rewriter.results = [.success("Hello, world!")]
        let prefs = StubPrefs()
        prefs.processingLevel = .clean

        let pipeline = DictationPipeline(
            stt: StubSTT(),
            rewriter: rewriter,
            paster: StubPaster(),
            prefs: prefs,
            rewriteCache: makeRewriteCache(),
            enableOpus: false,
            onDiagnosticsLog: { name, message in spy.record(name: name, message: message) }
        )

        _ = try await pipeline.process(audioURL: audioURL)

        #expect(spy.events.count == 1)
        #expect(spy.events[0].name == "rewrite_stage_outcome")
        #expect(spy.events[0].message.contains("outcome=success"))
        #expect(spy.events[0].message.contains("level=clean"))
        #expect(spy.events[0].message.contains("cache_hit=false"))
    }

    // MARK: - Rewrite stage outcome: cache hit

    @Test("Cache hit fires rewrite_stage_outcome with outcome=cache_hit")
    func rewriteCacheHit_firesDiagnosticsLog() async throws {
        let spy = DiagnosticsLogSpy()
        let rewriter = StubRewriter()
        rewriter.results = [.success("Hello, world!"), .success("unused")]
        let prefs = StubPrefs()
        prefs.processingLevel = .clean

        let cache = makeRewriteCache()
        let pipeline = DictationPipeline(
            stt: StubSTT(),
            rewriter: rewriter,
            paster: StubPaster(),
            prefs: prefs,
            rewriteCache: cache,
            enableRewriteCache: true,
            enableOpus: false,
            onDiagnosticsLog: { name, message in spy.record(name: name, message: message) }
        )

        // First call populates cache
        _ = try await pipeline.process(audioURL: audioURL)
        // Second call should hit cache
        _ = try await pipeline.process(audioURL: audioURL)

        let cacheHitEvents = spy.events.filter { $0.message.contains("outcome=cache_hit") }
        #expect(cacheHitEvents.count == 1)
        #expect(cacheHitEvents[0].name == "rewrite_stage_outcome")
        #expect(cacheHitEvents[0].message.contains("cache_hit=true"))
    }

    // MARK: - Rewrite stage outcome: empty fallback

    @Test("Empty rewrite fires rewrite_stage_outcome with outcome=empty_raw_fallback")
    func emptyRewrite_firesDiagnosticsLog() async throws {
        let spy = DiagnosticsLogSpy()
        let rewriter = StubRewriter()
        rewriter.results = [.success("   ")]  // whitespace-only = empty after trim
        let prefs = StubPrefs()
        prefs.processingLevel = .clean

        let pipeline = DictationPipeline(
            stt: StubSTT(),
            rewriter: rewriter,
            paster: StubPaster(),
            prefs: prefs,
            rewriteCache: makeRewriteCache(),
            enableOpus: false,
            onDiagnosticsLog: { name, message in spy.record(name: name, message: message) }
        )

        _ = try await pipeline.process(audioURL: audioURL)

        let events = spy.events.filter { $0.name == "rewrite_stage_outcome" }
        #expect(events.count == 1)
        #expect(events[0].message.contains("outcome=empty_raw_fallback"))
    }

    // MARK: - Rewrite stage outcome: timeout fallback

    @Test("Rewrite timeout fires rewrite_stage_outcome with outcome=timeout_raw_fallback")
    func rewriteTimeout_firesDiagnosticsLog() async throws {
        let spy = DiagnosticsLogSpy()
        let rewriter = StubRewriter()
        rewriter.results = [.success("Hello, world!")]
        rewriter.delay = 1.0  // will exceed 0.1s timeout
        let prefs = StubPrefs()
        prefs.processingLevel = .clean

        let pipeline = DictationPipeline(
            stt: StubSTT(),
            rewriter: rewriter,
            paster: StubPaster(),
            prefs: prefs,
            rewriteCache: makeRewriteCache(),
            enableOpus: false,
            rewriteStageTimeouts: RewriteStageTimeouts(cleanSeconds: 0.1, polishSeconds: 0.1),
            onDiagnosticsLog: { name, message in spy.record(name: name, message: message) }
        )

        _ = try await pipeline.process(audioURL: audioURL)

        let events = spy.events.filter { $0.name == "rewrite_stage_outcome" }
        #expect(events.count == 1)
        #expect(events[0].message.contains("outcome=timeout_raw_fallback"))
        #expect(events[0].message.contains("elapsed_ms="))
    }

    // MARK: - Rewrite stage outcome: error fallback

    @Test("Rewrite error fires rewrite_stage_outcome with outcome=error_raw_fallback")
    func rewriteError_firesDiagnosticsLog() async throws {
        let spy = DiagnosticsLogSpy()
        let rewriter = StubRewriter()
        rewriter.results = [.failure(RewriteError.unknown("test error"))]
        let prefs = StubPrefs()
        prefs.processingLevel = .clean

        let pipeline = DictationPipeline(
            stt: StubSTT(),
            rewriter: rewriter,
            paster: StubPaster(),
            prefs: prefs,
            rewriteCache: makeRewriteCache(),
            enableOpus: false,
            onDiagnosticsLog: { name, message in spy.record(name: name, message: message) }
        )

        _ = try await pipeline.process(audioURL: audioURL)

        let events = spy.events.filter { $0.name == "rewrite_stage_outcome" }
        #expect(events.count == 1)
        #expect(events[0].message.contains("outcome=error_raw_fallback"))
        #expect(events[0].message.contains("error="))
    }

    // MARK: - No diagnostics when processing level is raw

    @Test("Raw processing level does not fire rewrite diagnostics")
    func rawLevel_noDiagnosticsLog() async throws {
        let spy = DiagnosticsLogSpy()
        let prefs = StubPrefs()
        prefs.processingLevel = .raw

        let pipeline = DictationPipeline(
            stt: StubSTT(),
            rewriter: StubRewriter(),
            paster: StubPaster(),
            prefs: prefs,
            rewriteCache: makeRewriteCache(),
            enableOpus: false,
            onDiagnosticsLog: { name, message in spy.record(name: name, message: message) }
        )

        _ = try await pipeline.process(audioURL: audioURL)

        let rewriteEvents = spy.events.filter { $0.name == "rewrite_stage_outcome" }
        #expect(rewriteEvents.isEmpty)
    }
}
