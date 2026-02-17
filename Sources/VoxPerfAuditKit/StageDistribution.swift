import Foundation

package struct StageDistribution: Codable, Sendable {
    package let p50: Double
    package let p95: Double
    package let min: Double
    package let max: Double

    package init(samples: [Double]) {
        guard !samples.isEmpty else {
            self.p50 = 0
            self.p95 = 0
            self.min = 0
            self.max = 0
            return
        }
        let sorted = samples.sorted()
        self.min = sorted[0]
        self.max = sorted[sorted.count - 1]
        self.p50 = Self.percentile(sorted, quantile: 0.50)
        self.p95 = Self.percentile(sorted, quantile: 0.95)
    }

    static func percentile(_ sorted: [Double], quantile: Double) -> Double {
        guard sorted.count > 1 else { return sorted[0] }
        let rank = quantile * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        if lower == upper { return sorted[lower] }

        let lowerValue = sorted[lower]
        let upperValue = sorted[upper]
        let fraction = rank - Double(lower)
        return lowerValue + ((upperValue - lowerValue) * fraction)
    }
}
