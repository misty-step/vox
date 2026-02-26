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

    @Test("returns .raw on macOS < 26 without rewrite keys, .clean on macOS 26+")
    func test_capabilityAwareDefaultLevel_returnsRawOnOldOS_whenNoRewrite() {
        let level = PreferencesStore.capabilityAwareDefaultLevel(hasRewrite: false)
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            // Foundation Models runtime available → always .clean
            #expect(level == .clean)
        } else {
            // SDK has FoundationModels but runtime is macOS < 26 → .raw
            #expect(level == .raw)
        }
        #else
        // No FoundationModels SDK, no rewrite keys → .raw to avoid silent fallback
        #expect(level == .raw)
        #endif
    }
}
