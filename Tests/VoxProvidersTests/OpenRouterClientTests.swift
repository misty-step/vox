import Foundation
import Testing
import VoxCore
@testable import VoxProviders

/// Thread-safe capture box for use in URLProtocolStub handlers.
private final class Capture<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T

    init(_ value: T) { _value = value }

    var value: T {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }

    func mutate(_ transform: (inout T) -> Void) {
        lock.withLock { transform(&_value) }
    }
}

@Suite("OpenRouterClient", .serialized)
struct OpenRouterClientTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    // MARK: - Provider Routing

    @Test("Request payload includes provider routing preferences")
    func providerRoutingInPayload() async throws {
        let captured = Capture<[String: Any]?>(nil)
        URLProtocolStub.requestHandler = { request in
            let data = bodyData(from: request)
            captured.value = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"choices":[{"message":{"content":"rewritten"}}]}
                """.utf8)
            )
        }

        let client = OpenRouterClient(apiKey: "test-key", session: makeStubbedSession())
        _ = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "test/model")

        let body = try #require(captured.value)
        let provider = try #require(body["provider"] as? [String: Any])
        #expect(provider["sort"] as? String == "latency")
        #expect(provider["allow_fallbacks"] as? Bool == true)
        #expect(provider["require_parameters"] as? Bool == true)
    }

    @Test("Request includes reasoning disabled")
    func reasoningDisabled() async throws {
        let captured = Capture<[String: Any]?>(nil)
        URLProtocolStub.requestHandler = { request in
            let data = bodyData(from: request)
            captured.value = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"choices":[{"message":{"content":"rewritten"}}]}
                """.utf8)
            )
        }

        let client = OpenRouterClient(apiKey: "test-key", session: makeStubbedSession())
        _ = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "test/model")

        let body = try #require(captured.value)
        let reasoning = try #require(body["reasoning"] as? [String: Any])
        #expect(reasoning["enabled"] as? Bool == false)
    }

    @Test("Model usage callback reports served model from response")
    func test_modelUsage_reportsServedModelWhenResponseIncludesModel() async throws {
        let usage = Capture<[(model: String, isFallback: Bool)]>([])
        URLProtocolStub.requestHandler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"model":"anthropic/claude-sonnet-4.5","choices":[{"message":{"content":"rewritten"}}]}
                """.utf8)
            )
        }

        let client = OpenRouterClient(
            apiKey: "test-key",
            session: makeStubbedSession(),
            onModelUsed: { model, isFallback in
                usage.mutate { $0.append((model: model, isFallback: isFallback)) }
            }
        )
        _ = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "test/model")

        #expect(usage.value.count == 1)
        #expect(usage.value[0].model == "anthropic/claude-sonnet-4.5")
        #expect(usage.value[0].isFallback == false)
    }

    @Test("Model usage callback falls back to requested model when response omits model")
    func test_modelUsage_fallsBackToRequestedModelWhenResponseOmitsModel() async throws {
        let usage = Capture<[String]>([])
        URLProtocolStub.requestHandler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"choices":[{"message":{"content":"rewritten"}}]}
                """.utf8)
            )
        }

        let client = OpenRouterClient(
            apiKey: "test-key",
            session: makeStubbedSession(),
            onModelUsed: { model, _ in
                usage.mutate { $0.append(model) }
            }
        )
        _ = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "gemini-2.5-flash-lite")

        #expect(usage.value == ["google/gemini-2.5-flash-lite"])
    }

    @Test("Model usage callback marks fallback when second model succeeds")
    func test_modelUsage_marksFallbackWhenFallbackModelSucceeds() async throws {
        let usage = Capture<[(model: String, isFallback: Bool)]>([])
        let attempts = Capture(0)

        URLProtocolStub.requestHandler = { request in
            attempts.mutate { $0 += 1 }
            if attempts.value == 1 {
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!,
                    Data()
                )
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"model":"fallback/served-model","choices":[{"message":{"content":"ok"}}]}
                """.utf8)
            )
        }

        let client = OpenRouterClient(
            apiKey: "test-key",
            session: makeStubbedSession(),
            fallbackModels: ["fallback/model"],
            onModelUsed: { model, isFallback in
                usage.mutate { $0.append((model: model, isFallback: isFallback)) }
            }
        )
        let result = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "primary/model")

        #expect(result == "ok")
        #expect(usage.value.count == 1)
        #expect(usage.value[0].model == "fallback/served-model")
        #expect(usage.value[0].isFallback == true)
    }

    // MARK: - Fallback Model Chain

    @Test("Falls back to next model on throttled error")
    func fallbackOnThrottled() async throws {
        let counter = Capture(0)
        let models = Capture<[String]>([])

        URLProtocolStub.requestHandler = { request in
            counter.mutate { $0 += 1 }
            let current = counter.value
            let data = bodyData(from: request)
            if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                models.mutate { $0.append(body["model"] as? String ?? "") }
            }

            if current == 1 {
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!,
                    Data()
                )
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"choices":[{"message":{"content":"fallback result"}}]}
                """.utf8)
            )
        }

        let client = OpenRouterClient(
            apiKey: "test-key",
            session: makeStubbedSession(),
            fallbackModels: ["fallback/model"]
        )
        let result = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "primary/model")

        #expect(result == "fallback result")
        #expect(models.value == ["primary/model", "fallback/model"])
    }

    @Test("Falls back on 503 server error")
    func fallbackOn503() async throws {
        let counter = Capture(0)

        URLProtocolStub.requestHandler = { request in
            counter.mutate { $0 += 1 }
            if counter.value == 1 {
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!,
                    Data()
                )
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"choices":[{"message":{"content":"ok"}}]}
                """.utf8)
            )
        }

        let client = OpenRouterClient(
            apiKey: "test-key",
            session: makeStubbedSession(),
            fallbackModels: ["fallback/model"]
        )
        let result = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "primary/model")
        #expect(result == "ok")
    }

    @Test("Does not fall back on auth error")
    func noFallbackOnAuth() async throws {
        URLProtocolStub.requestHandler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        let client = OpenRouterClient(
            apiKey: "test-key",
            session: makeStubbedSession(),
            fallbackModels: ["fallback/model"]
        )

        await #expect(throws: RewriteError.self) {
            _ = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "primary/model")
        }
    }

    @Test("No fallback models means single attempt")
    func noFallbackModels() async throws {
        let counter = Capture(0)
        URLProtocolStub.requestHandler = { request in
            counter.mutate { $0 += 1 }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        let client = OpenRouterClient(apiKey: "test-key", session: makeStubbedSession())

        await #expect(throws: RewriteError.self) {
            _ = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "primary/model")
        }
        #expect(counter.value == 1)
    }

    @Test("Multiple fallback models tried in order")
    func multipleFallbacks() async throws {
        let models = Capture<[String]>([])

        URLProtocolStub.requestHandler = { request in
            let data = bodyData(from: request)
            if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                models.mutate { $0.append(body["model"] as? String ?? "") }
            }

            if models.value.count < 3 {
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!,
                    Data()
                )
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"choices":[{"message":{"content":"third time"}}]}
                """.utf8)
            )
        }

        let client = OpenRouterClient(
            apiKey: "test-key",
            session: makeStubbedSession(),
            fallbackModels: ["fallback/one", "fallback/two"]
        )
        let result = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "primary/model")

        #expect(result == "third time")
        #expect(models.value == ["primary/model", "fallback/one", "fallback/two"])
    }

    @Test("Model unavailable falls back to Mercury coder alias")
    func fallbackToMercuryCoderAliasOnModelUnavailable() async throws {
        let models = Capture<[String]>([])

        URLProtocolStub.requestHandler = { request in
            let data = bodyData(from: request)
            if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                models.mutate { $0.append(body["model"] as? String ?? "") }
            }

            if models.value.count == 1 {
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!,
                    Data("""
                    {"error":{"message":"Model inception/mercury not found"}}
                    """.utf8)
                )
            }

            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"choices":[{"message":{"content":"mercury-coder result"}}]}
                """.utf8)
            )
        }

        let client = OpenRouterClient(apiKey: "test-key", session: makeStubbedSession())
        let result = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "inception/mercury")

        #expect(result == "mercury-coder result")
        #expect(models.value == ["inception/mercury", "inception/mercury-coder"])
    }

    @Test("Model unavailable falls back to configured fallback models")
    func modelUnavailableFallsBackToConfiguredModels() async throws {
        let models = Capture<[String]>([])

        URLProtocolStub.requestHandler = { request in
            let data = bodyData(from: request)
            if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                models.mutate { $0.append(body["model"] as? String ?? "") }
            }

            if models.value.count == 1 {
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!,
                    Data("""
                    {"error":{"message":"No endpoints found for model primary/model"}}
                    """.utf8)
                )
            }

            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"choices":[{"message":{"content":"fallback result"}}]}
                """.utf8)
            )
        }

        let client = OpenRouterClient(
            apiKey: "test-key",
            session: makeStubbedSession(),
            fallbackModels: ["fallback/model"]
        )
        let result = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "primary/model")

        #expect(result == "fallback result")
        #expect(models.value == ["primary/model", "fallback/model"])
    }

    @Test("Does not fall back on non-model invalid request")
    func noFallbackOnGenericInvalidRequest() async throws {
        let counter = Capture(0)
        URLProtocolStub.requestHandler = { request in
            counter.mutate { $0 += 1 }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"error":{"message":"messages are required"}}
                """.utf8)
            )
        }

        let client = OpenRouterClient(
            apiKey: "test-key",
            session: makeStubbedSession(),
            fallbackModels: ["fallback/model"]
        )

        await #expect(throws: RewriteError.self) {
            _ = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "primary/model")
        }
        #expect(counter.value == 1)
    }

    // MARK: - HTTP Headers

    @Test("Sets required headers")
    func requiredHeaders() async throws {
        let captured = Capture<URLRequest?>(nil)
        URLProtocolStub.requestHandler = { request in
            captured.value = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"choices":[{"message":{"content":"ok"}}]}
                """.utf8)
            )
        }

        let client = OpenRouterClient(apiKey: "sk-test-123", session: makeStubbedSession())
        _ = try await client.rewrite(transcript: "hello", systemPrompt: "fix", model: "test/model")

        let req = try #require(captured.value)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-123")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(req.value(forHTTPHeaderField: "X-Title") == "Vox")
        #expect(req.value(forHTTPHeaderField: "HTTP-Referer") == "https://github.com/misty-step/vox")
    }

    // MARK: - Error Mapping

    @Test("Maps 429 to throttled")
    func maps429() async throws {
        URLProtocolStub.requestHandler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        let client = OpenRouterClient(apiKey: "key", session: makeStubbedSession())
        do {
            _ = try await client.rewrite(transcript: "t", systemPrompt: "p", model: "m")
            Issue.record("Expected error")
        } catch {
            #expect(error as? RewriteError == .throttled)
        }
    }

    @Test("Maps 502/503 to network error")
    func maps502503() async throws {
        for code in [502, 503] {
            URLProtocolStub.requestHandler = { request in
                (
                    HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!,
                    Data()
                )
            }

            let client = OpenRouterClient(apiKey: "key", session: makeStubbedSession())
            do {
                _ = try await client.rewrite(transcript: "t", systemPrompt: "p", model: "m")
                Issue.record("Expected error for \(code)")
            } catch let error as RewriteError {
                if case .network = error {
                    // expected
                } else {
                    Issue.record("Expected network error for \(code), got \(error)")
                }
            }
        }
    }
}
