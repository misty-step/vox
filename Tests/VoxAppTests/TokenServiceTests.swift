import XCTest
@testable import VoxApp

// Mock storage for testing
actor MockTokenStorage: TokenStorage {
    private var storedToken: String?
    private var storedExpiry: Date?

    func save(token: String, expiresAt: Date?) async throws {
        storedToken = token
        storedExpiry = expiresAt
    }

    func load() async -> (token: String, expiresAt: Date?)? {
        guard let token = storedToken else { return nil }
        return (token, storedExpiry)
    }

    func clear() async {
        storedToken = nil
        storedExpiry = nil
    }
}

// Mock refresher for testing
actor MockTokenRefresher: TokenRefresher {
    var refreshResult: Result<(token: String, expiresAt: Date?), Error> = .failure(TokenError.refreshFailed)
    var refreshCallCount = 0

    func refresh() async throws -> (token: String, expiresAt: Date?) {
        refreshCallCount += 1
        return try refreshResult.get()
    }

    func setResult(_ result: Result<(token: String, expiresAt: Date?), Error>) {
        refreshResult = result
    }

    func getCallCount() -> Int {
        refreshCallCount
    }
}

final class TokenServiceTests: XCTestCase {

    // Test: Returns cached token when valid
    func testReturnsCachedTokenWhenValid() async throws {
        let storage = MockTokenStorage()
        let refresher = MockTokenRefresher()
        let service = TokenServiceImpl(storage: storage, refresher: refresher)

        // Pre-populate storage with valid token (expires in 1 hour)
        let futureExpiry = Date().addingTimeInterval(3600)
        try await storage.save(token: "cached_token", expiresAt: futureExpiry)

        let token = try await service.validToken()

        XCTAssertEqual(token, "cached_token")
        let callCount = await refresher.getCallCount()
        XCTAssertEqual(callCount, 0, "Should not refresh when token is valid")
    }

    // Test: Refreshes on expiry
    func testRefreshesWhenTokenExpired() async throws {
        let storage = MockTokenStorage()
        let refresher = MockTokenRefresher()
        let service = TokenServiceImpl(storage: storage, refresher: refresher)

        // Pre-populate storage with expired token
        let pastExpiry = Date().addingTimeInterval(-3600)
        try await storage.save(token: "expired_token", expiresAt: pastExpiry)

        // Set up refresher to return new token
        let newExpiry = Date().addingTimeInterval(3600)
        await refresher.setResult(.success(("new_token", newExpiry)))

        let token = try await service.validToken()

        XCTAssertEqual(token, "new_token")
        let callCount = await refresher.getCallCount()
        XCTAssertEqual(callCount, 1)
    }

    // Test: Concurrent calls cause single refresh
    func testConcurrentCallsCauseSingleRefresh() async throws {
        let storage = MockTokenStorage()
        let refresher = MockTokenRefresher()
        let service = TokenServiceImpl(storage: storage, refresher: refresher)

        // Set up refresher with slight delay to simulate network
        let newExpiry = Date().addingTimeInterval(3600)
        await refresher.setResult(.success(("refreshed_token", newExpiry)))

        // Launch multiple concurrent requests
        async let token1 = service.validToken()
        async let token2 = service.validToken()
        async let token3 = service.validToken()

        let results = try await [token1, token2, token3]

        // All should get same token
        XCTAssertEqual(results, ["refreshed_token", "refreshed_token", "refreshed_token"])

        // But only one refresh should have happened
        let callCount = await refresher.getCallCount()
        XCTAssertEqual(callCount, 1, "Concurrent calls should coalesce into single refresh")
    }

    // Test: Refresh failure clears token
    func testRefreshFailureClearsToken() async throws {
        let storage = MockTokenStorage()
        let refresher = MockTokenRefresher()
        let service = TokenServiceImpl(storage: storage, refresher: refresher)

        // Pre-populate with expired token
        let pastExpiry = Date().addingTimeInterval(-3600)
        try await storage.save(token: "expired_token", expiresAt: pastExpiry)

        // Set refresher to fail
        await refresher.setResult(.failure(TokenError.refreshFailed))

        do {
            _ = try await service.validToken()
            XCTFail("Should have thrown error")
        } catch {
            // Expected
        }

        // Token should be cleared
        let isAuthenticated = await service.isAuthenticated
        XCTAssertFalse(isAuthenticated)
        let stored = await storage.load()
        XCTAssertNil(stored)
    }

    // Test: clearToken removes token and updates state
    func testClearTokenRemovesTokenAndUpdatesState() async throws {
        let storage = MockTokenStorage()
        let refresher = MockTokenRefresher()
        let service = TokenServiceImpl(storage: storage, refresher: refresher)

        // Pre-populate storage
        let futureExpiry = Date().addingTimeInterval(3600)
        try await storage.save(token: "some_token", expiresAt: futureExpiry)

        await service.clearToken()

        let isAuthenticated = await service.isAuthenticated
        XCTAssertFalse(isAuthenticated)
        let stored = await storage.load()
        XCTAssertNil(stored)
    }

    // Test: isAuthenticated reflects token presence
    func testIsAuthenticatedReflectsTokenPresence() async throws {
        let storage = MockTokenStorage()
        let refresher = MockTokenRefresher()
        let service = TokenServiceImpl(storage: storage, refresher: refresher)

        // Initially no token
        let initialAuth = await service.isAuthenticated
        XCTAssertFalse(initialAuth)

        // Add token
        let futureExpiry = Date().addingTimeInterval(3600)
        try await storage.save(token: "token", expiresAt: futureExpiry)

        // Service needs to check storage
        _ = try? await service.validToken()

        let isAuthenticated = await service.isAuthenticated
        XCTAssertTrue(isAuthenticated)
    }
}
