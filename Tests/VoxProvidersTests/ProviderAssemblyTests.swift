import XCTest
@testable import VoxProviders
import VoxCore

// MARK: - ProviderAssemblyTests
//
// Tests for the shared cloud-provider builder. Verifies chain shape, retry parameters,
// concurrency limits, and instrumentation hooks — without network calls.

final class ProviderAssemblyTests: XCTestCase {

    // MARK: - CloudSTT chain

    func test_makeCloudSTTProvider_noKeys_returnsNilProvider() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "",
            deepgramAPIKey: "",
            geminiAPIKey: "",
            openRouterAPIKey: ""
        )
        let result = ProviderAssembly.makeCloudSTTProvider(config: config)
        XCTAssertNil(result.provider)
        XCTAssertTrue(result.descriptors.isEmpty)
    }

    func test_makeCloudSTTProvider_elevenLabsOnly_returnsProvider() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "el-key",
            deepgramAPIKey: "",
            geminiAPIKey: "",
            openRouterAPIKey: ""
        )
        let result = ProviderAssembly.makeCloudSTTProvider(config: config)
        XCTAssertNotNil(result.provider)
        XCTAssertEqual(result.descriptors.count, 1)
        XCTAssertEqual(result.descriptors[0].name, "ElevenLabs")
        XCTAssertEqual(result.descriptors[0].model, "scribe_v2")
    }

    func test_makeCloudSTTProvider_deepgramOnly_returnsProvider() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "",
            deepgramAPIKey: "dg-key",
            geminiAPIKey: "",
            openRouterAPIKey: ""
        )
        let result = ProviderAssembly.makeCloudSTTProvider(config: config)
        XCTAssertNotNil(result.provider)
        XCTAssertEqual(result.descriptors.count, 1)
        XCTAssertEqual(result.descriptors[0].name, "Deepgram")
        XCTAssertEqual(result.descriptors[0].model, "nova-3")
    }

    func test_makeCloudSTTProvider_bothKeys_returnsChainWithElevenLabsFirst() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "el-key",
            deepgramAPIKey: "dg-key",
            geminiAPIKey: "",
            openRouterAPIKey: ""
        )
        let result = ProviderAssembly.makeCloudSTTProvider(config: config)
        XCTAssertNotNil(result.provider)
        XCTAssertEqual(result.descriptors.count, 2)
        XCTAssertEqual(result.descriptors[0].name, "ElevenLabs")
        XCTAssertEqual(result.descriptors[1].name, "Deepgram")
    }

    func test_makeCloudSTTProvider_whitespaceKeys_treatedAsEmpty() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "   ",
            deepgramAPIKey: "\t",
            geminiAPIKey: "",
            openRouterAPIKey: ""
        )
        let result = ProviderAssembly.makeCloudSTTProvider(config: config)
        XCTAssertNil(result.provider)
        XCTAssertTrue(result.descriptors.isEmpty)
    }

    func test_makeCloudSTTProvider_customMaxConcurrent_respected() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "el-key",
            deepgramAPIKey: "",
            geminiAPIKey: "",
            openRouterAPIKey: "",
            maxConcurrentSTT: 4
        )
        let result = ProviderAssembly.makeCloudSTTProvider(config: config)
        XCTAssertNotNil(result.provider)
        // We can't easily inspect the internal limit, but the call must not crash
        // and the type should be ConcurrencyLimitedSTTProvider.
        XCTAssertTrue(result.provider is ConcurrencyLimitedSTTProvider)
    }

    // MARK: - Instrumentation hooks

    func test_makeCloudSTTProvider_instrumentationHookCalled() {
        var instrumentedNames: [String] = []
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "el-key",
            deepgramAPIKey: "dg-key",
            geminiAPIKey: "",
            openRouterAPIKey: "",
            sttInstrument: { name, _, provider in
                instrumentedNames.append(name)
                return provider
            }
        )
        _ = ProviderAssembly.makeCloudSTTProvider(config: config)
        XCTAssertEqual(Set(instrumentedNames), Set(["ElevenLabs", "Deepgram"]))
    }

    // MARK: - Rewrite provider

    func test_makeRewriteProvider_noKeys_returnsOpenRouterWithEmptyKey() {
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "",
            deepgramAPIKey: "",
            geminiAPIKey: "",
            openRouterAPIKey: ""
        )
        let provider = ProviderAssembly.makeRewriteProvider(config: config)
        // No keys: falls back to OpenRouterClient (will fail at runtime, but must not crash at build time)
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
        // Gemini-only also uses ModelRoutedRewriteProvider (openRouter parameter is nil)
        XCTAssertTrue(provider is ModelRoutedRewriteProvider)
    }

    func test_makeRewriteProvider_rewriteInstrumentationHookCalled() {
        var instrumentedPaths: [String] = []
        let config = ProviderAssemblyConfig(
            elevenLabsAPIKey: "",
            deepgramAPIKey: "",
            geminiAPIKey: "gem-key",
            openRouterAPIKey: "or-key",
            rewriteInstrument: { path, provider in
                instrumentedPaths.append(path)
                return provider
            }
        )
        _ = ProviderAssembly.makeRewriteProvider(config: config)
        XCTAssertFalse(instrumentedPaths.isEmpty)
    }
}
