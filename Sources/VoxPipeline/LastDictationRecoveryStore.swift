import Foundation
import VoxCore

public actor LastDictationRecoveryStore {
    public struct Snapshot: Sendable, Equatable {
        public let rawTranscript: String
        public let finalText: String
        public let processingLevel: ProcessingLevel
        public let capturedAt: Date

        public init(rawTranscript: String, finalText: String, processingLevel: ProcessingLevel, capturedAt: Date) {
            self.rawTranscript = rawTranscript
            self.finalText = finalText
            self.processingLevel = processingLevel
            self.capturedAt = capturedAt
        }
    }

    public static let shared = LastDictationRecoveryStore(ttlSeconds: 600)

    private let ttlSeconds: TimeInterval
    private var snapshot: Snapshot?

    public init(ttlSeconds: TimeInterval) {
        self.ttlSeconds = max(0.001, ttlSeconds)
    }

    public func store(rawTranscript: String, finalText: String, processingLevel: ProcessingLevel) {
        snapshot = Snapshot(
            rawTranscript: rawTranscript,
            finalText: finalText,
            processingLevel: processingLevel,
            capturedAt: Date()
        )
    }

    public func latestSnapshot() -> Snapshot? {
        pruneExpired()
        return snapshot
    }

    public func latestRawTranscript() -> String? {
        latestSnapshot()?.rawTranscript
    }

    public func clear() {
        snapshot = nil
    }

    private func pruneExpired() {
        guard let snapshot else { return }
        let age = Date().timeIntervalSince(snapshot.capturedAt)
        if age < 0 || age >= ttlSeconds {
            self.snapshot = nil
        }
    }
}
