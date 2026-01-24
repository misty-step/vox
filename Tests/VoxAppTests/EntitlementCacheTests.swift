import XCTest
@testable import VoxApp

final class EntitlementCacheTests: XCTestCase {

    func testIsStaleAfterFourHours() {
        let cache = EntitlementCache(
            plan: "trial",
            status: "active",
            features: ["stt", "rewrite"],
            currentPeriodEnd: nil,
            lastVerified: Date().addingTimeInterval(-4 * 3600 - 1) // 4 hours + 1 second ago
        )
        XCTAssertTrue(cache.isStale, "Cache should be stale after 4 hours")
    }

    func testIsNotStaleWithinFourHours() {
        let cache = EntitlementCache(
            plan: "trial",
            status: "active",
            features: ["stt", "rewrite"],
            currentPeriodEnd: nil,
            lastVerified: Date().addingTimeInterval(-3 * 3600) // 3 hours ago
        )
        XCTAssertFalse(cache.isStale, "Cache should not be stale within 4 hours")
    }

    func testIsValidWithinTwentyFourHours() {
        let cache = EntitlementCache(
            plan: "pro",
            status: "active",
            features: ["stt", "rewrite", "unlimited"],
            currentPeriodEnd: nil,
            lastVerified: Date().addingTimeInterval(-20 * 3600) // 20 hours ago
        )
        XCTAssertTrue(cache.isValid, "Cache should be valid within 24 hours")
    }

    func testIsInvalidAfterTwentyFourHours() {
        let cache = EntitlementCache(
            plan: "pro",
            status: "active",
            features: ["stt", "rewrite", "unlimited"],
            currentPeriodEnd: nil,
            lastVerified: Date().addingTimeInterval(-24 * 3600 - 1) // 24 hours + 1 second ago
        )
        XCTAssertFalse(cache.isValid, "Cache should be invalid after 24 hours")
    }

    func testIsActiveWhenStatusActive() {
        let cache = EntitlementCache(
            plan: "trial",
            status: "active",
            features: ["stt", "rewrite"],
            currentPeriodEnd: nil,
            lastVerified: Date()
        )
        XCTAssertTrue(cache.isActive, "Cache should be active when status is 'active'")
    }

    func testIsNotActiveWhenStatusExpired() {
        let cache = EntitlementCache(
            plan: "trial",
            status: "expired",
            features: [],
            currentPeriodEnd: nil,
            lastVerified: Date()
        )
        XCTAssertFalse(cache.isActive, "Cache should not be active when status is 'expired'")
    }

    func testInitFromEntitlementResponse() {
        let response = EntitlementResponse(
            subject: "user_123",
            plan: "pro",
            status: "active",
            features: ["stt", "rewrite", "unlimited"],
            currentPeriodEnd: 1735689600 // 2025-01-01 00:00:00 UTC
        )

        let cache = EntitlementCache(from: response)

        XCTAssertEqual(cache.plan, "pro")
        XCTAssertEqual(cache.status, "active")
        XCTAssertEqual(cache.features, ["stt", "rewrite", "unlimited"])
        XCTAssertNotNil(cache.currentPeriodEnd)
        XCTAssertTrue(cache.lastVerified.timeIntervalSinceNow < 1, "lastVerified should be now")
    }
}
