import Testing
@testable import VoxCore

@Suite("ModelRoutedRewriteProvider")
struct ModelRoutedRewriteProviderTests {
    @Test("Routes bare Gemini model id to Gemini provider")
    func routesBareGeminiToGemini() async throws {
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
    func routesPrefixedGeminiToGemini() async throws {
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
    func fallsBackFromGeminiToOpenRouter() async throws {
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
    func routesOpenRouterModelToOpenRouter() async throws {
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
    func fallsBackToGeminiWhenOpenRouterMissing() async throws {
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
    func fallsBackFromOpenRouterToGemini() async throws {
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
}
// MARK: - Test Double

private final class StubRewriteProvider: RewriteProvider, @unchecked Sendable {
    let result: Result<String, Error>
    private(set) var callCount = 0
    private(set) var lastModel: String?

    init(result: Result<String, Error>) {
        self.result = result
    }

    func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        callCount += 1
        lastModel = model
        return try result.get()
    }
}
