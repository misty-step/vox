import XCTest
@testable import VoxCore

final class VoxCloudAPITests: XCTestCase {
    var api: VoxCloudAPI!
    var mockSession: MockURLSession!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        api = VoxCloudAPI(baseURL: URL(string: "https://api.misty-step.com")!, session: mockSession)
    }

    override func tearDown() {
        api = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - fetchQuota Tests

    func testFetchQuota_Success() async throws {
        let jsonData = """
        {
            "used": 150,
            "remaining": 850
        }
        """.data(using: .utf8)!

        mockSession.nextData = jsonData
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.misty-step.com/v1/quota")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let quota = try await api.fetchQuota(token: "test-token")

        XCTAssertEqual(quota.used, 150)
        XCTAssertEqual(quota.remaining, 850)
        XCTAssertEqual(quota.total, 1000)

        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
    }

    func testFetchQuota_InvalidToken() async throws {
        mockSession.nextData = Data()
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.misty-step.com/v1/quota")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )

        do {
            _ = try await api.fetchQuota(token: "invalid-token")
            XCTFail("Expected invalidToken error")
        } catch let error as VoxCloudAPIError {
            XCTAssertEqual(error, .invalidToken)
        }
    }

    func testFetchQuota_Forbidden() async throws {
        mockSession.nextData = Data()
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.misty-step.com/v1/quota")!,
            statusCode: 403,
            httpVersion: nil,
            headerFields: nil
        )

        do {
            _ = try await api.fetchQuota(token: "test-token")
            XCTFail("Expected forbidden error")
        } catch let error as VoxCloudAPIError {
            XCTAssertEqual(error, .forbidden)
        }
    }

    func testFetchQuota_NotFound() async throws {
        mockSession.nextData = Data()
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.misty-step.com/v1/quota")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )

        do {
            _ = try await api.fetchQuota(token: "test-token")
            XCTFail("Expected notFound error")
        } catch let error as VoxCloudAPIError {
            XCTAssertEqual(error, .notFound)
        }
    }

    func testFetchQuota_ServerError() async throws {
        mockSession.nextData = Data()
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.misty-step.com/v1/quota")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        do {
            _ = try await api.fetchQuota(token: "test-token")
            XCTFail("Expected serverError")
        } catch let error as VoxCloudAPIError {
            if case .serverError(let statusCode) = error {
                XCTAssertEqual(statusCode, 500)
            } else {
                XCTFail("Expected serverError")
            }
        }
    }

    func testFetchQuota_NetworkError() async throws {
        mockSession.nextError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)

        do {
            _ = try await api.fetchQuota(token: "test-token")
            XCTFail("Expected networkError")
        } catch let error as VoxCloudAPIError {
            XCTAssertEqual(error, .networkError)
        }
    }

    func testFetchQuota_DecodingError() async throws {
        let jsonData = """
        {
            "used": "not-a-number",
            "remaining": 850
        }
        """.data(using: .utf8)!

        mockSession.nextData = jsonData
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.misty-step.com/v1/quota")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        do {
            _ = try await api.fetchQuota(token: "test-token")
            XCTFail("Expected decodingError")
        } catch {
            // Any decoding error is acceptable
            XCTAssertTrue(true)
        }
    }
}

// MARK: - VoxCloudQuota Tests

extension VoxCloudAPITests {
    func testVoxCloudQuota_Codable() throws {
        let json = """
        {
            "used": 100,
            "remaining": 400
        }
        """.data(using: .utf8)!

        let quota = try JSONDecoder().decode(VoxCloudQuota.self, from: json)

        XCTAssertEqual(quota.used, 100)
        XCTAssertEqual(quota.remaining, 400)
        XCTAssertEqual(quota.total, 500)
    }

    func testVoxCloudQuota_TotalCalculation() throws {
        let quota = VoxCloudQuota(used: 250, remaining: 750, total: 0)

        XCTAssertEqual(quota.used, 250)
        XCTAssertEqual(quota.remaining, 750)
        XCTAssertEqual(quota.total, 1000)
    }
}

// MARK: - VoxCloudAPIError Tests

extension VoxCloudAPITests {
    func testVoxCloudAPIError_InvalidToken_Description() {
        let error = VoxCloudAPIError.invalidToken

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testVoxCloudAPIError_Forbidden_Description() {
        let error = VoxCloudAPIError.forbidden

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testVoxCloudAPIError_NotFound_Description() {
        let error = VoxCloudAPIError.notFound

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testVoxCloudAPIError_NetworkError_Description() {
        let error = VoxCloudAPIError.networkError

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testVoxCloudAPIError_ServerError_Description() {
        let error = VoxCloudAPIError.serverError(statusCode: 503)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }
}

// MARK: - Mock URLSession

private class MockURLSession: URLSession {
    var nextData: Data?
    var nextResponse: URLResponse?
    var nextError: Error?
    var lastRequest: URLRequest?

    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let error = nextError {
            throw error
        }
        return (nextData ?? Data(), nextResponse ?? HTTPURLResponse())
    }
}
