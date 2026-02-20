import Testing
@testable import VoxAppKit
@testable import VoxCore

@Suite("Last dictation recovery store")
struct LastDictationRecoveryStoreTests {
    @Test("Store and load latest snapshot")
    func test_latestSnapshot_storeAndLoad() async {
        let store = LastDictationRecoveryStore(ttlSeconds: 60)

        await store.store(rawTranscript: "raw transcript", finalText: "clean transcript", processingLevel: .clean)

        let snapshot = await store.latestSnapshot()
        #expect(snapshot?.rawTranscript == "raw transcript")
        #expect(snapshot?.finalText == "clean transcript")
        #expect(snapshot?.processingLevel == .clean)
        #expect(await store.latestRawTranscript() == "raw transcript")
    }

    @Test("Snapshot expires after TTL")
    func test_latestSnapshot_expiresAfterTTL() async throws {
        let store = LastDictationRecoveryStore(ttlSeconds: 0.01)

        await store.store(rawTranscript: "raw transcript", finalText: "clean transcript", processingLevel: .clean)
        try await Task.sleep(nanoseconds: 30_000_000)

        #expect(await store.latestSnapshot() == nil)
        #expect(await store.latestRawTranscript() == nil)
    }

    @Test("Clear removes stored snapshot")
    func test_clear_removesStoredSnapshot() async {
        let store = LastDictationRecoveryStore(ttlSeconds: 60)

        await store.store(rawTranscript: "raw transcript", finalText: "clean transcript", processingLevel: .polish)
        await store.clear()

        #expect(await store.latestSnapshot() == nil)
        #expect(await store.latestRawTranscript() == nil)
    }
}
