import Foundation
import VoxCore

actor RewriteResultCache {
    static let shared = RewriteResultCache(maxEntries: 128, ttlSeconds: 600, maxCharacterCount: 1_024)

    private struct CacheKey: Hashable {
        let transcript: String
        let level: ProcessingLevel
        let model: String
    }

    private struct Entry {
        let value: String
        let createdAt: Date
    }

    private let maxEntries: Int
    private let ttlSeconds: TimeInterval
    private let maxCharacterCount: Int
    private var entries: [CacheKey: Entry] = [:]

    init(maxEntries: Int, ttlSeconds: TimeInterval, maxCharacterCount: Int) {
        self.maxEntries = max(1, maxEntries)
        self.ttlSeconds = max(0.001, ttlSeconds)
        self.maxCharacterCount = max(1, maxCharacterCount)
    }

    func value(for transcript: String, level: ProcessingLevel, model: String) -> String? {
        guard transcript.count <= maxCharacterCount else {
            return nil
        }

        let now = Date()
        pruneExpiredEntries(now: now)

        let key = CacheKey(transcript: transcript, level: level, model: model)
        guard let entry = entries[key] else {
            return nil
        }
        return entry.value
    }

    func store(_ value: String, for transcript: String, level: ProcessingLevel, model: String) {
        guard transcript.count <= maxCharacterCount, value.count <= maxCharacterCount else {
            return
        }

        let now = Date()
        pruneExpiredEntries(now: now)

        let key = CacheKey(transcript: transcript, level: level, model: model)
        if entries[key] == nil, entries.count >= maxEntries {
            evictOldestEntry()
        }

        entries[key] = Entry(value: value, createdAt: now)
    }

    private func pruneExpiredEntries(now: Date) {
        entries = entries.filter { _, entry in
            now.timeIntervalSince(entry.createdAt) < ttlSeconds
        }
    }

    private func evictOldestEntry() {
        guard let oldest = entries.min(by: { $0.value.createdAt < $1.value.createdAt }) else {
            return
        }
        entries.removeValue(forKey: oldest.key)
    }
}
