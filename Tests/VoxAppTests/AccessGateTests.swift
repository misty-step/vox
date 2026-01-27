import XCTest
@testable import VoxApp

// Mock token service
actor MockTokenService: TokenService {
    var tokenResult: Result<String, Error> = .failure(TokenError.noToken)
    var isAuthenticatedValue = false
    var clearCalled = false

    var isAuthenticated: Bool {
        get async { isAuthenticatedValue }
    }

    func validToken() async throws -> String {
        try tokenResult.get()
    }

    func clearToken() async {
        clearCalled = true
        isAuthenticatedValue = false
    }

    func setToken(_ token: String) {
        tokenResult = .success(token)
        isAuthenticatedValue = true
    }

    func setNoToken() {
        tokenResult = .failure(TokenError.noToken)
        isAuthenticatedValue = false
    }
}

// Mock entitlement checker
actor MockEntitlementChecker: EntitlementChecker {
    var checkResult: Result<AccessEntitlementStatus, Error> = .success(.entitled)
    var checkCount = 0

    func check(token: String) async throws -> AccessEntitlementStatus {
        checkCount += 1
        return try checkResult.get()
    }

    func setResult(_ result: Result<AccessEntitlementStatus, Error>) {
        checkResult = result
    }

    func getCheckCount() -> Int { checkCount }
}

// Mock cache for testing
actor MockEntitlementCacheStore: EntitlementCacheStore {
    private var status: AccessEntitlementStatus?
    private var expiresAt: Date?

    func setStatus(_ status: AccessEntitlementStatus, expiresAt: Date) {
        self.status = status
        self.expiresAt = expiresAt
    }

    func get() async -> (status: AccessEntitlementStatus, expiresAt: Date)? {
        guard let status, let expiry = expiresAt else { return nil }
        return (status, expiry)
    }

    func save(_ status: AccessEntitlementStatus, ttl: TimeInterval) async {
        self.status = status
        self.expiresAt = Date().addingTimeInterval(ttl)
    }

    func clear() async {
        status = nil
        expiresAt = nil
    }
}

final class AccessGateTests: XCTestCase {

    // Test: authenticated + entitled → allowed
    func testAuthenticatedAndEntitledReturnsAllowed() async throws {
        let tokenService = MockTokenService()
        let checker = MockEntitlementChecker()
        let gate = AccessGateImpl(
            tokenService: tokenService,
            entitlementChecker: checker,
            cache: nil
        )

        await tokenService.setToken("valid_token")
        await checker.setResult(.success(.entitled))

        let decision = await gate.preflight()

        if case .allowed = decision {
            // Success
        } else {
            XCTFail("Expected .allowed, got \(decision)")
        }
    }

    // Test: not authenticated → blocked(auth)
    func testNotAuthenticatedReturnsBlockedAuth() async throws {
        let tokenService = MockTokenService()
        let checker = MockEntitlementChecker()
        let gate = AccessGateImpl(
            tokenService: tokenService,
            entitlementChecker: checker,
            cache: nil
        )

        await tokenService.setNoToken()

        let decision = await gate.preflight()

        if case .blocked(let reason) = decision, case .notAuthenticated = reason {
            // Success
        } else {
            XCTFail("Expected .blocked(.notAuthenticated), got \(decision)")
        }
    }

    // Test: authenticated but not entitled → blocked(notEntitled)
    func testAuthenticatedButNotEntitledReturnsBlockedNotEntitled() async throws {
        let tokenService = MockTokenService()
        let checker = MockEntitlementChecker()
        let gate = AccessGateImpl(
            tokenService: tokenService,
            entitlementChecker: checker,
            cache: nil
        )

        await tokenService.setToken("valid_token")
        await checker.setResult(.success(.expired))

        let decision = await gate.preflight()

        if case .blocked(let reason) = decision, case .notEntitled = reason {
            // Success
        } else {
            XCTFail("Expected .blocked(.notEntitled), got \(decision)")
        }
    }

    // Test: 401/403 during check → token cleared → blocked(auth)
    func testAuthErrorClearsTokenAndReturnsBlockedAuth() async throws {
        let tokenService = MockTokenService()
        let checker = MockEntitlementChecker()
        let gate = AccessGateImpl(
            tokenService: tokenService,
            entitlementChecker: checker,
            cache: nil
        )

        await tokenService.setToken("stale_token")
        await checker.setResult(.failure(GatewayError.httpError(401, "unauthorized")))

        let decision = await gate.preflight()

        // Should have cleared token
        let cleared = await tokenService.clearCalled
        XCTAssertTrue(cleared, "Token should be cleared on 401/403")

        if case .blocked(let reason) = decision, case .notAuthenticated = reason {
            // Success
        } else {
            XCTFail("Expected .blocked(.notAuthenticated) after auth error, got \(decision)")
        }
    }

    // Test: network error with valid cache → grace allowed
    func testNetworkErrorWithValidCacheAllowsGrace() async throws {
        let tokenService = MockTokenService()
        let checker = MockEntitlementChecker()
        let cache = MockEntitlementCacheStore()
        let gate = AccessGateImpl(
            tokenService: tokenService,
            entitlementChecker: checker,
            cache: cache
        )

        await tokenService.setToken("valid_token")
        await cache.setStatus(.entitled, expiresAt: Date().addingTimeInterval(3600))
        await checker.setResult(.failure(URLError(.notConnectedToInternet)))

        let decision = await gate.preflight()

        if case .allowed = decision {
            // Success - grace period from cache
        } else {
            XCTFail("Expected .allowed during grace period, got \(decision)")
        }
    }

    // Test: network error with expired cache → blocked
    func testNetworkErrorWithExpiredCacheBlocks() async throws {
        let tokenService = MockTokenService()
        let checker = MockEntitlementChecker()
        let cache = MockEntitlementCacheStore()
        let gate = AccessGateImpl(
            tokenService: tokenService,
            entitlementChecker: checker,
            cache: cache
        )

        await tokenService.setToken("valid_token")
        // Expired beyond hard TTL grace
        await cache.setStatus(.entitled, expiresAt: Date().addingTimeInterval(-(25 * 3600)))
        await checker.setResult(.failure(URLError(.notConnectedToInternet)))

        let decision = await gate.preflight()

        if case .blocked = decision {
            // Success
        } else {
            XCTFail("Expected .blocked with expired cache, got \(decision)")
        }
    }
}

