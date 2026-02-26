import Foundation
import Testing
@testable import VoxAppKit
import VoxCore

@Suite("PreferencesStore capability-aware default level")
@MainActor
struct PreferencesStoreDefaultLevelTests {

    @Test("returns .clean when hasRewrite is true")
    func defaultLevelWithRewrite() {
        let level = PreferencesStore.capabilityAwareDefaultLevel(hasRewrite: true)
        #expect(level == .clean)
    }

    @Test("returns .raw on macOS < 26 without rewrite keys, .clean on macOS 26+")
    func defaultLevelWithoutRewrite() {
        let level = PreferencesStore.capabilityAwareDefaultLevel(hasRewrite: false)
        #if canImport(FoundationModels)
        // FoundationModels SDK present ↔ macOS 26+ → always .clean
        #expect(level == .clean)
        #else
        // No FoundationModels, no rewrite keys → .raw to avoid silent fallback
        #expect(level == .raw)
        #endif
    }

    @Test("hasRewrite wins even when FoundationModels is absent")
    func rewriteTakesPrecedenceOverOS() {
        // hasRewrite: true is the dominant signal — result must be .clean regardless of SDK
        let level = PreferencesStore.capabilityAwareDefaultLevel(hasRewrite: true)
        #expect(level == .clean)
    }
}
