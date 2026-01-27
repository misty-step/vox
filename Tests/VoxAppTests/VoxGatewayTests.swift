import Foundation
import XCTest
import VoxCore
@testable import VoxApp

private struct MockClock: VoxAuthClock {
    var now: Date
}

private actor GatewayAuthStorage: VoxAuthStorage {
    var token: String?
    var tokenExpiry: Date?
    var cache: EntitlementCache?
    private(set) var clearTokenCount = 0
    private(set) var clearEntitlementCount = 0

    init(token: String? = nil) {
        self.token = token
    }

    func loadToken() async -> (token: String, expiry: Date?)? {
        guard let token else { return nil }
        return (token, tokenExpiry)
    }

    func saveToken(_ token: String, expiry: Date?) async throws {
        self.token = token
        tokenExpiry = expiry
    }

    func clearToken() async {
        clearTokenCount += 1
        token = nil
        tokenExpiry = nil
    }

    func loadEntitlement() async -> EntitlementCache? {
        cache
    }

    func saveEntitlement(_ cache: EntitlementCache) async throws {
        self.cache = cache
    }

    func clearEntitlement() async {
        clearEntitlementCount += 1
        cache = nil
    }
}

private actor HTTPStub: VoxGatewayHTTPClient {
    typealias Inspector = @Sendable (URLRequest) async -> Void
    typealias Responder = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let inspector: Inspector?
    private let responder: Responder
    private(set) var lastRequest: URLRequest?

    init(
        inspector: Inspector? = nil,
        responder: @escaping Responder
    ) {
        self.inspector = inspector
        self.responder = responder
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let inspector {
            await inspector(request)
        }
        return try await responder(request)
    }

    func getLastRequest() -> URLRequest? { lastRequest }
}

private actor RewriteCapture {
    private(set) var level: ProcessingLevel?
    private(set) var error: Error?

    func setLevel(_ level: ProcessingLevel) {
        self.level = level
    }

    func setError(_ error: Error) {
        self.error = error
    }

    func snapshot() -> (ProcessingLevel?, Error?) {
        (level, error)
    }
}

@MainActor
final class VoxGatewayTests: XCTestCase {
    // Transcription
    func testTranscribeReturnsText() async throws {
        let baseURL = URL(string: "https://example.com")!
        let auth = makeAuth(token: "token")
        let stub = HTTPStub { request in
            let response = http(status: 200, url: request.url!)
            let data = json(["text": "hello world"])
            return (data, response)
        }
        let gateway = VoxGateway(baseURL: baseURL, auth: auth, http: stub)

        let text = try await gateway.transcribe(Data("audio".utf8))

        XCTAssertEqual(text, "hello world")
    }

    func testTranscribeWith401TriggersSignOut() async {
        let baseURL = URL(string: "https://example.com")!
        let storage = GatewayAuthStorage(token: "token")
        let auth = VoxAuth(storage: storage, gateway: nil, clock: MockClock(now: Date()))
        let stub = HTTPStub { request in
            let response = http(status: 401, url: request.url!)
            return (Data("unauthorized".utf8), response)
        }
        let gateway = VoxGateway(baseURL: baseURL, auth: auth, http: stub)

        do {
            _ = try await gateway.transcribe(Data("audio".utf8))
            XCTFail("Expected error")
        } catch {
            // expected
        }

        await waitForSignOut(storage: storage)
        XCTAssertEqual(auth.state, .needsAuth)
    }

    func testTranscribeWithNetworkErrorThrows() async {
        let baseURL = URL(string: "https://example.com")!
        let auth = makeAuth(token: "token")
        let stub = HTTPStub { _ in
            throw URLError(.notConnectedToInternet)
        }
        let gateway = VoxGateway(baseURL: baseURL, auth: auth, http: stub)

        await XCTAssertThrowsErrorAsync {
            _ = try await gateway.transcribe(Data("audio".utf8))
        } as: { error in
            XCTAssertTrue(error is URLError)
        }
    }

    // Rewrite
    func testRewriteReturnsProcessedText() async throws {
        let baseURL = URL(string: "https://example.com")!
        let auth = makeAuth(token: "token")
        let stub = HTTPStub { request in
            let response = http(status: 200, url: request.url!)
            let data = json(["finalText": "Processed"])
            return (data, response)
        }
        let gateway = VoxGateway(baseURL: baseURL, auth: auth, http: stub)

        let text = try await gateway.rewrite("raw", level: .light)

        XCTAssertEqual(text, "Processed")
    }

    func testRewriteWithLightLevel() async throws {
        let baseURL = URL(string: "https://example.com")!
        let auth = makeAuth(token: "token")
        let capture = RewriteCapture()
        let stub = HTTPStub(
            inspector: { request in
                do {
                    let level = try decodeRewriteLevel(from: request)
                    await capture.setLevel(level)
                } catch {
                    await capture.setError(error)
                }
            },
            responder: { request in
                let response = http(status: 200, url: request.url!)
                return (json(["finalText": "ok"]), response)
            }
        )
        let gateway = VoxGateway(baseURL: baseURL, auth: auth, http: stub)

        _ = try await gateway.rewrite("raw", level: .light)

        let (level, error) = await capture.snapshot()
        if let error {
            return XCTFail("Failed to decode rewrite level: \(error)")
        }
        XCTAssertEqual(level, .light)
    }

