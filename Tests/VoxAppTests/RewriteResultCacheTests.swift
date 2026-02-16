import Foundation
import Testing
@testable import VoxCore
@testable import VoxAppKit

@Suite("RewriteResultCache")
struct RewriteResultCacheTests {
    @Test("Store and load cached value")
    func value_storeAndLoad() async {
        let cache = RewriteResultCache(maxEntries: 4, ttlSeconds: 60, maxCharacterCount: 1_024)

        await cache.store("Hello, world!", for: "hello world", level: .clean, model: "model-a")
        let value = await cache.value(for: "hello world", level: .clean, model: "model-a")

        #expect(value == "Hello, world!")
    }

    @Test("Entries expire after TTL")
    func value_expiredAfterTTL() async throws {
        let cache = RewriteResultCache(maxEntries: 4, ttlSeconds: 0.01, maxCharacterCount: 1_024)

        await cache.store("cached", for: "source", level: .clean, model: "model-a")
        try await Task.sleep(nanoseconds: 30_000_000)

        let value = await cache.value(for: "source", level: .clean, model: "model-a")
        #expect(value == nil)
    }

    @Test("Evicts oldest entry when capacity is reached")
    func value_evictsOldestWhenAtCapacity() async throws {
        let cache = RewriteResultCache(maxEntries: 2, ttlSeconds: 60, maxCharacterCount: 1_024)

        await cache.store("one", for: "one", level: .clean, model: "model-a")
        try await Task.sleep(nanoseconds: 1_000_000)
        await cache.store("two", for: "two", level: .clean, model: "model-a")
        try await Task.sleep(nanoseconds: 1_000_000)
        await cache.store("three", for: "three", level: .clean, model: "model-a")

        let one = await cache.value(for: "one", level: .clean, model: "model-a")
        let two = await cache.value(for: "two", level: .clean, model: "model-a")
        let three = await cache.value(for: "three", level: .clean, model: "model-a")

        #expect(one == nil)
        #expect(two == "two")
        #expect(three == "three")
    }

    @Test("Cache key isolates level and model")
    func value_isolatedByLevelAndModel() async {
        let cache = RewriteResultCache(maxEntries: 4, ttlSeconds: 60, maxCharacterCount: 1_024)

        await cache.store("cached", for: "same", level: .clean, model: "model-a")

        let exact = await cache.value(for: "same", level: .clean, model: "model-a")
        let wrongLevel = await cache.value(for: "same", level: .polish, model: "model-a")
        let wrongModel = await cache.value(for: "same", level: .clean, model: "model-b")

        #expect(exact == "cached")
        #expect(wrongLevel == nil)
        #expect(wrongModel == nil)
    }

    @Test("Oversized entries are not cached")
    func store_oversizedEntry_notCached() async {
        let cache = RewriteResultCache(maxEntries: 4, ttlSeconds: 60, maxCharacterCount: 1_024)
        let oversized = String(repeating: "x", count: 1_100)

        await cache.store(oversized, for: oversized, level: .clean, model: "model-a")
        let value = await cache.value(for: oversized, level: .clean, model: "model-a")

        #expect(value == nil)
    }
}
