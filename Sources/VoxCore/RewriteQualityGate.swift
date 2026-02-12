import Foundation

public enum RewriteQualityGate {
    public struct Decision: Equatable, Sendable {
        public let isAcceptable: Bool
        public let ratio: Double
        public let minimumRatio: Double
        public let maximumRatio: Double?
        public let levenshteinSimilarity: Double?
        public let contentOverlap: Double?
        public let levenshteinThreshold: Double?
        public let contentOverlapThreshold: Double?

        public init(
            isAcceptable: Bool,
            ratio: Double,
            minimumRatio: Double,
            maximumRatio: Double?,
            levenshteinSimilarity: Double? = nil,
            contentOverlap: Double? = nil,
            levenshteinThreshold: Double? = nil,
            contentOverlapThreshold: Double? = nil
        ) {
            self.isAcceptable = isAcceptable
            self.ratio = ratio
            self.minimumRatio = minimumRatio
            self.maximumRatio = maximumRatio
            self.levenshteinSimilarity = levenshteinSimilarity
            self.contentOverlap = contentOverlap
            self.levenshteinThreshold = levenshteinThreshold
            self.contentOverlapThreshold = contentOverlapThreshold
        }
    }

    public static func evaluate(raw: String, candidate: String, level: ProcessingLevel) -> Decision {
        let trimmedRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        let minRatio = minimumRatio(for: level)
        let maxRatio = maximumRatio(for: level)

        guard !trimmedCandidate.isEmpty else {
            return Decision(isAcceptable: false, ratio: 0, minimumRatio: minRatio, maximumRatio: maxRatio)
        }

        guard !trimmedRaw.isEmpty else {
            let ratio = 1.0
            let isAcceptable = ratio >= minRatio && (maxRatio == nil || ratio <= maxRatio!)
            return Decision(isAcceptable: isAcceptable, ratio: ratio, minimumRatio: minRatio, maximumRatio: maxRatio)
        }

        let ratio = Double(trimmedCandidate.count) / Double(max(trimmedRaw.count, 1))
        var ratioAcceptable = ratio >= minRatio && (maxRatio == nil || ratio <= maxRatio!)

        // Distance checks for light/aggressive only — enhance intentionally transforms
        let skipDistanceChecks = (level == .enhance || level == .off)
        var levSim: Double?
        var overlap: Double?
        var levThresh: Double?
        var ovlThresh: Double?

        if !skipDistanceChecks {
            let lev = normalizedLevenshteinSimilarity(raw: trimmedRaw, candidate: trimmedCandidate)
            let ovl = contentOverlapScore(raw: trimmedRaw, candidate: trimmedCandidate)
            levSim = lev
            overlap = ovl

            let lt = levenshteinThreshold(for: level)
            let ot = contentOverlapThreshold(for: level)
            levThresh = lt
            ovlThresh = ot

            if lev < lt || ovl < ot {
                ratioAcceptable = false
            }
        }

        return Decision(
            isAcceptable: ratioAcceptable,
            ratio: ratio,
            minimumRatio: minRatio,
            maximumRatio: maxRatio,
            levenshteinSimilarity: levSim,
            contentOverlap: overlap,
            levenshteinThreshold: levThresh,
            contentOverlapThreshold: ovlThresh
        )
    }

    // MARK: - Levenshtein Distance

    /// Normalized Levenshtein similarity: 1.0 = identical, 0.0 = completely different.
    public static func normalizedLevenshteinSimilarity(raw: String, candidate: String) -> Double {
        let rawChars = Array(raw.lowercased())
        let candChars = Array(candidate.lowercased())
        let maxLen = max(rawChars.count, candChars.count)
        guard maxLen > 0 else { return 1.0 }

        let distance = levenshteinDistance(rawChars, candChars)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    private static func levenshteinDistance(_ a: [Character], _ b: [Character]) -> Int {
        // DP array sized to shorter string for O(min(|a|,|b|)) memory
        let (longer, shorter) = a.count >= b.count ? (a, b) : (b, a)
        let m = longer.count
        let n = shorter.count
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = longer[i - 1] == shorter[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,       // deletion
                    curr[j - 1] + 1,    // insertion
                    prev[j - 1] + cost  // substitution
                )
            }
            swap(&prev, &curr)
        }
        return prev[n]
    }

    // MARK: - Content Word Overlap

    /// Fraction of raw's content words found in candidate. 1.0 = all preserved.
    public static func contentOverlapScore(raw: String, candidate: String) -> Double {
        let rawWords = contentWords(raw)
        guard !rawWords.isEmpty else { return 1.0 }

        let candidateWords = Set(contentWords(candidate))
        let matches = rawWords.filter { candidateWords.contains($0) }.count
        return Double(matches) / Double(rawWords.count)
    }

    // "not"/"no" intentionally excluded — negation tokens must survive overlap
    // scoring to catch semantic inversions (e.g. "not approving" → "approving").
    private static let stopWords: Set<String> = [
        "a", "an", "the", "is", "it", "in", "on", "at", "to", "of",
        "and", "or", "but", "so", "if", "do", "my", "me", "we", "he",
        "she", "be", "am", "are", "was", "were", "has", "had", "have",
        "i", "you", "for", "with", "as", "by", "this",
        "that", "from", "up", "out", "just", "then", "than", "very",
        "um", "uh", "like", "know", "mean", "basically", "actually",
        "literally", "well", "right", "yeah", "ok", "okay",
    ]

    private static func contentWords(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 && !stopWords.contains($0) }
    }

    // MARK: - Thresholds

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
        case .light: return 3.0
        case .enhance: return 15.0
        case .off, .aggressive: return nil
        }
    }

    private static func levenshteinThreshold(for level: ProcessingLevel) -> Double {
        switch level {
        case .light: return 0.3
        case .aggressive: return 0.2
        case .off, .enhance: return 0
        }
    }

    private static func contentOverlapThreshold(for level: ProcessingLevel) -> Double {
        switch level {
        case .light: return 0.4
        case .aggressive: return 0.3
        case .off, .enhance: return 0
        }
    }
}
