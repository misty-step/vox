import Testing
import VoxCore
import VoxBenchmarksKit

@Suite("BenchmarkRecommendations")
struct BenchmarkRecommendationsTests {
    @Test("Winner prefers lowest latency among models that meet the quality target")
    func test_selectRecommendationWinner_prefersLowestLatencyWhenQualityTargetIsMet() {
        let slower = ModelLevelSummary(
            model: "slower",
            level: .clean,
            samples: 10,
            errorRate: 0,
            qualityPassRate: 0.99,
            nonEmptyRate: 1,
            latency: Distribution(values: [0.8, 0.9]),
            cost: nil
        )
        let faster = ModelLevelSummary(
            model: "faster",
            level: .clean,
            samples: 10,
            errorRate: 0,
            qualityPassRate: 0.97,
            nonEmptyRate: 1,
            latency: Distribution(values: [0.5, 0.6]),
            cost: nil
        )

        let winner = selectRecommendationWinner(
            from: [slower, faster],
            qualityTarget: 0.95
        )

        #expect(winner?.model == "faster")
    }

    @Test("Fallback path still uses quality as primary tiebreaker")
    func test_selectRecommendationWinner_fallbackKeepsQualityAsPrimaryTiebreaker() {
        let highQuality = ModelLevelSummary(
            model: "high-quality",
            level: .polish,
            samples: 10,
            errorRate: 0,
            qualityPassRate: 0.94,
            nonEmptyRate: 1,
            latency: Distribution(values: [0.8, 0.9]),
            cost: nil
        )
        let lowerQuality = ModelLevelSummary(
            model: "lower-quality",
            level: .polish,
            samples: 10,
            errorRate: 0,
            qualityPassRate: 0.10,
            nonEmptyRate: 1,
            latency: Distribution(values: [0.4, 0.5]),
            cost: nil
        )

        let winner = selectRecommendationWinner(
            from: [highQuality, lowerQuality],
            qualityTarget: 0.95
        )

        #expect(winner?.model == "high-quality")
    }
}
