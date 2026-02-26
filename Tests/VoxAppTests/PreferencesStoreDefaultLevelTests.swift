import Foundation
import Testing
@testable import VoxAppKit
import VoxCore

@Suite("PreferencesStore capability-aware default level")
@MainActor
struct PreferencesStoreDefaultLevelTests {

    @Test("returns .clean when hasRewrite is true")
    func test_capabilityAwareDefaultLevel_returnsClean_whenHasRewriteTrue() {
        let level = PreferencesStore.capabilityAwareDefaultLevel(hasRewrite: true)
        #expect(level == .clean)
    }

    @Test("returns .raw without rewrite keys (no on-device rewrite fallback)")
    func test_capabilityAwareDefaultLevel_returnsRaw_whenNoRewrite() {
        let level = PreferencesStore.capabilityAwareDefaultLevel(hasRewrite: false)
        #expect(level == .raw)
    }
}
