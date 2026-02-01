import XCTest
@testable import VoxCore

final class RewriteQualityGateTests: XCTestCase {
    func test_evaluate_emptyRaw_returnsAcceptable() {
        let decision = RewriteQualityGate.evaluate(raw: "   ", candidate: "candidate", level: .light)

        XCTAssertTrue(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 1, accuracy: 0.0001)
        XCTAssertEqual(decision.minimumRatio, 0.6, accuracy: 0.0001)
    }

    func test_evaluate_emptyCandidate_returnsNotAcceptable() {
        let decision = RewriteQualityGate.evaluate(raw: "raw", candidate: "  \n", level: .aggressive)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 0, accuracy: 0.0001)
        XCTAssertEqual(decision.minimumRatio, 0.3, accuracy: 0.0001)
    }

    func test_evaluate_ratioCalculation_isCorrect() {
        let decision = RewriteQualityGate.evaluate(raw: "abcd", candidate: "ab", level: .off)

        XCTAssertEqual(decision.ratio, 0.5, accuracy: 0.0001)
        XCTAssertEqual(decision.minimumRatio, 0, accuracy: 0.0001)
    }

    func test_evaluate_minimumRatio_perProcessingLevel() {
        let cases: [(ProcessingLevel, Double)] = [
            (.off, 0),
            (.light, 0.6),
            (.aggressive, 0.3),
        ]

        for (level, expected) in cases {
            let decision = RewriteQualityGate.evaluate(raw: "raw", candidate: "candidate", level: level)
            XCTAssertEqual(decision.minimumRatio, expected, accuracy: 0.0001)
        }
    }

    func test_evaluate_boundaryAtThreshold_isAcceptable() {
        let raw = String(repeating: "r", count: 10)

        let lightCandidate = String(repeating: "c", count: 6)
        let lightDecision = RewriteQualityGate.evaluate(raw: raw, candidate: lightCandidate, level: .light)
        XCTAssertTrue(lightDecision.isAcceptable)
        XCTAssertEqual(lightDecision.ratio, 0.6, accuracy: 0.0001)

        let aggressiveCandidate = String(repeating: "c", count: 3)
        let aggressiveDecision = RewriteQualityGate.evaluate(raw: raw, candidate: aggressiveCandidate, level: .aggressive)
        XCTAssertTrue(aggressiveDecision.isAcceptable)
        XCTAssertEqual(aggressiveDecision.ratio, 0.3, accuracy: 0.0001)
    }

    func test_decision_equatable_matchesEqualValues() {
        let decision = RewriteQualityGate.Decision(isAcceptable: true, ratio: 0.5, minimumRatio: 0.3)
        let sameDecision = RewriteQualityGate.Decision(isAcceptable: true, ratio: 0.5, minimumRatio: 0.3)
        let differentDecision = RewriteQualityGate.Decision(isAcceptable: false, ratio: 0.5, minimumRatio: 0.3)

        XCTAssertEqual(decision, sameDecision)
        XCTAssertNotEqual(decision, differentDecision)
    }
}
