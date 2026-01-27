import Foundation
import XCTest
@testable import VoxApp

private struct MockClock: VoxAuthClock {
    var now: Date
}

private actor MockStorage: VoxAuthStorage {
    var token: String?
    var tokenExpiry: Date?
    var cache: EntitlementCache?

    func loadToken() async -> (token: String, expiry: Date?)? {
        guard let token else { return nil }
        return (token, tokenExpiry)
    }

    func saveToken(_ token: String, expiry: Date?) async throws {
        self.token = token
        self.tokenExpiry = expiry
    }

    func clearToken() async {
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
        cache = nil
    }
}

private actor MockGateway: VoxAuthGateway {
    var result: Result<EntitlementResponse, Error>
    var callCount = 0
    var delayNanos: UInt64 = 0

    init(result: Result<EntitlementResponse, Error>) {
        self.result = result
    }

    func setResult(_ result: Result<EntitlementResponse, Error>) {
        self.result = result
    }

    func setDelay(milliseconds: UInt64) {
        delayNanos = milliseconds * 1_000_000
    }

    func getEntitlements(token _: String) async throws -> EntitlementResponse {
        callCount += 1
        if delayNanos > 0 {
            try? await Task.sleep(nanoseconds: delayNanos)
        }
        return try result.get()
    }

    func getCallCount() async -> Int { callCount }
}

@MainActor
final class VoxAuthTests: XCTestCase {
    func testInitialStateIsUnknown() {
        let auth = VoxAuth(
            storage: MockStorage(),
            gateway: nil,
            clock: MockClock(now: Date())
        )
        XCTAssertEqual(auth.state, .unknown)
        XCTAssertFalse(auth.isAllowed)
    }

    func testCheckTransitionsToAllowedWhenEntitled() async {
        let storage = MockStorage()
        let gateway = MockGateway(result: .success(.active))
        let auth = VoxAuth(storage: storage, gateway: gateway, clock: MockClock(now: Date()))

        try? await storage.saveToken("token", expiry: nil)

        await auth.check()

        XCTAssertEqual(auth.state, .allowed)
        XCTAssertTrue(auth.isAllowed)
    }

    func testCheckTransitionsToNeedsAuthWhenNoToken() async {
        let auth = VoxAuth(
            storage: MockStorage(),
            gateway: MockGateway(result: .success(.active)),
            clock: MockClock(now: Date())
        )

        await auth.check()

        XCTAssertEqual(auth.state, .needsAuth)
        XCTAssertFalse(auth.isAllowed)
    }

    func testCheckTransitionsToNeedsSubscriptionWhenExpired() async {
        let storage = MockStorage()
        let gateway = MockGateway(result: .success(.expired))
        let auth = VoxAuth(storage: storage, gateway: gateway, clock: MockClock(now: Date()))

        try? await storage.saveToken("token", expiry: nil)

        await auth.check()

        XCTAssertEqual(auth.state, .needsSubscription)
        XCTAssertFalse(auth.isAllowed)
    }

    func testDeepLinkSavesTokenAndUpdatesState() async {
        let storage = MockStorage()
        let gateway = MockGateway(result: .success(.active))
        let auth = VoxAuth(storage: storage, gateway: gateway, clock: MockClock(now: Date()))

        let url = URL(string: "vox://auth?token=abc123")!
        auth.handleDeepLink(url)

        await waitForState(auth, equals: .allowed)

        let stored = await storage.loadToken()
        XCTAssertEqual(stored?.token, "abc123")
    }

    func testDeepLinkWithInvalidURLIsIgnored() async {
        let storage = MockStorage()
        let gateway = MockGateway(result: .success(.active))
        let auth = VoxAuth(storage: storage, gateway: gateway, clock: MockClock(now: Date()))

        auth.handleDeepLink(URL(string: "vox://wrong?token=abc")!)

        // Give any spawned tasks a moment.
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(auth.state, .unknown)
        let stored = await storage.loadToken()
        let callCount = await gateway.getCallCount()
        XCTAssertNil(stored)
        XCTAssertEqual(callCount, 0)
    }

    func testSignOutClearsTokenAndUpdatesState() async {
        let storage = MockStorage()
        let gateway = MockGateway(result: .success(.active))
        let auth = VoxAuth(storage: storage, gateway: gateway, clock: MockClock(now: Date()))

        try? await storage.saveToken("token", expiry: nil)
        try? await storage.saveEntitlement(.activeCache(lastVerified: Date()))

        auth.signOut()
        try? await Task.sleep(nanoseconds: 50_000_000)

        let stored = await storage.loadToken()
        let cache = await storage.loadEntitlement()

        XCTAssertNil(stored)
        XCTAssertNil(cache)
        XCTAssertEqual(auth.state, .needsAuth)
    }

