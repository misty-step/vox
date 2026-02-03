import Foundation

public enum RewriteQualityGate {
    public struct Decision: Equatable, Sendable {
        public let isAcceptable: Bool
        public let ratio: Double
        public let minimumRatio: Double
        public let maximumRatio: Double?
    }

    public static func evaluate(raw: String, candidate: String, level: ProcessingLevel) -> Decision {
        let trimmedRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        let minimumRatio = minimumRatio(for: level)
        let maximumRatio = maximumRatio(for: level)

        guard !trimmedCandidate.isEmpty else {
            return Decision(isAcceptable: false, ratio: 0, minimumRatio: minimumRatio, maximumRatio: maximumRatio)
        }

        guard !trimmedRaw.isEmpty else {
            let ratio = 1.0
            let isAcceptable = ratio >= minimumRatio && (maximumRatio == nil || ratio <= maximumRatio!)
            return Decision(isAcceptable: isAcceptable, ratio: ratio, minimumRatio: minimumRatio, maximumRatio: maximumRatio)
        }

        let ratio = Double(trimmedCandidate.count) / Double(max(trimmedRaw.count, 1))
        let isAcceptable = ratio >= minimumRatio && (maximumRatio == nil || ratio <= maximumRatio!)
        return Decision(isAcceptable: isAcceptable, ratio: ratio, minimumRatio: minimumRatio, maximumRatio: maximumRatio)
    }

    private static func minimumRatio(for level: ProcessingLevel) -> Double {
        switch level {
        case .off: return 0
        case .light: return 0.6
        case .aggressive: return 0.3
        case .enhance: return 0.2
        }
    }

    private static func maximumRatio(for level: ProcessingLevel) -> Double? {
        switch level {
        case .enhance: return 15.0
        case .off, .light, .aggressive: return nil
        }
    }
}
