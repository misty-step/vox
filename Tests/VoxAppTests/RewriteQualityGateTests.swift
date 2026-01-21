import XCTest
@testable import VoxApp

final class RewriteQualityGateTests: XCTestCase {
    func testAcceptsLightWhenRatioIsHighEnough() {
        let raw = String(repeating: "a", count: 100)
        let candidate = String(repeating: "b", count: 70)

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .light)

        XCTAssertTrue(decision.isAcceptable)
    }

    func testRejectsLightWhenRatioTooLow() {
        let raw = String(repeating: "a", count: 100)
        let candidate = String(repeating: "b", count: 40)

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .light)

        XCTAssertFalse(decision.isAcceptable)
    }

    func testAcceptsAggressiveAtLowerRatio() {
        let raw = String(repeating: "a", count: 100)
        let candidate = String(repeating: "b", count: 30)

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .aggressive)

        XCTAssertTrue(decision.isAcceptable)
    }
}
