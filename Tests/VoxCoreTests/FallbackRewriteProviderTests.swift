import Testing
@testable import VoxCore

@Suite("FallbackRewriteProvider")
struct FallbackRewriteProviderTests {
    @Test("Returns first provider result on success")
    func firstProviderSucceeds() async throws {
        let primary = StubRewriteProvider(result: .success("rewritten"))
        let fallback = StubRewriteProvider(result: .success("fallback"))
        let sut = FallbackRewriteProvider(entries: [
            .init(provider: primary, label: "Primary"),
            .init(provider: fallback, label: "Fallback"),
        ])

        let result = try await sut.rewrite(transcript: "raw", systemPrompt: "", model: "model-x")
        #expect(result == "rewritten")
        #expect(primary.callCount == 1)
        #expect(fallback.callCount == 0)
        #expect(primary.lastModel == "model-x")
    }

    @Test("Falls back on primary failure")
    func fallsBackOnError() async throws {
        let primary = StubRewriteProvider(result: .failure(RewriteError.network("503")))
        let fallback = StubRewriteProvider(result: .success("fallback result"))
        let sut = FallbackRewriteProvider(entries: [
            .init(provider: primary, label: "Primary"),
            .init(provider: fallback, label: "Fallback"),
        ])

        let result = try await sut.rewrite(transcript: "raw", systemPrompt: "", model: "model-y")
        #expect(result == "fallback result")
        #expect(primary.callCount == 1)
        #expect(fallback.callCount == 1)
        #expect(primary.lastModel == "model-y")
        #expect(fallback.lastModel == "model-y")
    }

    @Test("Throws last error when all providers fail")
    func allProvidersFail() async throws {
        let primary = StubRewriteProvider(result: .failure(RewriteError.network("DNS")))
        let fallback = StubRewriteProvider(result: .failure(RewriteError.throttled))
        let sut = FallbackRewriteProvider(entries: [
            .init(provider: primary, label: "Primary"),
            .init(provider: fallback, label: "Fallback"),
        ])

        await #expect(throws: RewriteError.throttled) {
            try await sut.rewrite(transcript: "raw", systemPrompt: "", model: "ignored")
        }
    }

    @Test("CancellationError propagates immediately without trying fallback")
    func cancellationPropagates() async throws {
        let primary = StubRewriteProvider(result: .failure(CancellationError()))
        let fallback = StubRewriteProvider(result: .success("should not reach"))
        let sut = FallbackRewriteProvider(entries: [
            .init(provider: primary, label: "Primary"),
            .init(provider: fallback, label: "Fallback"),
        ])

        await #expect(throws: CancellationError.self) {
            try await sut.rewrite(transcript: "raw", systemPrompt: "", model: "ignored")
        }
        #expect(fallback.callCount == 0)
    }

    @Test("Passes requested model to each provider")
    func modelPassthrough() async throws {
        let primary = StubRewriteProvider(result: .failure(RewriteError.network("fail")))
        let fallback = StubRewriteProvider(result: .success("ok"))
        let sut = FallbackRewriteProvider(entries: [
            .init(provider: primary, label: "Gemini"),
            .init(provider: fallback, label: "OpenRouter"),
        ])

        _ = try await sut.rewrite(transcript: "raw", systemPrompt: "sys", model: "openai/gpt-5.2")
        #expect(primary.lastModel == "openai/gpt-5.2")
        #expect(fallback.lastModel == "openai/gpt-5.2")
    }

    @Test("Auth error on primary still triggers fallback")
    func authErrorFallsBack() async throws {
        let primary = StubRewriteProvider(result: .failure(RewriteError.auth))
        let fallback = StubRewriteProvider(result: .success("recovered"))
        let sut = FallbackRewriteProvider(entries: [
            .init(provider: primary, label: "Primary"),
            .init(provider: fallback, label: "Fallback"),
        ])

        let result = try await sut.rewrite(transcript: "raw", systemPrompt: "", model: "ignored")
        #expect(result == "recovered")
    }

    @Test("Three-deep fallback chain works")
    func threeDeepChain() async throws {
        let a = StubRewriteProvider(result: .failure(RewriteError.network("a")))
        let b = StubRewriteProvider(result: .failure(RewriteError.throttled))
        let c = StubRewriteProvider(result: .success("third time"))
        let sut = FallbackRewriteProvider(entries: [
            .init(provider: a, label: "A"),
            .init(provider: b, label: "B"),
            .init(provider: c, label: "C"),
        ])

        let result = try await sut.rewrite(transcript: "raw", systemPrompt: "", model: "ignored")
        #expect(result == "third time")
        #expect(a.callCount == 1)
        #expect(b.callCount == 1)
        #expect(c.callCount == 1)
    }
}

// MARK: - Test Doubles

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
