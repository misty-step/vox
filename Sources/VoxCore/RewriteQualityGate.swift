import Foundation

public enum RewriteQualityGate {
    public struct Decision: Equatable, Sendable {
        public let isAcceptable: Bool
        public let ratio: Double
        public let minimumRatio: Double
    }

    public static func evaluate(raw: String, candidate: String, level: ProcessingLevel) -> Decision {
        let trimmedRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCandidate.isEmpty else {
            return Decision(isAcceptable: false, ratio: 0, minimumRatio: minimumRatio(for: level))
        }

        guard !trimmedRaw.isEmpty else {
            return Decision(isAcceptable: true, ratio: 1, minimumRatio: minimumRatio(for: level))
        }

        let ratio = Double(trimmedCandidate.count) / Double(max(trimmedRaw.count, 1))
        let minimumRatio = minimumRatio(for: level)
        return Decision(isAcceptable: ratio >= minimumRatio, ratio: ratio, minimumRatio: minimumRatio)
    }

    private static func minimumRatio(for level: ProcessingLevel) -> Double {
        switch level {
        case .off: return 0
        case .light: return 0.6
        case .aggressive: return 0.3
        }
    }
}
