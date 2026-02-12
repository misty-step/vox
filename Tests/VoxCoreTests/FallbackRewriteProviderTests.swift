import Testing
@testable import VoxCore

@Suite("FallbackRewriteProvider")
struct FallbackRewriteProviderTests {
    @Test("Returns first provider result on success")
    func firstProviderSucceeds() async throws {
        let primary = StubRewriteProvider(result: .success("rewritten"))
        let fallback = StubRewriteProvider(result: .success("fallback"))
        let sut = FallbackRewriteProvider(entries: [
            .init(provider: primary, model: "model-a", label: "Primary"),
            .init(provider: fallback, model: "model-b", label: "Fallback"),
        ])

        let result = try await sut.rewrite(transcript: "raw", systemPrompt: "", model: "ignored")
        #expect(result == "rewritten")
        #expect(primary.callCount == 1)
        #expect(fallback.callCount == 0)
    }

    @Test("Falls back on primary failure")
    func fallsBackOnError() async throws {
        let primary = StubRewriteProvider(result: .failure(RewriteError.network("503")))
        let fallback = StubRewriteProvider(result: .success("fallback result"))
        let sut = FallbackRewriteProvider(entries: [
            .init(provider: primary, model: "model-a", label: "Primary"),
            .init(provider: fallback, model: "model-b", label: "Fallback"),
        ])

        let result = try await sut.rewrite(transcript: "raw", systemPrompt: "", model: "ignored")
        #expect(result == "fallback result")
        #expect(primary.callCount == 1)
        #expect(fallback.callCount == 1)
    }

    @Test("Throws last error when all providers fail")
    func allProvidersFail() async throws {
        let primary = StubRewriteProvider(result: .failure(RewriteError.network("DNS")))
        let fallback = StubRewriteProvider(result: .failure(RewriteError.throttled))
        let sut = FallbackRewriteProvider(entries: [
            .init(provider: primary, model: "model-a", label: "Primary"),
            .init(provider: fallback, model: "model-b", label: "Fallback"),
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
            .init(provider: primary, model: "model-a", label: "Primary"),
            .init(provider: fallback, model: "model-b", label: "Fallback"),
        ])

        await #expect(throws: CancellationError.self) {
            try await sut.rewrite(transcript: "raw", systemPrompt: "", model: "ignored")
        }
        #expect(fallback.callCount == 0)
    }

    @Test("Passes entry-specific model to each provider")
    func modelPassthrough() async throws {
        let primary = StubRewriteProvider(result: .failure(RewriteError.network("fail")))
        let fallback = StubRewriteProvider(result: .success("ok"))
        let sut = FallbackRewriteProvider(entries: [
            .init(provider: primary, model: "gemini-2.5-flash-lite", label: "Gemini"),
            .init(provider: fallback, model: "google/gemini-2.5-flash-lite", label: "OpenRouter"),
        ])

        _ = try await sut.rewrite(transcript: "raw", systemPrompt: "sys", model: "should-be-ignored")
        #expect(primary.lastModel == "gemini-2.5-flash-lite")
        #expect(fallback.lastModel == "google/gemini-2.5-flash-lite")
    }

    @Test("Auth error on primary still triggers fallback")
    func authErrorFallsBack() async throws {
        let primary = StubRewriteProvider(result: .failure(RewriteError.auth))
        let fallback = StubRewriteProvider(result: .success("recovered"))
        let sut = FallbackRewriteProvider(entries: [
            .init(provider: primary, model: "model-a", label: "Primary"),
            .init(provider: fallback, model: "model-b", label: "Fallback"),
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
            .init(provider: a, model: "m1", label: "A"),
            .init(provider: b, model: "m2", label: "B"),
            .init(provider: c, model: "m3", label: "C"),
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
