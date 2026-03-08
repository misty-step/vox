import Foundation
import VoxCore

package struct OutputContract: Decodable, Sendable {
    package let mustNotStartWith: [String]?
    package let mustPreserveTerms: [String]?
    package let mustNotEndWith: [String]?

    package init(
        mustNotStartWith: [String]?,
        mustPreserveTerms: [String]?,
        mustNotEndWith: [String]?
    ) {
        self.mustNotStartWith = mustNotStartWith
        self.mustPreserveTerms = mustPreserveTerms
        self.mustNotEndWith = mustNotEndWith
    }

    enum CodingKeys: String, CodingKey {
        case mustNotStartWith = "must_not_start_with"
        case mustPreserveTerms = "must_preserve_terms"
        case mustNotEndWith = "must_not_end_with"
    }
}

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
    package let contractPassRate: Double?
    package let nonEmptyRate: Double
    package let latency: Distribution
    package let cost: Distribution?

    package init(
        model: String,
        level: ProcessingLevel,
        samples: Int,
        errorRate: Double,
        qualityPassRate: Double,
        contractPassRate: Double?,
        nonEmptyRate: Double,
        latency: Distribution,
        cost: Distribution?
    ) {
        self.model = model
        self.level = level
        self.samples = samples
        self.errorRate = errorRate
        self.qualityPassRate = qualityPassRate
        self.contractPassRate = contractPassRate
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

package func evaluateContract(output: String, contract: OutputContract?) -> (pass: Bool?, violations: [String]) {
    guard let contract else { return (nil, []) }
    var violations: [String] = []
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedOutput = normalizeContractBoundary(trimmed)

    if let prefixes = contract.mustNotStartWith {
        for prefix in prefixes {
            let normalizedPrefix = normalizeContractBoundary(prefix)
            if !normalizedPrefix.isEmpty, normalizedOutput.hasPrefix(normalizedPrefix) {
                violations.append("starts_with:\(prefix)")
            }
        }
    }

    if let suffixes = contract.mustNotEndWith {
        let lastLine = trimmed
            .components(separatedBy: .newlines)
            .last(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
        let normalizedLastLine = normalizeContractBoundary(lastLine)

        for suffix in suffixes {
            let normalizedSuffix = normalizeContractBoundary(suffix)
            guard !normalizedSuffix.isEmpty else { continue }

            if normalizedOutput.hasSuffix(normalizedSuffix) {
                violations.append("ends_with:\(suffix)")
                continue
            }

            if hasTrailingArtifactClause(normalizedLastLine: normalizedLastLine, normalizedSuffix: normalizedSuffix) {
                violations.append("ends_with:\(suffix)")
            }
        }
    }

    if let terms = contract.mustPreserveTerms {
        let normalizedContent = normalizeContractContent(trimmed)
        for term in terms {
            let normalizedTerm = normalizeContractContent(term)
            if !normalizedTerm.isEmpty, !normalizedContent.contains(normalizedTerm) {
                violations.append("missing_term:\(term)")
            }
        }
    }

    return (violations.isEmpty, violations)
}

package func selectRecommendation(
    from summaries: [ModelLevelSummary],
    qualityTarget: Double
) -> RecommendationSelection {
    // nil = untested. Keep those rows eligible so mixed corpora do not discard them,
    // but rank them below measured contract scores to prefer proven compliance.
    let eligible = summaries.filter {
        $0.qualityPassRate >= qualityTarget && ($0.contractPassRate ?? 1.0) >= 1.0
    }
    let usedFallback = eligible.isEmpty
    let pool = usedFallback ? summaries : eligible

    let winner = pool.min(by: { lhs, rhs in
        let lhsContractScore = lhs.contractPassRate ?? -1.0
        let rhsContractScore = rhs.contractPassRate ?? -1.0

        if usedFallback {
            if lhs.qualityPassRate != rhs.qualityPassRate {
                return lhs.qualityPassRate > rhs.qualityPassRate
            }
            if lhsContractScore != rhsContractScore {
                return lhsContractScore > rhsContractScore
            }
        } else {
            if lhsContractScore != rhsContractScore {
                return lhsContractScore > rhsContractScore
            }
            if lhs.qualityPassRate != rhs.qualityPassRate {
                return lhs.qualityPassRate > rhs.qualityPassRate
            }
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

private func normalizeContractBoundary(_ text: String) -> String {
    text
        .trimmingCharacters(in: CharacterSet.contractWrapperCharacters)
        .lowercased()
}

private func normalizeContractContent(_ text: String) -> String {
    normalizeContractBoundary(text)
        .replacingOccurrences(of: "\r\n", with: "\n")
}

private func hasTrailingArtifactClause(
    normalizedLastLine: String,
    normalizedSuffix: String
) -> Bool {
    guard !normalizedLastLine.isEmpty, !normalizedSuffix.isEmpty else { return false }
    guard let suffixRange = normalizedLastLine.range(of: normalizedSuffix, options: .backwards) else {
        return false
    }

    let beforeSuffix = normalizedLastLine[..<suffixRange.lowerBound]
    let trimmedBefore = beforeSuffix.trimmingCharacters(in: CharacterSet.contractClausePrefixTrimCharacters)
    if
        let boundary = trimmedBefore.unicodeScalars.last,
        !CharacterSet.contractClauseBoundaryCharacters.contains(boundary)
    {
        return false
    }

    let afterSuffix = normalizedLastLine[suffixRange.upperBound...]
        .trimmingCharacters(in: CharacterSet.contractClauseSuffixTrimCharacters)
    guard !afterSuffix.isEmpty else { return true }

    let tailTokens = afterSuffix.split(whereSeparator: \.isWhitespace)
    guard tailTokens.count == 1 else { return false }
    return tailTokens[0].unicodeScalars.allSatisfy(CharacterSet.contractArtifactTokenCharacters.contains)
}

private extension CharacterSet {
    static let contractArtifactTokenCharacters = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "._-/")
    )
    static let contractClauseBoundaryCharacters = CharacterSet(charactersIn: ".,!?;:-")
    static let contractClausePrefixTrimCharacters = CharacterSet.whitespacesAndNewlines.union(
        CharacterSet(charactersIn: "\"'`>*_~()[]{}<>")
    )
    static let contractClauseSuffixTrimCharacters = CharacterSet.whitespacesAndNewlines.union(
        CharacterSet(charactersIn: "\"'`*_~()[]{}<>.,!?;:")
    )
    static let contractWrapperCharacters = CharacterSet.whitespacesAndNewlines.union(
        CharacterSet(charactersIn: "\"'`>*_~()[]{}<>.,!?;:“”‘’")
    )
}