    func testRewriteWithAggressiveLevel() async throws {
        let baseURL = URL(string: "https://example.com")!
        let auth = makeAuth(token: "token")
        let capture = RewriteCapture()
        let stub = HTTPStub(
            inspector: { request in
                do {
                    let level = try decodeRewriteLevel(from: request)
                    await capture.setLevel(level)
                } catch {
                    await capture.setError(error)
                }
            },
            responder: { request in
                let response = http(status: 200, url: request.url!)
                return (json(["finalText": "ok"]), response)
            }
        )
        let gateway = VoxGateway(baseURL: baseURL, auth: auth, http: stub)

        _ = try await gateway.rewrite("raw", level: .aggressive)

        let (level, error) = await capture.snapshot()
        if let error {
            return XCTFail("Failed to decode rewrite level: \(error)")
        }
        XCTAssertEqual(level, .aggressive)
    }

    // Auth integration
    func testRequestsIncludeAuthHeader() async throws {
        let baseURL = URL(string: "https://example.com")!
        let auth = makeAuth(token: "token-123")
        let stub = HTTPStub { request in
            let response = http(status: 200, url: request.url!)
            return (json(entitlementsJSON), response)
        }
        let gateway = VoxGateway(baseURL: baseURL, auth: auth, http: stub)

        _ = try await gateway.getEntitlements()

        let request = await stub.getLastRequest()
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
    }

    func testNoTokenThrowsError() async {
        let baseURL = URL(string: "https://example.com")!
        let storage = GatewayAuthStorage(token: nil)
        let auth = VoxAuth(storage: storage, gateway: nil, clock: MockClock(now: Date()))
        let stub = HTTPStub { request in
            let response = http(status: 200, url: request.url!)
            return (json(entitlementsJSON), response)
        }
        let gateway = VoxGateway(baseURL: baseURL, auth: auth, http: stub)

        await XCTAssertThrowsErrorAsync {
            _ = try await gateway.getEntitlements()
        } as: { error in
            guard case VoxGatewayError.missingToken = error else {
                return XCTFail("Expected missingToken, got \(error)")
            }
        }
    }

    // Error handling
    func testServerErrorThrows() async {
        let baseURL = URL(string: "https://example.com")!
        let auth = makeAuth(token: "token")
        let stub = HTTPStub { request in
            let response = http(status: 500, url: request.url!)
            return (Data("boom".utf8), response)
        }
        let gateway = VoxGateway(baseURL: baseURL, auth: auth, http: stub)

        await XCTAssertThrowsErrorAsync {
            _ = try await gateway.getEntitlements()
        } as: { error in
            guard case VoxGatewayError.httpError(let status, _) = error else {
                return XCTFail("Expected httpError, got \(error)")
            }
            XCTAssertEqual(status, 500)
        }
    }

    func testMalformedResponseThrows() async {
        let baseURL = URL(string: "https://example.com")!
        let auth = makeAuth(token: "token")
        let stub = HTTPStub { request in
            let response = http(status: 200, url: request.url!)
            return (Data("not-json".utf8), response)
        }
        let gateway = VoxGateway(baseURL: baseURL, auth: auth, http: stub)

        await XCTAssertThrowsErrorAsync {
            _ = try await gateway.getEntitlements()
        } as: { error in
            guard case VoxGatewayError.malformedResponse = error else {
                return XCTFail("Expected malformedResponse, got \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func makeAuth(token: String) -> VoxAuth {
        let storage = GatewayAuthStorage(token: token)
        return VoxAuth(storage: storage, gateway: nil, clock: MockClock(now: Date()))
    }

    private func waitForSignOut(storage: GatewayAuthStorage) async {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if await storage.clearTokenCount > 0 {
                return
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("Timed out waiting for signOut clearToken")
    }
}

private let entitlementsJSON: [String: Any] = [
    "subject": "user",
    "plan": "pro",
    "status": "active",
    "features": ["dictation"],
    "currentPeriodEnd": Int(Date().addingTimeInterval(3600).timeIntervalSince1970)
]

private func decodeRewriteLevel(from request: URLRequest) throws -> ProcessingLevel {
    guard let body = request.httpBody else {
        throw VoxGatewayError.malformedResponse
    }
    let decoded = try JSONDecoder().decode(RewriteRequest.self, from: body)
    return decoded.processingLevel
}

private func http(status: Int, url: URL) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
}

private func json(_ object: [String: Any]) -> Data {
    (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
}

private extension XCTestCase {
    func XCTAssertThrowsErrorAsync(
        _ expression: @escaping () async throws -> Void,
        as assertion: (Error) -> Void
    ) async {
        do {
            try await expression()
            XCTFail("Expected error")
        } catch {
            assertion(error)
        }
    }
}
