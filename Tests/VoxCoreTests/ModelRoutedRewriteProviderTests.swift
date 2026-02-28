import Foundation
import Testing
@testable import VoxCore

@Suite("ModelRoutedRewriteProvider")
struct ModelRoutedRewriteProviderTests {
    @Test("Routes bare Gemini model id to Gemini provider")
    func test_rewrite_routesBareGeminiToGemini() async throws {
        let gemini = StubRewriteProvider(result: .success("gemini ok"))
        let openRouter = StubRewriteProvider(result: .success("openrouter ok"))
        let sut = ModelRoutedRewriteProvider(
            gemini: gemini,
            openRouter: openRouter,
            fallbackGeminiModel: "gemini-2.5-flash-lite"
        )

        let result = try await sut.rewrite(transcript: "t", systemPrompt: "s", model: "gemini-2.5-flash-lite")
        #expect(result == "gemini ok")
        #expect(gemini.callCount == 1)
        #expect(openRouter.callCount == 0)
        #expect(gemini.lastModel == "gemini-2.5-flash-lite")
    }

    @Test("Routes google/gemini prefixed id to Gemini provider (strips prefix)")
    func test_rewrite_routesPrefixedGeminiToGemini() async throws {
        let gemini = StubRewriteProvider(result: .success("gemini ok"))
        let openRouter = StubRewriteProvider(result: .success("openrouter ok"))
        let sut = ModelRoutedRewriteProvider(
            gemini: gemini,
            openRouter: openRouter,
            fallbackGeminiModel: "gemini-2.5-flash-lite"
        )

        let result = try await sut.rewrite(transcript: "t", systemPrompt: "s", model: "google/gemini-2.5-flash-lite")
        #expect(result == "gemini ok")
        #expect(gemini.callCount == 1)
        #expect(openRouter.callCount == 0)
        #expect(gemini.lastModel == "gemini-2.5-flash-lite")
    }

    @Test("Falls back to OpenRouter when Gemini direct fails for a Gemini model")
    func test_rewrite_fallsBackFromGeminiToOpenRouter() async throws {
        let gemini = StubRewriteProvider(result: .failure(RewriteError.network("boom")))
        let openRouter = StubRewriteProvider(result: .success("openrouter ok"))
        let sut = ModelRoutedRewriteProvider(
            gemini: gemini,
            openRouter: openRouter,
            fallbackGeminiModel: "gemini-2.5-flash-lite"
        )

        let result = try await sut.rewrite(transcript: "t", systemPrompt: "s", model: "gemini-2.5-flash-lite")
        #expect(result == "openrouter ok")
        #expect(gemini.callCount == 1)
        #expect(openRouter.callCount == 1)
        #expect(openRouter.lastModel == "gemini-2.5-flash-lite")
    }

    @Test("Routes OpenRouter-only model to OpenRouter without calling Gemini")
    func test_rewrite_routesOpenRouterModelToOpenRouter() async throws {
        let gemini = StubRewriteProvider(result: .success("gemini ok"))
        let openRouter = StubRewriteProvider(result: .success("openrouter ok"))
        let sut = ModelRoutedRewriteProvider(
            gemini: gemini,
            openRouter: openRouter,
            fallbackGeminiModel: "gemini-2.5-flash-lite"
        )

        let result = try await sut.rewrite(transcript: "t", systemPrompt: "s", model: "x-ai/grok-4.1-fast")
        #expect(result == "openrouter ok")
        #expect(openRouter.callCount == 1)
        #expect(gemini.callCount == 0)
        #expect(openRouter.lastModel == "x-ai/grok-4.1-fast")
    }

    @Test("Falls back to Gemini fallback model when OpenRouter is unavailable for OpenRouter-only model")
    func test_rewrite_fallsBackToGeminiWhenOpenRouterMissing() async throws {
        let gemini = StubRewriteProvider(result: .success("gemini ok"))
        let sut = ModelRoutedRewriteProvider(
            gemini: gemini,
            openRouter: nil,
            fallbackGeminiModel: "gemini-2.5-flash-lite"
        )

        let result = try await sut.rewrite(transcript: "t", systemPrompt: "s", model: "x-ai/grok-4.1-fast")
        #expect(result == "gemini ok")
        #expect(gemini.callCount == 1)
        #expect(gemini.lastModel == "gemini-2.5-flash-lite")
    }

