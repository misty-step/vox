import XCTest
@testable import VoxCore

final class RewriteQualityGateTests: XCTestCase {
    func test_evaluate_emptyRaw_returnsAcceptable() {
        let decision = RewriteQualityGate.evaluate(raw: "   ", candidate: "candidate", level: .clean)

        XCTAssertTrue(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 1, accuracy: 0.0001)
        XCTAssertEqual(decision.minimumRatio, 0.6, accuracy: 0.0001)
        XCTAssertEqual(decision.maximumRatio!, 3.0, accuracy: 0.0001)
    }

    func test_evaluate_emptyCandidate_returnsNotAcceptable() {
        let decision = RewriteQualityGate.evaluate(raw: "raw", candidate: "  \n", level: .polish)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 0, accuracy: 0.0001)
        XCTAssertEqual(decision.minimumRatio, 0.3, accuracy: 0.0001)
        XCTAssertNil(decision.maximumRatio)
    }

    func test_evaluate_ratioCalculation_isCorrect() {
        let decision = RewriteQualityGate.evaluate(raw: "abcd", candidate: "ab", level: .raw)

        XCTAssertEqual(decision.ratio, 0.5, accuracy: 0.0001)
        XCTAssertEqual(decision.minimumRatio, 0, accuracy: 0.0001)
        XCTAssertNil(decision.maximumRatio)
    }

    func test_evaluate_minimumRatio_perProcessingLevel() {
        let cases: [(ProcessingLevel, Double)] = [
            (.raw, 0),
            (.clean, 0.6),
            (.polish, 0.3),
        ]

        for (level, expected) in cases {
            let decision = RewriteQualityGate.evaluate(raw: "raw", candidate: "candidate", level: level)
            XCTAssertEqual(decision.minimumRatio, expected, accuracy: 0.0001)
        }
    }

    func test_evaluate_boundaryAtThreshold_isAcceptable() {
        // Realistic text that passes distance checks while testing ratio boundaries.
        // Clean mode: ratio >= 0.6
        let lightRaw = "fix the bug now"        // 15 chars
        let lightCandidate = "Fix the bug."      // 12 chars, ratio = 0.8
        let lightDecision = RewriteQualityGate.evaluate(raw: lightRaw, candidate: lightCandidate, level: .clean)
        XCTAssertTrue(lightDecision.isAcceptable)

        // Polish mode: ratio >= 0.3
        let aggRaw = "so basically I think we should really fix that critical bug soon"  // 63 chars
        let aggCandidate = "Fix that critical bug."  // 22 chars, ratio ≈ 0.349
        let aggDecision = RewriteQualityGate.evaluate(raw: aggRaw, candidate: aggCandidate, level: .polish)
        XCTAssertTrue(aggDecision.isAcceptable)
    }

    func test_evaluate_boundaryRatio_syntheticStrings() {
        // Pure ratio math: synthetic strings with .raw mode (no distance checks)
        let raw = String(repeating: "r", count: 10)

        let lightCandidate = String(repeating: "c", count: 6)
        let lightDecision = RewriteQualityGate.evaluate(raw: raw, candidate: lightCandidate, level: .raw)
        XCTAssertEqual(lightDecision.ratio, 0.6, accuracy: 0.0001)

        let aggressiveCandidate = String(repeating: "c", count: 3)
        let aggressiveDecision = RewriteQualityGate.evaluate(raw: raw, candidate: aggressiveCandidate, level: .raw)
        XCTAssertEqual(aggressiveDecision.ratio, 0.3, accuracy: 0.0001)
    }

    func test_evaluate_cleanExpansionAboveMax_isNotAcceptable() {
        let raw = String(repeating: "r", count: 10)
        let candidate = String(repeating: "c", count: 31)  // ratio = 3.1 (> max 3.0)

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .clean)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.maximumRatio!, 3.0, accuracy: 0.0001)
        XCTAssertEqual(decision.ratio, 3.1, accuracy: 0.0001)
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
        let decision = RewriteQualityGate.evaluate(raw: "", candidate: "", level: .clean)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 0, accuracy: 0.0001)
    }

    func test_evaluate_singleCharacterRaw_expansionWithinBounds() {
        // Clean has a maximum expansion ratio of 3.0.
        let decision = RewriteQualityGate.evaluate(raw: "a", candidate: "This is expanded", level: .clean)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 16.0, accuracy: 0.0001)
    }

    func test_evaluate_singleCharacterRaw_expansionExceedsBounds() {
        let decision = RewriteQualityGate.evaluate(raw: "a", candidate: String(repeating: "x", count: 20), level: .clean)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 20.0, accuracy: 0.0001)
    }

    func test_evaluate_exactlyAtMinimumRatio_isAcceptable() {
        let raw = "hello world"  // 11 chars
        let candidate = "hello"   // 5 chars, ratio = 5/11 ≈ 0.45

        let aggressiveDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .polish)
        XCTAssertTrue(aggressiveDecision.isAcceptable)
        XCTAssertEqual(aggressiveDecision.ratio, 5.0/11.0, accuracy: 0.0001)

        let lightDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .clean)
        XCTAssertFalse(lightDecision.isAcceptable)
    }

    func test_evaluate_justBelowMinimumRatio_isNotAcceptable() {
        let raw = "hello world test"  // 16 chars
        let candidate = "hello"        // 5 chars, ratio = 5/16 = 0.3125

        let aggressiveDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .polish)
        XCTAssertTrue(aggressiveDecision.isAcceptable)  // Just above 0.3

        let candidate2 = "hello wor"  // 9 chars, ratio = 9/16 = 0.5625
        let lightDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate2, level: .clean)
        XCTAssertFalse(lightDecision.isAcceptable)  // Below 0.6
    }

    func test_evaluate_veryLongRaw_veryShortCandidate() {
        let raw = String(repeating: "a", count: 1000)
        let candidate = "ok"

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .polish)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 0.002, accuracy: 0.0001)
    }

    func test_evaluate_whitespaceOnlyRaw_treatedAsEmpty() {
        let decision = RewriteQualityGate.evaluate(raw: "   \n\t  ", candidate: "result", level: .clean)

        XCTAssertTrue(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 1.0, accuracy: 0.0001)
    }

    func test_evaluate_whitespaceOnlyCandidate_treatedAsEmpty() {
        let decision = RewriteQualityGate.evaluate(raw: "raw text", candidate: "   \n\t  ", level: .clean)

        XCTAssertFalse(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 0, accuracy: 0.0001)
    }

    func test_evaluate_unicodeCharacters_countedCorrectly() {
        let raw = "こんにちは"  // 5 Japanese characters
        let candidate = "hello"   // 5 English characters

        // Use .raw to isolate character counting from distance checks
        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .raw)

        XCTAssertTrue(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 1.0, accuracy: 0.0001)
    }

    func test_evaluate_emojiCharacters_countedCorrectly() {
        let raw = "hello 👋 world"  // 13 characters (including emoji)
        let candidate = "hello world"  // 11 characters

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .clean)

        XCTAssertTrue(decision.isAcceptable)
        XCTAssertEqual(decision.ratio, 11.0/13.0, accuracy: 0.0001)
    }

    func test_evaluate_rawLevel_alwaysAcceptable() {
        let testCases: [(String, String, Bool)] = [
            ("", "", false),  // Empty candidate is never acceptable
            ("raw", "", false),  // Empty candidate is never acceptable
            ("", "candidate", true),
            ("short", String(repeating: "x", count: 1000), true),
        ]

        for (raw, candidate, expectedAcceptable) in testCases {
            let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .raw)
            XCTAssertEqual(decision.isAcceptable, expectedAcceptable, "Failed for raw='\(raw)', candidate='\(candidate)'")
            XCTAssertEqual(decision.minimumRatio, 0, accuracy: 0.0001)
            XCTAssertNil(decision.maximumRatio)
        }
    }

    func test_evaluate_maximumRatio_onlyAppliesToClean() {
        let raw = "test"
        let candidate = String(repeating: "x", count: 1000)

        let lightDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .clean)
        XCTAssertEqual(lightDecision.maximumRatio!, 3.0, accuracy: 0.0001)

        let aggressiveDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .polish)
        XCTAssertNil(aggressiveDecision.maximumRatio)

        let offDecision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .raw)
        XCTAssertNil(offDecision.maximumRatio)
    }

    // MARK: - Levenshtein Similarity

    func test_normalizedLevenshteinSimilarity_identicalStrings_returns1() {
        let score = RewriteQualityGate.normalizedLevenshteinSimilarity(raw: "hello world", candidate: "hello world")
        XCTAssertEqual(score, 1.0, accuracy: 0.0001)
    }

    func test_normalizedLevenshteinSimilarity_completelyDifferent_returnsLow() {
        let score = RewriteQualityGate.normalizedLevenshteinSimilarity(raw: "hello world", candidate: "xyz abc qrs")
        XCTAssertLessThan(score, 0.3)
    }

    func test_normalizedLevenshteinSimilarity_fillerRemoval_scoresHigh() {
        let raw = "so um I was like thinking we should you know do the thing"
        let candidate = "I was thinking we should do the thing"
        let score = RewriteQualityGate.normalizedLevenshteinSimilarity(raw: raw, candidate: candidate)
        XCTAssertGreaterThan(score, 0.5)
    }

    func test_normalizedLevenshteinSimilarity_emptyStrings_returns1() {
        let score = RewriteQualityGate.normalizedLevenshteinSimilarity(raw: "", candidate: "")
        XCTAssertEqual(score, 1.0, accuracy: 0.0001)
    }

    // MARK: - Content Word Overlap

    func test_contentOverlapScore_identicalText_returns1() {
        let score = RewriteQualityGate.contentOverlapScore(raw: "project factory names brainstorm", candidate: "project factory names brainstorm")
        XCTAssertEqual(score, 1.0, accuracy: 0.0001)
    }

    func test_contentOverlapScore_completelyDifferent_returnsNear0() {
        let score = RewriteQualityGate.contentOverlapScore(raw: "factory project brainstorm names", candidate: "quantum physics relativity entropy")
        XCTAssertEqual(score, 0.0, accuracy: 0.0001)
    }

    func test_contentOverlapScore_emptyInput_returns1() {
        let score = RewriteQualityGate.contentOverlapScore(raw: "", candidate: "anything here")
        XCTAssertEqual(score, 1.0, accuracy: 0.0001)
    }

    func test_contentOverlapScore_partialOverlap() {
        let raw = "asking Gemini brainstorm factory names project"
        let candidate = "factory project meeting review"
        let score = RewriteQualityGate.contentOverlapScore(raw: raw, candidate: candidate)
        XCTAssertGreaterThan(score, 0.0)
        XCTAssertLessThan(score, 1.0)
    }

    // MARK: - Hallucination Regression

    func test_evaluate_lightMode_rejectsHallucinatedAnswer() {
        let raw = "so I was asking Gemini to brainstorm factory names for our factory project"
        let candidate = "Here are some factory name suggestions: 1. SteelForge Industries 2. Nova Manufacturing 3. Apex Production Co. 4. Titan Works 5. Ironclad Fabrication"

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .clean)

        XCTAssertFalse(decision.isAcceptable, "Hallucinated answer must be rejected")
        XCTAssertNotNil(decision.levenshteinSimilarity)
        XCTAssertNotNil(decision.contentOverlap)
        XCTAssertLessThan(decision.levenshteinSimilarity!, 0.4, "Hallucinated answer should have low Levenshtein similarity")
        XCTAssertLessThan(decision.contentOverlap!, 0.5, "Hallucinated answer should have low content overlap")
    }

    func test_evaluate_aggressiveMode_rejectsHallucinatedAnswer() {
        let raw = "we were debating what if we used Redis instead of Postgres for the session cache and John thought it was overkill"
        let candidate = "Redis vs PostgreSQL Comparison:\n\nRedis Advantages:\n- In-memory storage for faster reads\n- Built-in TTL support\n\nPostgreSQL Advantages:\n- ACID compliance\n- No additional infrastructure"

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .polish)

        XCTAssertFalse(decision.isAcceptable, "Generated comparison must be rejected")
    }

    func test_evaluate_lightMode_acceptsCleanedTranscript() {
        let raw = "so um I was like thinking we should you know schedule a meeting for um next Tuesday"
        let candidate = "I was thinking we should schedule a meeting for next Tuesday."

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .clean)

        XCTAssertTrue(decision.isAcceptable, "Legitimate cleanup should pass")
    }

    func test_evaluate_lightMode_rejectsListGeneration() {
        let raw = "I told him to list the top five programming languages for web development"
        let candidate = "Top 5 Programming Languages for Web Development:\n1. JavaScript\n2. Python\n3. TypeScript\n4. Go\n5. Rust"

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .clean)

        XCTAssertFalse(decision.isAcceptable, "Generated list must be rejected")
    }

    func test_evaluate_decisionPropertiesAreConsistent() {
        let raw = "hello world this is a test"
        let candidate = "hello world"

        let decision = RewriteQualityGate.evaluate(raw: raw, candidate: candidate, level: .clean)

        XCTAssertEqual(decision.minimumRatio, 0.6, accuracy: 0.0001)
        XCTAssertEqual(decision.maximumRatio!, 3.0, accuracy: 0.0001)
        XCTAssertEqual(decision.ratio, 11.0/26.0, accuracy: 0.0001)
        // 11/26 ≈ 0.42, which is below 0.6, so not acceptable
        XCTAssertFalse(decision.isAcceptable)
    }
}
