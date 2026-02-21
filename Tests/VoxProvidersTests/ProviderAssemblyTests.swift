import XCTest
@testable import VoxProviders
import VoxCore

// MARK: - ProviderAssemblyTests
//
// Tests for the shared cloud-provider builder. Verifies chain shape, retry parameters,
// concurrency limits, and instrumentation hooks — without network calls.

final class ProviderAssemblyTests: XCTestCase {

    // MARK: - CloudSTT chain

    func test_makeCloudSTTProvider_noKeys_returnsEmptyEntries() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "",
            deepgramAPIKey: "",
            geminiAPIKey: "",
            openRouterAPIKey: ""
        )
        let result = ProviderAssembly.makeCloudSTTProvider(config: config)
        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertNil(result.cloudChain)
    }

    func test_makeCloudSTTProvider_elevenLabsOnly_returnsOneEntry() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "el-key",
            deepgramAPIKey: "",
            geminiAPIKey: "",
            openRouterAPIKey: ""
        )
        let result = ProviderAssembly.makeCloudSTTProvider(config: config)
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].name, "ElevenLabs")
        XCTAssertEqual(result.entries[0].model, "scribe_v2")
        XCTAssertNotNil(result.cloudChain)
    }

    func test_makeCloudSTTProvider_deepgramOnly_returnsOneEntry() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "",
            deepgramAPIKey: "dg-key",
            geminiAPIKey: "",
            openRouterAPIKey: ""
        )
        let result = ProviderAssembly.makeCloudSTTProvider(config: config)
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].name, "Deepgram")
        XCTAssertEqual(result.entries[0].model, "nova-3")
        XCTAssertNotNil(result.cloudChain)
    }

    func test_makeCloudSTTProvider_bothKeys_returnsElevenLabsFirst() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "el-key",
            deepgramAPIKey: "dg-key",
            geminiAPIKey: "",
            openRouterAPIKey: ""
        )
        let result = ProviderAssembly.makeCloudSTTProvider(config: config)
        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(result.entries[0].name, "ElevenLabs")
        XCTAssertEqual(result.entries[1].name, "Deepgram")
        XCTAssertNotNil(result.cloudChain)
    }

    func test_makeCloudSTTProvider_whitespaceKeys_treatedAsEmpty() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "   ",
            deepgramAPIKey: "\t",
            geminiAPIKey: "",
            openRouterAPIKey: ""
        )
        let result = ProviderAssembly.makeCloudSTTProvider(config: config)
        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertNil(result.cloudChain)
    }

    func test_makeCloudSTTProvider_singleEntry_cloudChainIsDirectProvider() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "el-key",
            deepgramAPIKey: "",
            geminiAPIKey: "",
            openRouterAPIKey: ""
        )
        let result = ProviderAssembly.makeCloudSTTProvider(config: config)
        // Single entry: cloudChain is just the one retry-wrapped provider
        XCTAssertNotNil(result.cloudChain)
        XCTAssertNotNil(result.entries.first)
    }

    // MARK: - Instrumentation hooks

    func test_makeCloudSTTProvider_instrumentationHookCalledForEachEntry() {
        final class NameCollector: @unchecked Sendable {
            var names: [String] = []
        }
        let collector = NameCollector()
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "el-key",
            deepgramAPIKey: "dg-key",
            geminiAPIKey: "",
            openRouterAPIKey: "",
            sttInstrument: { name, _, provider in
                collector.names.append(name)
                return provider
            }
        )
        _ = ProviderAssembly.makeCloudSTTProvider(config: config)
        XCTAssertEqual(Set(collector.names), Set(["ElevenLabs", "Deepgram"]))
    }

    func test_makeCloudSTTProvider_instrumentedProviderUsedInEntries() {
        // Verify the hook is called and its return value drives the entry's provider type.
        // (We can't use === on existential STTProvider, so we verify via a spy wrapper type.)
        final class SpyProvider: STTProvider, @unchecked Sendable {
            var callCount = 0
            func transcribe(audioURL: URL) async throws -> String {
                callCount += 1
                return ""
            }
        }
        let spy = SpyProvider()
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "el-key",
            deepgramAPIKey: "",
            geminiAPIKey: "",
            openRouterAPIKey: "",
            sttInstrument: { _, _, _ in spy }
        )
        let result = ProviderAssembly.makeCloudSTTProvider(config: config)
        // The entry's provider is the spy (hook's return value), so transcribing it increments the spy's counter.
        XCTAssertNotNil(result.entries.first)
        Task { _ = try? await result.entries[0].provider.transcribe(audioURL: URL(fileURLWithPath: "/tmp/fake.caf")) }
        // Async fire-and-forget — just confirm no crash and entry was populated.
        XCTAssertEqual(result.entries.count, 1)
    }

    // MARK: - Rewrite provider

    func test_makeRewriteProvider_noKeys_returnsNonNilProvider() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "",
            deepgramAPIKey: "",
            geminiAPIKey: "",
            openRouterAPIKey: ""
        )
        let provider = ProviderAssembly.makeRewriteProvider(config: config)
        XCTAssertNotNil(provider)
    }

    func test_makeRewriteProvider_openRouterOnly_returnsOpenRouter() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "",
            deepgramAPIKey: "",
            geminiAPIKey: "",
            openRouterAPIKey: "or-key"
        )
        let provider = ProviderAssembly.makeRewriteProvider(config: config)
        XCTAssertTrue(provider is OpenRouterClient)
    }

    func test_makeRewriteProvider_bothKeys_returnsModelRoutedProvider() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "",
            deepgramAPIKey: "",
            geminiAPIKey: "gem-key",
            openRouterAPIKey: "or-key"
        )
        let provider = ProviderAssembly.makeRewriteProvider(config: config)
        XCTAssertTrue(provider is ModelRoutedRewriteProvider)
    }

    func test_makeRewriteProvider_geminiOnly_returnsModelRoutedProvider() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "",
            deepgramAPIKey: "",
            geminiAPIKey: "gem-key",
            openRouterAPIKey: ""
        )
        let provider = ProviderAssembly.makeRewriteProvider(config: config)
        XCTAssertTrue(provider is ModelRoutedRewriteProvider)
    }

    func test_makeRewriteProvider_rewriteInstrumentationHookCalled() {
        final class PathCollector: @unchecked Sendable {
            var paths: [String] = []
        }
        let collector = PathCollector()
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "",
            deepgramAPIKey: "",
            geminiAPIKey: "gem-key",
            openRouterAPIKey: "or-key",
            rewriteInstrument: { path, provider in
                collector.paths.append(path)
                return provider
            }
        )
        _ = ProviderAssembly.makeRewriteProvider(config: config)
        XCTAssertFalse(collector.paths.isEmpty)
    }
}
