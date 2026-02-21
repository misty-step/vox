import XCTest
@testable import VoxProviders
import VoxCore

// MARK: - ProviderAssemblyTests
//
// Tests for the shared cloud-provider builder. Verifies chain shape, retry constants,
// fallback chain wiring, and instrumentation hooks — without network calls.

final class ProviderAssemblyTests: XCTestCase {

    // MARK: - Helpers

    private func config(
        elevenLabs: String = "",
        deepgram: String = "",
        gemini: String = "",
        openRouter: String = "",
        sttInstrument: @escaping @Sendable (String, String, any STTProvider) -> any STTProvider = { _, _, p in p },
        rewriteInstrument: @escaping @Sendable (String, any RewriteProvider) -> any RewriteProvider = { _, p in p },
        openRouterOnModelUsed: (@Sendable (String, Bool) -> Void)? = nil
    ) -> ProviderAssemblyConfig {
        ProviderAssemblyConfig(
            elevenLabsAPIKey: elevenLabs,
            deepgramAPIKey: deepgram,
            geminiAPIKey: gemini,
            openRouterAPIKey: openRouter,
            sttInstrument: sttInstrument,
            rewriteInstrument: rewriteInstrument,
            openRouterOnModelUsed: openRouterOnModelUsed
        )
    }

    // MARK: - CloudSTT entries

    func test_makeCloudSTTProvider_noKeys_returnsEmptyEntries() {
        let result = ProviderAssembly.makeCloudSTTProvider(config: config())
        XCTAssertTrue(result.entries.isEmpty)
    }

