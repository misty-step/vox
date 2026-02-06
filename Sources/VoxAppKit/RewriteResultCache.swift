import Foundation
import VoxCore

actor RewriteResultCache {
    static let shared = RewriteResultCache(maxEntries: 128, ttlSeconds: 600)

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
    private var entries: [CacheKey: Entry] = [:]

    init(maxEntries: Int, ttlSeconds: TimeInterval) {
        self.maxEntries = max(1, maxEntries)
        self.ttlSeconds = max(1, ttlSeconds)
    }

    func value(for transcript: String, level: ProcessingLevel, model: String) -> String? {
        let now = Date()
        pruneExpiredEntries(now: now)

        let key = CacheKey(transcript: transcript, level: level, model: model)
        guard let entry = entries[key] else {
            return nil
        }
        return entry.value
    }

    func store(_ value: String, for transcript: String, level: ProcessingLevel, model: String) {
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
