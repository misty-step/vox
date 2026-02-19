import Foundation
import VoxCore

actor LastDictationRecoveryStore {
    struct Snapshot: Sendable, Equatable {
        let rawTranscript: String
        let finalText: String
        let processingLevel: ProcessingLevel
        let capturedAt: Date
    }

    static let shared = LastDictationRecoveryStore(ttlSeconds: 600)

    private let ttlSeconds: TimeInterval
    private var snapshot: Snapshot?

    init(ttlSeconds: TimeInterval) {
        self.ttlSeconds = max(0.001, ttlSeconds)
    }

    func store(rawTranscript: String, finalText: String, processingLevel: ProcessingLevel) {
        snapshot = Snapshot(
            rawTranscript: rawTranscript,
            finalText: finalText,
            processingLevel: processingLevel,
            capturedAt: Date()
        )
    }

    func latestSnapshot() -> Snapshot? {
        pruneExpired()
        return snapshot
    }

    func latestRawTranscript() -> String? {
        latestSnapshot()?.rawTranscript
    }

    func clear() {
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
