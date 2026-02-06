import XCTest
@testable import VoxCore

final class RewriteQualityGateTests: XCTestCase {
    func test_evaluate_emptyRaw_returnsAcceptable() {
        let decision = RewriteQualityGate.evaluate(raw: "   ", candidate: "candidate", level: .light)

        XCTAssertTrue(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 1, accuracy: 0.0001)
        XCTAssertEqual(decision.minimumRatio, 0.6, accuracy: 0.0001)
        XCTAssertNil(decision.maximumRatio)
    }

    func test_evaluate_emptyCandidate_returnsNotAcceptable() {
        let decision = RewriteQualityGate.evaluate(raw: "raw", candidate: "  \n", level: .aggressive)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 0, accuracy: 0.0001)
        XCTAssertEqual(decision.minimumRatio, 0.3, accuracy: 0.0001)
        XCTAssertNil(decision.maximumRatio)
    }

    func test_evaluate_ratioCalculation_isCorrect() {
        let decision = RewriteQualityGate.evaluate(raw: "abcd", candidate: "ab", level: .off)

        XCTAssertEqual(decision.ratio, 0.5, accuracy: 0.0001)
        XCTAssertEqual(decision.minimumRatio, 0, accuracy: 0.0001)
        XCTAssertNil(decision.maximumRatio)
    }

    func test_evaluate_minimumRatio_perProcessingLevel() {
        let cases: [(ProcessingLevel, Double)] = [
            (.off, 0),
            (.light, 0.6),
            (.aggressive, 0.3),
            (.enhance, 0.2),
        ]

        for (level, expected) in cases {
            let decision = RewriteQualityGate.evaluate(raw: "raw", candidate: "candidate", level: level)
            XCTAssertEqual(decision.minimumRatio, expected, accuracy: 0.0001)
        }
    }

    func test_evaluate_maximumRatio_forEnhance() {
        let decision = RewriteQualityGate.evaluate(raw: "raw", candidate: "candidate", level: .enhance)

        XCTAssertEqual(decision.maximumRatio!, 15.0, accuracy: 0.0001)
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

    func test_evaluate_enhanceExpansionWithinBounds_isAcceptable() {
        let raw = String(repeating: "r", count: 10)
        let candidate = String(repeating: "c", count: 100)

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .enhance)

        XCTAssertTrue(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 10.0, accuracy: 0.0001)
    }

    func test_evaluate_enhanceExpansionAboveMax_isNotAcceptable() {
        let raw = String(repeating: "r", count: 10)
        let candidate = String(repeating: "c", count: 200)

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .enhance)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 20.0, accuracy: 0.0001)
    }

    func test_decision_equatable_matchesEqualValues() {
        let decision = RewriteQualityGate.Decision(
            isAcceptable: true,
            ratio: 0.5,
            minimumRatio: 0.3,
            maximumRatio: nil
        )
        let sameDecision = RewriteQualityGate.Decision(
            isAcceptable: true,
            ratio: 0.5,
            minimumRatio: 0.3,
            maximumRatio: nil
        )
        let differentDecision = RewriteQualityGate.Decision(
            isAcceptable: false,
            ratio: 0.5,
            minimumRatio: 0.3,
            maximumRatio: nil
        )

        XCTAssertEqual(decision, sameDecision)
        XCTAssertNotEqual(decision, differentDecision)
    }

    // MARK: - Edge Cases

    func test_evaluate_bothEmpty_returnsNotAcceptable() {
        let decision = RewriteQualityGate.evaluate(raw: "", candidate: "", level: .light)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 0, accuracy: 0.0001)
    }

    func test_evaluate_singleCharacterRaw_expansionWithinBounds() {
        // "This is expanded" is 16 chars, ratio = 16/1 = 16.0 which exceeds max of 15.0
        let decision = RewriteQualityGate.evaluate(raw: "a", candidate: "This is expanded", level: .enhance)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 16.0, accuracy: 0.0001)
    }

    func test_evaluate_singleCharacterRaw_expansionExceedsBounds() {
        let decision = RewriteQualityGate.evaluate(raw: "a", candidate: String(repeating: "x", count: 20), level: .enhance)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 20.0, accuracy: 0.0001)
    }

    func test_evaluate_exactlyAtMinimumRatio_isAcceptable() {
        let raw = "hello world"  // 11 chars
        let candidate = "hello"   // 5 chars, ratio = 5/11 ≈ 0.45

        let aggressiveDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .aggressive)
        XCTAssertTrue(aggressiveDecision.isAcceptable)
        XCTAssertEqual(aggressiveDecision.ratio, 5.0/11.0, accuracy: 0.0001)

        let lightDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .light)
        XCTAssertFalse(lightDecision.isAcceptable)
    }

    func test_evaluate_justBelowMinimumRatio_isNotAcceptable() {
        let raw = "hello world test"  // 16 chars
        let candidate = "hello"        // 5 chars, ratio = 5/16 = 0.3125

        let aggressiveDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .aggressive)
        XCTAssertTrue(aggressiveDecision.isAcceptable)  // Just above 0.3

        let candidate2 = "hello wor"  // 9 chars, ratio = 9/16 = 0.5625
        let lightDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate2, level: .light)
        XCTAssertFalse(lightDecision.isAcceptable)  // Below 0.6
    }

    func test_evaluate_veryLongRaw_veryShortCandidate() {
        let raw = String(repeating: "a", count: 1000)
        let candidate = "ok"

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .enhance)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 0.002, accuracy: 0.0001)
    }

    func test_evaluate_whitespaceOnlyRaw_treatedAsEmpty() {
        let decision = RewriteQualityGate.evaluate(raw: "   \n\t  ", candidate: "result", level: .light)

        XCTAssertTrue(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 1.0, accuracy: 0.0001)
    }

    func test_evaluate_whitespaceOnlyCandidate_treatedAsEmpty() {
        let decision = RewriteQualityGate.evaluate(raw: "raw text", candidate: "   \n\t  ", level: .light)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 0, accuracy: 0.0001)
    }

    func test_evaluate_unicodeCharacters_countedCorrectly() {
        let raw = "こんにちは"  // 5 Japanese characters
        let candidate = "hello"   // 5 English characters

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .light)

        XCTAssertTrue(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 1.0, accuracy: 0.0001)
    }

    func test_evaluate_emojiCharacters_countedCorrectly() {
        let raw = "hello 👋 world"  // 13 characters (including emoji)
        let candidate = "hello world"  // 11 characters

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .light)

        XCTAssertTrue(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 11.0/13.0, accuracy: 0.0001)
    }

    func test_evaluate_offLevel_alwaysAcceptable() {
        let testCases: [(String, String, Bool)] = [
            ("", "", false),  // Empty candidate is never acceptable
            ("raw", "", false),  // Empty candidate is never acceptable
            ("", "candidate", true),
            ("short", String(repeating: "x", count: 1000), true),
        ]

        for (raw, candidate, expectedAcceptable) in testCases {
            let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .off)
            XCTAssertEqual(decision.isAcceptable, expectedAcceptable, "Failed for raw='\(raw)', candidate='\(candidate)'")
            XCTAssertEqual(decision.minimumRatio, 0, accuracy: 0.0001)
            XCTAssertNil(decision.maximumRatio)
        }
    }

    func test_evaluate_enhanceLevel_noMaximumForOtherLevels() {
        let raw = "test"
        let candidate = String(repeating: "x", count: 1000)

        let lightDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .light)
        XCTAssertNil(lightDecision.maximumRatio)

        let aggressiveDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .aggressive)
        XCTAssertNil(aggressiveDecision.maximumRatio)

        let offDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .off)
        XCTAssertNil(offDecision.maximumRatio)
    }

    func test_evaluate_decisionPropertiesAreConsistent() {
        let raw = "hello world this is a test"
        let candidate = "hello world"

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .light)

        XCTAssertEqual(decision.minimumRatio, 0.6, accuracy: 0.0001)
        XCTAssertNil(decision.maximumRatio)
        XCTAssertEqual(decision.ratio, 11.0/26.0, accuracy: 0.0001)
        // 11/26 ≈ 0.42, which is below 0.6, so not acceptable
        XCTAssertFalse(decision.isAcceptable)
    }
}
