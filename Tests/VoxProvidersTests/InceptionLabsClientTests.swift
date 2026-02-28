import Foundation
import Testing
import VoxCore
@testable import VoxProviders

// Isolated stub to avoid cross-suite interference with URLProtocolStub.
private final class InceptionStub: URLProtocol, @unchecked Sendable {
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

private func makeInceptionSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [InceptionStub.self]
    return URLSession(configuration: config)
}

private final class Capture<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T

    init(_ value: T) { _value = value }

    var value: T {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}

@Suite("InceptionLabsClient", .serialized)
struct InceptionLabsClientTests {
    init() {
        InceptionStub.handler = nil
    }

    // MARK: - Request Format

    @Test("Sends model and messages in OpenAI-compatible format")
    func requestFormat() async throws {
        let captured = Capture<[String: Any]?>(nil)
        InceptionStub.handler = { request in
            let data = bodyData(from: request)
            captured.value = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"choices":[{"message":{"content":"fixed"}}]}
                """.utf8)
            )
        }

        let client = InceptionLabsClient(apiKey: "test-key", session: makeInceptionSession())
        _ = try await client.rewrite(transcript: "hello", systemPrompt: "fix grammar", model: "mercury-2")

        let body = try #require(captured.value)
        #expect(body["model"] as? String == "mercury-2")

        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.count == 2)
        #expect(messages[0]["role"] as? String == "system")
        #expect(messages[0]["content"] as? String == "fix grammar")
        #expect(messages[1]["role"] as? String == "user")
        #expect(messages[1]["content"] as? String == "hello")
    }

    @Test("Sends Authorization Bearer header")
    func authHeader() async throws {
        let captured = Capture<URLRequest?>(nil)
        InceptionStub.handler = { request in
            captured.value = request
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"choices":[{"message":{"content":"ok"}}]}
                """.utf8)
            )
        }

        let client = InceptionLabsClient(apiKey: "sk-inception-123", session: makeInceptionSession())
        _ = try await client.rewrite(transcript: "hi", systemPrompt: "fix", model: "mercury-2")

        let req = try #require(captured.value)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer sk-inception-123")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("Posts to InceptionLabs chat completions endpoint")
    func correctEndpoint() async throws {
        let captured = Capture<URL?>(nil)
        InceptionStub.handler = { request in
            captured.value = request.url
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"choices":[{"message":{"content":"ok"}}]}
                """.utf8)
            )
        }

        let client = InceptionLabsClient(apiKey: "key", session: makeInceptionSession())
        _ = try await client.rewrite(transcript: "hi", systemPrompt: "fix", model: "mercury-2")

        let url = try #require(captured.value)
        #expect(url.absoluteString == "https://api.inceptionlabs.ai/v1/chat/completions")
    }

    // MARK: - Response Parsing

    @Test("Extracts content from OpenAI-compatible response")
    func parseResponse() async throws {
        InceptionStub.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"choices":[{"message":{"content":"I went to the store."}}]}
                """.utf8)
            )
        }

        let client = InceptionLabsClient(apiKey: "key", session: makeInceptionSession())
        let result = try await client.rewrite(transcript: "i went too the store", systemPrompt: "fix", model: "mercury-2")
        #expect(result == "I went to the store.")
    }

    // MARK: - Error Mapping

    @Test("Maps 401 to auth error")
    func maps401() async throws {
        InceptionStub.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = InceptionLabsClient(apiKey: "bad-key", session: makeInceptionSession())
        do {
            _ = try await client.rewrite(transcript: "t", systemPrompt: "p", model: "mercury-2")
            Issue.record("Expected error")
        } catch {
            #expect(error as? RewriteError == .auth)
        }
    }

    @Test("Maps 402 to quotaExceeded")
    func maps402() async throws {
        InceptionStub.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 402, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = InceptionLabsClient(apiKey: "key", session: makeInceptionSession())
        do {
            _ = try await client.rewrite(transcript: "t", systemPrompt: "p", model: "mercury-2")
            Issue.record("Expected error")
        } catch {
            #expect(error as? RewriteError == .quotaExceeded)
        }
    }

    @Test("Maps 429 to throttled")
    func maps429() async throws {
        InceptionStub.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = InceptionLabsClient(apiKey: "key", session: makeInceptionSession())
        do {
            _ = try await client.rewrite(transcript: "t", systemPrompt: "p", model: "mercury-2")
            Issue.record("Expected error")
        } catch {
            #expect(error as? RewriteError == .throttled)
        }
    }

    @Test("Maps 500 to network error")
    func maps500() async throws {
        InceptionStub.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = InceptionLabsClient(apiKey: "key", session: makeInceptionSession())
        do {
            _ = try await client.rewrite(transcript: "t", systemPrompt: "p", model: "mercury-2")
            Issue.record("Expected error")
        } catch let error as RewriteError {
            if case .network(let msg) = error {
                #expect(msg == "HTTP 500")
            } else {
                Issue.record("Expected network error, got \(error)")
            }
        }
    }

    @Test("Maps 404 to invalidRequest with error message")
    func maps404() async throws {
        InceptionStub.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!,
                Data("""
                {"error":{"message":"Model not found"}}
                """.utf8)
            )
        }

        let client = InceptionLabsClient(apiKey: "key", session: makeInceptionSession())
        do {
            _ = try await client.rewrite(transcript: "t", systemPrompt: "p", model: "mercury-999")
            Issue.record("Expected error")
        } catch let error as RewriteError {
            if case .invalidRequest(let msg) = error {
                #expect(msg == "Model not found")
            } else {
                Issue.record("Expected invalidRequest, got \(error)")
            }
        }
    }

    @Test("Propagates cancellation cleanly")
    func cancellationPropagates() async throws {
        // Use a semaphore to block the stub until the task is cancelled.
        let sem = DispatchSemaphore(value: 0)
        InceptionStub.handler = { request in
            sem.wait()
            throw URLError(.cancelled)
        }

        let client = InceptionLabsClient(apiKey: "key", session: makeInceptionSession())
        let task = Task {
            try await client.rewrite(transcript: "t", systemPrompt: "p", model: "mercury-2")
        }
        task.cancel()
        sem.signal()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation error")
        } catch is CancellationError {
            // Expected: cooperative cancellation
        } catch is URLError {
            // Also expected: URLSession surfaces .cancelled as URLError
        }
    }
}
