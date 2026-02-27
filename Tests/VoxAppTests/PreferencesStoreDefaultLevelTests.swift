import Foundation
import Testing
@testable import VoxAppKit
import VoxCore

@Suite("PreferencesStore default level")
@MainActor
struct PreferencesStoreDefaultLevelTests {

    @Test("returns .clean when hasRewrite is true")
    func test_defaultLevel_returnsClean_whenHasRewrite() {
        let level = PreferencesStore.defaultLevel(hasRewrite: true)
        #expect(level == .clean)
    }

    @Test("returns .raw without rewrite keys")
    func test_defaultLevel_returnsRaw_whenNoRewrite() {
        let level = PreferencesStore.defaultLevel(hasRewrite: false)
        #expect(level == .raw)
    }
}
