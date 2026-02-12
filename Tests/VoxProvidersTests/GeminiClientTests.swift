import Foundation
import Testing
import VoxCore
@testable import VoxProviders

// Isolated stub to avoid cross-suite interference with URLProtocolStub.
private final class GeminiStub: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))? {
        get { lock.withLock { _handler } }
        set { lock.withLock { _handler = newValue } }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeGeminiSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [GeminiStub.self]
    return URLSession(configuration: config)
}

/// Thread-safe capture box for use in stub handlers.
private final class Capture<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T

    init(_ value: T) { _value = value }

    var value: T {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}

@Suite("GeminiClient", .serialized)
struct GeminiClientTests {
    init() {
        GeminiStub.handler = nil
    }

    // MARK: - Request Format

    @Test("Sends systemInstruction and contents in Gemini format")
    func requestFormat() async throws {
        let captured = Capture<[String: Any]?>(nil)
        GeminiStub.handler = { request in
            let data = bodyData(from: request)
            captured.value = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"candidates":[{"content":{"parts":[{"text":"fixed"}],"role":"model"},"finishReason":"STOP"}]}
                """.utf8)
            )
        }

        let client = GeminiClient(apiKey: "test-key", session: makeGeminiSession())
        _ = try await client.rewrite(transcript: "hello", systemPrompt: "fix grammar", model: "gemini-2.5-flash-lite")

        let body = try #require(captured.value)

        let sysInstruction = try #require(body["systemInstruction"] as? [String: Any])
        let sysParts = try #require(sysInstruction["parts"] as? [[String: Any]])
        #expect(sysParts.first?["text"] as? String == "fix grammar")

        let contents = try #require(body["contents"] as? [[String: Any]])
        #expect(contents.first?["role"] as? String == "user")
        let parts = try #require((contents.first?["parts"] as? [[String: Any]]))
        #expect(parts.first?["text"] as? String == "hello")
    }

    @Test("Uses model name in URL path")
    func modelInURL() async throws {
        let captured = Capture<URL?>(nil)
        GeminiStub.handler = { request in
            captured.value = request.url
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"candidates":[{"content":{"parts":[{"text":"ok"}],"role":"model"}}]}
                """.utf8)
            )
        }

        let client = GeminiClient(apiKey: "test-key", session: makeGeminiSession())
        _ = try await client.rewrite(transcript: "hi", systemPrompt: "fix", model: "gemini-2.5-flash-lite")

        let url = try #require(captured.value)
        #expect(url.absoluteString.contains("models/gemini-2.5-flash-lite:generateContent"))
    }

    @Test("Sets x-goog-api-key header")
    func apiKeyHeader() async throws {
        let captured = Capture<URLRequest?>(nil)
        GeminiStub.handler = { request in
            captured.value = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"candidates":[{"content":{"parts":[{"text":"ok"}],"role":"model"}}]}
                """.utf8)
            )
        }

        let client = GeminiClient(apiKey: "AIza-test-123", session: makeGeminiSession())
        _ = try await client.rewrite(transcript: "hi", systemPrompt: "fix", model: "gemini-2.5-flash-lite")

        let req = try #require(captured.value)
        #expect(req.value(forHTTPHeaderField: "x-goog-api-key") == "AIza-test-123")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    // MARK: - Response Parsing

    @Test("Extracts text from Gemini response")
    func parseResponse() async throws {
        GeminiStub.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {
                  "candidates": [{
                    "content": {
                      "parts": [{"text": "I went to the store."}],
                      "role": "model"
                    },
                    "finishReason": "STOP"
                  }],
                  "usageMetadata": {"promptTokenCount": 10, "candidatesTokenCount": 6, "totalTokenCount": 16}
                }
                """.utf8)
            )
        }

        let client = GeminiClient(apiKey: "key", session: makeGeminiSession())
        let result = try await client.rewrite(transcript: "i went too the store", systemPrompt: "fix", model: "gemini-2.5-flash-lite")
        #expect(result == "I went to the store.")
    }

    // MARK: - Error Mapping

    @Test("Maps 401 to auth error")
    func maps401() async throws {
        GeminiStub.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = GeminiClient(apiKey: "bad-key", session: makeGeminiSession())
        do {
            _ = try await client.rewrite(transcript: "t", systemPrompt: "p", model: "m")
            Issue.record("Expected error")
        } catch {
            #expect(error as? RewriteError == .auth)
        }
    }

    @Test("Maps 403 to auth error")
    func maps403() async throws {
        GeminiStub.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = GeminiClient(apiKey: "key", session: makeGeminiSession())
        do {
            _ = try await client.rewrite(transcript: "t", systemPrompt: "p", model: "m")
            Issue.record("Expected error")
        } catch {
            #expect(error as? RewriteError == .auth)
        }
    }

    @Test("Maps 429 to throttled")
    func maps429() async throws {
        GeminiStub.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = GeminiClient(apiKey: "key", session: makeGeminiSession())
        do {
            _ = try await client.rewrite(transcript: "t", systemPrompt: "p", model: "m")
            Issue.record("Expected error")
        } catch {
            #expect(error as? RewriteError == .throttled)
        }
    }

    @Test("Maps 502 to network error")
    func maps502() async throws {
        GeminiStub.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 502, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = GeminiClient(apiKey: "key", session: makeGeminiSession())
        do {
            _ = try await client.rewrite(transcript: "t", systemPrompt: "p", model: "m")
            Issue.record("Expected error")
        } catch let error as RewriteError {
            if case .network(let msg) = error {
                #expect(msg == "HTTP 502")
            } else {
                Issue.record("Expected network error, got \(error)")
            }
        }
    }

    @Test("Maps 400 to invalidRequest with error message")
    func maps400() async throws {
        GeminiStub.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"error":{"message":"Invalid model name","code":400}}
                """.utf8)
            )
        }

        let client = GeminiClient(apiKey: "key", session: makeGeminiSession())
        do {
            _ = try await client.rewrite(transcript: "t", systemPrompt: "p", model: "bad-model")
            Issue.record("Expected error")
        } catch let error as RewriteError {
            if case .invalidRequest(let msg) = error {
                #expect(msg == "Invalid model name")
            } else {
                Issue.record("Expected invalidRequest, got \(error)")
            }
        }
    }
}
