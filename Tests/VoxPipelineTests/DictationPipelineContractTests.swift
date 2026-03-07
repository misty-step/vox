import Foundation
import Testing
@testable import VoxCore
@testable import VoxPipeline

private final class DiagnosticsSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [(String, String)] = []
    var events: [(String, String)] { lock.withLock { _events } }

    func record(name: String, message: String) {
        lock.withLock { _events.append((name, message)) }
    }
}

/// Integration tests verifying that the DictationPipeline applies RewriteOutputContract
/// to rewrite candidates before pasting. These exercise the contract through the full
/// pipeline path rather than testing the contract validator in isolation.
@Suite("DictationPipeline – Output Contract")
@MainActor
struct DictationPipelineContractTests {
    let audioURL = URL(fileURLWithPath: "/tmp/test-audio.caf")

    private func makeRewriteCache() -> RewriteResultCache {
        RewriteResultCache(maxEntries: 16, ttlSeconds: 60, maxCharacterCount: 1_024)
    }

    // MARK: - Preamble stripping

    @Test("Strips preamble from rewrite and pastes clean text")
    func stripsPreamble() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("i went to the store")]
        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("Here's the cleaned version:\nI went to the store.")]
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .clean

        let pipeline = DictationPipeline(
            stt: stt, rewriter: rewriter, paster: paster, prefs: prefs,
            rewriteCache: makeRewriteCache(), enableOpus: false
        )

        let result = try await pipeline.process(audioURL: audioURL)
        #expect(result == "I went to the store.")
        #expect(paster.lastText == "I went to the store.")
    }

    // MARK: - Attribution stripping (#319)

    @Test("Strips 'Transcribed by otter.ai' attribution from rewrite output")
    func stripsOtterAttribution() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("i went to the store")]
        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("I went to the store.\n\nTranscribed by otter.ai")]
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .clean

        let pipeline = DictationPipeline(
            stt: stt, rewriter: rewriter, paster: paster, prefs: prefs,
            rewriteCache: makeRewriteCache(), enableOpus: false
        )

        let result = try await pipeline.process(audioURL: audioURL)
        #expect(result == "I went to the store.")
        #expect(paster.lastText == "I went to the store.")
    }

    // MARK: - Contract rejection falls back to raw transcript

    @Test("Falls back to raw transcript when contract rejects entire output")
    func fallsBackOnRejection() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("hello world")]
        let rewriter = MockRewriteProvider()
        // Output is just a preamble with no actual content
        rewriter.results = [.success("Here's the cleaned version:")]
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .clean

        let pipeline = DictationPipeline(
            stt: stt, rewriter: rewriter, paster: paster, prefs: prefs,
            rewriteCache: makeRewriteCache(), enableOpus: false
        )

        let result = try await pipeline.process(audioURL: audioURL)
        #expect(result == "hello world")
        #expect(paster.lastText == "hello world")
    }

    // MARK: - Diagnostics logging

    @Test("Logs diagnostics event on contract violation")
    func logsDiagnosticsOnViolation() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("test input")]
        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("Sure, here you go:\nTest input.")]
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .clean

        let spy = DiagnosticsSpy()
        let pipeline = DictationPipeline(
            stt: stt, rewriter: rewriter, paster: paster, prefs: prefs,
            rewriteCache: makeRewriteCache(), enableOpus: false,
            onDiagnosticsLog: { name, message in
                spy.record(name: name, message: message)
            }
        )

        _ = try await pipeline.process(audioURL: audioURL)

        let contractEvents = spy.events.filter { $0.0 == "rewrite_contract_violation" }
        #expect(!contractEvents.isEmpty)
        #expect(contractEvents[0].1.contains("repaired"))
    }

    // MARK: - Clean output passes through unchanged

    @Test("Clean rewrite output passes through without modification")
    func cleanOutputPassesThrough() async throws {
        let stt = MockSTTProvider()
        stt.results = [.success("i went to the store")]
        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("I went to the store.")]
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .clean

        let pipeline = DictationPipeline(
            stt: stt, rewriter: rewriter, paster: paster, prefs: prefs,
            rewriteCache: makeRewriteCache(), enableOpus: false
        )

        let result = try await pipeline.process(audioURL: audioURL)
        #expect(result == "I went to the store.")
    }

    // MARK: - Transcript path (streaming) also validates

    @Test("Transcript processing path also applies contract validation")
    func transcriptPathValidates() async throws {
        let stt = MockSTTProvider()
        let rewriter = MockRewriteProvider()
        rewriter.results = [.success("Of course!\nThe meeting went well.")]
        let paster = MockTextPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = .polish

        let pipeline = DictationPipeline(
            stt: stt, rewriter: rewriter, paster: paster, prefs: prefs,
            rewriteCache: makeRewriteCache(), enableOpus: false
        )

        let result = try await pipeline.process(transcript: "the meeting went well")
        #expect(result == "The meeting went well.")
    }
}
