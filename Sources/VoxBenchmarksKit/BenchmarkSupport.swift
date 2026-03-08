import Foundation
import VoxCore

package struct Distribution: Codable, Sendable {
    package let count: Int
    package let p50: Double
    package let p95: Double
    package let min: Double
    package let max: Double
    package let mean: Double

    package init(values: [Double]) {
        guard !values.isEmpty else {
            self.count = 0
            self.p50 = 0
            self.p95 = 0
            self.min = 0
            self.max = 0
            self.mean = 0
            return
        }

        self.count = values.count
        let sorted = values.sorted()
        self.p50 = Self.percentile(sorted, quantile: 0.5)
        self.p95 = Self.percentile(sorted, quantile: 0.95)
        self.min = sorted.first ?? 0
        self.max = sorted.last ?? 0
        self.mean = values.reduce(0, +) / Double(values.count)
    }

    private static func percentile(_ sorted: [Double], quantile: Double) -> Double {
        guard sorted.count > 1 else { return sorted[0] }
        let rank = quantile * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        if lower == upper { return sorted[lower] }
        let fraction = rank - Double(lower)
        return sorted[lower] + ((sorted[upper] - sorted[lower]) * fraction)
    }
}

package struct ModelLevelSummary: Codable, Sendable {
    package let model: String
    package let level: ProcessingLevel
    package let samples: Int
    package let errorRate: Double
    package let qualityPassRate: Double
    package let nonEmptyRate: Double
    package let latency: Distribution
    package let cost: Distribution?

    package init(
        model: String,
        level: ProcessingLevel,
        samples: Int,
        errorRate: Double,
        qualityPassRate: Double,
        nonEmptyRate: Double,
        latency: Distribution,
        cost: Distribution?
    ) {
        self.model = model
        self.level = level
        self.samples = samples
        self.errorRate = errorRate
        self.qualityPassRate = qualityPassRate
        self.nonEmptyRate = nonEmptyRate
        self.latency = latency
        self.cost = cost
    }
}

package struct RecommendationSelection: Sendable {
    package let winner: ModelLevelSummary?
    package let usedFallback: Bool

    package init(winner: ModelLevelSummary?, usedFallback: Bool) {
        self.winner = winner
        self.usedFallback = usedFallback
    }
}

package func selectRecommendation(
    from summaries: [ModelLevelSummary],
    qualityTarget: Double
) -> RecommendationSelection {
    let eligible = summaries.filter { $0.qualityPassRate >= qualityTarget }
    let usedFallback = eligible.isEmpty
    let pool = usedFallback ? summaries : eligible

    let winner = pool.min(by: { lhs, rhs in
        if usedFallback, lhs.qualityPassRate != rhs.qualityPassRate {
            return lhs.qualityPassRate > rhs.qualityPassRate
        }

        if lhs.latency.p95 != rhs.latency.p95 {
            return lhs.latency.p95 < rhs.latency.p95
        }
        return costMean(lhs) < costMean(rhs)
    })

    return RecommendationSelection(winner: winner, usedFallback: usedFallback)
}

package func selectRecommendationWinner(
    from summaries: [ModelLevelSummary],
    qualityTarget: Double
) -> ModelLevelSummary? {
    selectRecommendation(from: summaries, qualityTarget: qualityTarget).winner
}

package func costMean(_ summary: ModelLevelSummary) -> Double {
    summary.cost?.mean ?? Double.greatestFiniteMagnitude
}