    @Test("Falls back to Gemini fallback model when OpenRouter fails for OpenRouter-only model")
    func test_rewrite_fallsBackFromOpenRouterToGemini() async throws {
        let gemini = StubRewriteProvider(result: .success("gemini ok"))
        let openRouter = StubRewriteProvider(result: .failure(RewriteError.network("503")))
        let sut = ModelRoutedRewriteProvider(
            gemini: gemini,
            openRouter: openRouter,
            fallbackGeminiModel: "gemini-2.5-flash-lite"
        )

        let result = try await sut.rewrite(transcript: "t", systemPrompt: "s", model: "x-ai/grok-4.1-fast")
        #expect(result == "gemini ok")
        #expect(openRouter.callCount == 1)
        #expect(gemini.callCount == 1)
        #expect(gemini.lastModel == "gemini-2.5-flash-lite")
    }

    @Test("Routes mercury- model to inception provider")
    func test_rewrite_routesMercuryToInception() async throws {
        let gemini = StubRewriteProvider(result: .success("gemini ok"))
        let openRouter = StubRewriteProvider(result: .success("openrouter ok"))
        let inception = StubRewriteProvider(result: .success("inception ok"))
        let sut = ModelRoutedRewriteProvider(
            gemini: gemini,
            openRouter: openRouter,
            inception: inception,
            fallbackGeminiModel: "gemini-2.5-flash-lite"
        )

        let result = try await sut.rewrite(transcript: "t", systemPrompt: "s", model: "mercury-2")
        #expect(result == "inception ok")
        #expect(inception.callCount == 1)
        #expect(inception.lastModel == "mercury-2")
        #expect(gemini.callCount == 0)
        #expect(openRouter.callCount == 0)
    }

    @Test("Falls back to Gemini when inception fails for mercury model")
    func test_rewrite_fallsBackFromInceptionToGemini() async throws {
        let gemini = StubRewriteProvider(result: .success("gemini ok"))
        let inception = StubRewriteProvider(result: .failure(RewriteError.network("503")))
        let sut = ModelRoutedRewriteProvider(
            gemini: gemini,
            openRouter: nil,
            inception: inception,
            fallbackGeminiModel: "gemini-2.5-flash-lite"
        )

        let result = try await sut.rewrite(transcript: "t", systemPrompt: "s", model: "mercury-2")
        #expect(result == "gemini ok")
        #expect(inception.callCount == 1)
        #expect(gemini.callCount == 1)
        #expect(gemini.lastModel == "gemini-2.5-flash-lite")
    }

    @Test("Falls back to Gemini when no inception client for mercury model")
    func test_rewrite_noInceptionFallsBackToGemini() async throws {
        let gemini = StubRewriteProvider(result: .success("gemini ok"))
        let sut = ModelRoutedRewriteProvider(
            gemini: gemini,
            openRouter: nil,
            inception: nil,
            fallbackGeminiModel: "gemini-2.5-flash-lite"
        )

        let result = try await sut.rewrite(transcript: "t", systemPrompt: "s", model: "mercury-2")
        #expect(result == "gemini ok")
        #expect(gemini.callCount == 1)
        #expect(gemini.lastModel == "gemini-2.5-flash-lite")
    }

    @Test("Throws auth when no providers available for mercury model")
    func test_rewrite_noProvidersThrowsAuthForMercury() async throws {
        let sut = ModelRoutedRewriteProvider(
            gemini: nil,
            openRouter: nil,
            inception: nil,
            fallbackGeminiModel: "gemini-2.5-flash-lite"
        )

        do {
            _ = try await sut.rewrite(transcript: "t", systemPrompt: "s", model: "mercury-2")
            Issue.record("Expected error")
        } catch {
            #expect(error as? RewriteError == .auth)
        }
    }
}
// MARK: - Test Double

private final class StubRewriteProvider: RewriteProvider, @unchecked Sendable {
    private let lock = NSLock()
    let result: Result<String, Error>
    private var _callCount = 0
    private var _lastModel: String?

    var callCount: Int {
        lock.withLock { _callCount }
    }

    var lastModel: String? {
        lock.withLock { _lastModel }
    }

    init(result: Result<String, Error>) {
        self.result = result
    }

    func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        lock.withLock {
            _callCount += 1
            _lastModel = model
        }
        return try result.get()
    }
}