    func testFreshCacheReturnsWithoutNetwork() async {
        let storage = MockStorage()
        let gateway = MockGateway(result: .success(.active))
        let auth = VoxAuth(storage: storage, gateway: gateway, clock: MockClock(now: Date()))

        try? await storage.saveToken("token", expiry: nil)
        try? await storage.saveEntitlement(.activeCache(lastVerified: Date().addingTimeInterval(-3600)))

        await auth.check()

        XCTAssertEqual(auth.state, .allowed)
        let callCount = await gateway.getCallCount()
        XCTAssertEqual(callCount, 0)
    }

    func testStaleCacheTriggersBackgroundRefresh() async {
        let storage = MockStorage()
        let gateway = MockGateway(result: .success(.active))
        let auth = VoxAuth(storage: storage, gateway: gateway, clock: MockClock(now: Date()))

        try? await storage.saveToken("token", expiry: nil)
        try? await storage.saveEntitlement(.activeCache(lastVerified: Date().addingTimeInterval(-(5 * 3600))))

        await auth.check()
        XCTAssertEqual(auth.state, .allowed)

        await waitForGatewayCalls(gateway, atLeast: 1)
    }

    func test401ClearsTokenAndSetsNeedsAuth() async {
        let storage = MockStorage()
        let gateway = MockGateway(result: .failure(GatewayError.httpError(401, "nope")))
        let auth = VoxAuth(storage: storage, gateway: gateway, clock: MockClock(now: Date()))

        try? await storage.saveToken("token", expiry: nil)

        await auth.check()

        XCTAssertEqual(auth.state, .needsAuth)
        let token = await storage.loadToken()
        let cache = await storage.loadEntitlement()
        XCTAssertNil(token)
        XCTAssertNil(cache)
    }

    func test403ClearsTokenAndSetsNeedsAuth() async {
        let storage = MockStorage()
        let gateway = MockGateway(result: .failure(GatewayError.httpError(403, "nope")))
        let auth = VoxAuth(storage: storage, gateway: gateway, clock: MockClock(now: Date()))

        try? await storage.saveToken("token", expiry: nil)

        await auth.check()

        XCTAssertEqual(auth.state, .needsAuth)
        let token = await storage.loadToken()
        XCTAssertNil(token)
    }

    func testNetworkErrorWithValidCacheReturnsAllowed() async {
        let storage = MockStorage()
        let gateway = MockGateway(result: .failure(URLError(.notConnectedToInternet)))
        let auth = VoxAuth(storage: storage, gateway: gateway, clock: MockClock(now: Date()))

        try? await storage.saveToken("token", expiry: nil)
        try? await storage.saveEntitlement(.activeCache(lastVerified: Date().addingTimeInterval(-(5 * 3600))))

        await auth.check()
        XCTAssertEqual(auth.state, .allowed)

        // Ensure background refresh ran but did not clobber allowed state.
        await waitForGatewayCalls(gateway, atLeast: 1)
        XCTAssertEqual(auth.state, .allowed)
    }

    func testConcurrentChecksCoalesce() async {
        let storage = MockStorage()
        let gateway = MockGateway(result: .success(.active))
        await gateway.setDelay(milliseconds: 150)
        let auth = VoxAuth(storage: storage, gateway: gateway, clock: MockClock(now: Date()))

        try? await storage.saveToken("token", expiry: nil)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask { await auth.check() }
            }
        }

        XCTAssertEqual(auth.state, .allowed)
        let callCount = await gateway.getCallCount()
        XCTAssertEqual(callCount, 1)
    }

    // MARK: - Helpers

    private func waitForState(
        _ auth: VoxAuth,
        equals expected: VoxAuth.State,
        timeout: TimeInterval = 2
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if auth.state == expected { return }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("Timed out waiting for state \(expected), got \(auth.state)")
    }

    private func waitForGatewayCalls(
        _ gateway: MockGateway,
        atLeast expected: Int,
        timeout: TimeInterval = 2
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await gateway.getCallCount() >= expected { return }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("Timed out waiting for gateway calls >= \(expected)")
    }
}

private extension EntitlementResponse {
    static var active: EntitlementResponse {
        EntitlementResponse(
            subject: "user",
            plan: "pro",
            status: "active",
            features: ["dictation"],
            currentPeriodEnd: Int(Date().addingTimeInterval(3600).timeIntervalSince1970)
        )
    }

    static var expired: EntitlementResponse {
        EntitlementResponse(
            subject: "user",
            plan: "pro",
            status: "expired",
            features: [],
            currentPeriodEnd: Int(Date().addingTimeInterval(-3600).timeIntervalSince1970)
        )
    }
}

private extension EntitlementCache {
    static func activeCache(lastVerified: Date) -> EntitlementCache {
        EntitlementCache(
            plan: "pro",
            status: "active",
            features: ["dictation"],
            currentPeriodEnd: Date().addingTimeInterval(3600),
            lastVerified: lastVerified
        )
    }
}