    func test_makeCloudSTTProvider_elevenLabsOnly_returnsOneEntry() {
        let result = ProviderAssembly.makeCloudSTTProvider(config: config(elevenLabs: "el-key"))
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].name, "ElevenLabs")
        XCTAssertEqual(result.entries[0].model, ProviderAssembly.elevenLabsModel)
    }

    func test_makeCloudSTTProvider_deepgramOnly_returnsOneEntry() {
        let result = ProviderAssembly.makeCloudSTTProvider(config: config(deepgram: "dg-key"))
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].name, "Deepgram")
        XCTAssertEqual(result.entries[0].model, ProviderAssembly.deepgramModel)
    }

    func test_makeCloudSTTProvider_bothKeys_returnsElevenLabsFirst() {
        let result = ProviderAssembly.makeCloudSTTProvider(config: config(elevenLabs: "el-key", deepgram: "dg-key"))
        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(result.entries[0].name, "ElevenLabs")
        XCTAssertEqual(result.entries[1].name, "Deepgram")
    }

    func test_makeCloudSTTProvider_whitespaceKeys_treatedAsEmpty() {
        let result = ProviderAssembly.makeCloudSTTProvider(config: config(elevenLabs: "   ", deepgram: "\t"))
        XCTAssertTrue(result.entries.isEmpty)
    }

    // MARK: - buildFallbackChain

    func test_buildFallbackChain_emptyEntries_returnsNil() {
        XCTAssertNil(ProviderAssembly.buildFallbackChain(from: []))
    }

    func test_buildFallbackChain_singleEntry_returnsProvider() {
        let result = ProviderAssembly.makeCloudSTTProvider(config: config(elevenLabs: "el-key"))
        XCTAssertNotNil(ProviderAssembly.buildFallbackChain(from: result.entries))
    }

    func test_buildFallbackChain_multipleEntries_returnsFallbackProvider() {
        let result = ProviderAssembly.makeCloudSTTProvider(config: config(elevenLabs: "el-key", deepgram: "dg-key"))
        let chain = ProviderAssembly.buildFallbackChain(from: result.entries)
        XCTAssertNotNil(chain)
        XCTAssertTrue(chain is FallbackSTTProvider)
    }

    func test_buildFallbackChain_fallsBackOnPrimaryFailure() async throws {
        // Primary fails, fallback succeeds — verifies the chain is actually wired.
        let failing = FailingSTTProvider()
        let succeeding = FixedSTTProvider(result: "fallback transcript")
        let entries: [CloudSTTEntry] = [
            CloudSTTEntry(name: "Primary", model: "m1", provider: failing),
            CloudSTTEntry(name: "Fallback", model: "m2", provider: succeeding),
        ]
        let chain = ProviderAssembly.buildFallbackChain(from: entries)!
        let transcript = try await chain.transcribe(audioURL: URL(fileURLWithPath: "/tmp/test.caf"))
        XCTAssertEqual(transcript, "fallback transcript")
    }

    // MARK: - chainLabel

    func test_chainLabel_empty() {
        XCTAssertEqual(ProviderAssembly.chainLabel(for: []), "")
    }

    func test_chainLabel_multiple() {
        let result = ProviderAssembly.makeCloudSTTProvider(config: config(elevenLabs: "el-key", deepgram: "dg-key"))
        XCTAssertEqual(ProviderAssembly.chainLabel(for: result.entries), "ElevenLabs + Deepgram")
    }

    // MARK: - Retry constants

    func test_retryConstants_matchExpectedValues() {
        XCTAssertEqual(ProviderAssembly.elevenLabsMaxRetries, 3)
        XCTAssertEqual(ProviderAssembly.deepgramMaxRetries, 2)
        XCTAssertEqual(ProviderAssembly.retryBaseDelay, 0.5)
    }

    func test_openRouterFallbackModels_nonEmpty() {
        XCTAssertFalse(ProviderAssembly.openRouterFallbackModels.isEmpty)
    }

    // MARK: - Instrumentation hooks

    func test_makeCloudSTTProvider_instrumentationHookCalledForEachEntry() {
        final class NameCollector: @unchecked Sendable {
            var names: [String] = []
        }
        let collector = NameCollector()
        let c = config(elevenLabs: "el-key", deepgram: "dg-key", sttInstrument: { name, _, provider in
            collector.names.append(name)
            return provider
        })
        _ = ProviderAssembly.makeCloudSTTProvider(config: c)
        XCTAssertEqual(Set(collector.names), Set(["ElevenLabs", "Deepgram"]))
    }

    func test_makeCloudSTTProvider_instrumentHookReceivesModelName() {
        final class ModelCollector: @unchecked Sendable {
            var models: [String] = []
        }
        let collector = ModelCollector()
        let c = config(elevenLabs: "el-key", deepgram: "dg-key", sttInstrument: { _, model, provider in
            collector.models.append(model)
            return provider
        })
        _ = ProviderAssembly.makeCloudSTTProvider(config: c)
        XCTAssertTrue(collector.models.contains(ProviderAssembly.elevenLabsModel))
        XCTAssertTrue(collector.models.contains(ProviderAssembly.deepgramModel))
    }

    func test_makeCloudSTTProvider_instrumentedProviderUsedInEntries() async throws {
        final class SpyProvider: STTProvider, @unchecked Sendable {
            var callCount = 0
            func transcribe(audioURL: URL) async throws -> String {
                callCount += 1
                return "spy"
            }
        }
        let spy = SpyProvider()
        let c = config(elevenLabs: "el-key", sttInstrument: { _, _, _ in spy })
        let result = ProviderAssembly.makeCloudSTTProvider(config: c)
        XCTAssertEqual(result.entries.count, 1)
        let transcript = try await result.entries[0].provider.transcribe(audioURL: URL(fileURLWithPath: "/tmp/fake.caf"))
        XCTAssertEqual(transcript, "spy")
        XCTAssertEqual(spy.callCount, 1)
    }

    // MARK: - Rewrite provider

    func test_makeRewriteProvider_noKeys_returnsOpenRouterClient() {
        let provider = ProviderAssembly.makeRewriteProvider(config: config())
        XCTAssertTrue(provider is OpenRouterClient)
    }

    func test_makeRewriteProvider_openRouterOnly_returnsOpenRouter() {
        let provider = ProviderAssembly.makeRewriteProvider(config: config(openRouter: "or-key"))
        XCTAssertTrue(provider is OpenRouterClient)
    }

    func test_makeRewriteProvider_geminiOnly_returnsModelRoutedProvider() {
        let provider = ProviderAssembly.makeRewriteProvider(config: config(gemini: "gem-key"))
        XCTAssertTrue(provider is ModelRoutedRewriteProvider)
    }

    func test_makeRewriteProvider_bothKeys_returnsModelRoutedProvider() {
        let provider = ProviderAssembly.makeRewriteProvider(config: config(gemini: "gem-key", openRouter: "or-key"))
        XCTAssertTrue(provider is ModelRoutedRewriteProvider)
    }

    func test_makeRewriteProvider_rewriteInstrumentCalledWithGeminiDirectPath() {
        final class PathCollector: @unchecked Sendable {
            var paths: [String] = []
        }
        let collector = PathCollector()
        let c = config(gemini: "gem-key", openRouter: "or-key", rewriteInstrument: { path, provider in
            collector.paths.append(path)
            return provider
        })
        _ = ProviderAssembly.makeRewriteProvider(config: c)
        XCTAssertEqual(collector.paths, ["gemini_direct"])
    }

    func test_makeRewriteProvider_openRouterOnly_instrumentNotCalled() {
        final class PathCollector: @unchecked Sendable {
            var paths: [String] = []
        }
        let collector = PathCollector()
        let c = config(openRouter: "or-key", rewriteInstrument: { path, provider in
            collector.paths.append(path)
            return provider
        })
        _ = ProviderAssembly.makeRewriteProvider(config: c)
        XCTAssertTrue(collector.paths.isEmpty, "Instrument should not be called for openRouter-only path")
    }

    func test_makeRewriteProvider_whitespaceKeys_treatedAsNoKeys() {
        let provider = ProviderAssembly.makeRewriteProvider(config: config(gemini: "  ", openRouter: "\n"))
        // No real keys → falls back to bare OpenRouterClient
        XCTAssertTrue(provider is OpenRouterClient)
    }
}

// MARK: - Test doubles

private final class FailingSTTProvider: STTProvider, @unchecked Sendable {
    func transcribe(audioURL: URL) async throws -> String {
        throw STTError.network("simulated failure")
    }
}

private final class FixedSTTProvider: STTProvider, @unchecked Sendable {
    let result: String
    init(result: String) { self.result = result }
    func transcribe(audioURL: URL) async throws -> String { result }
}
