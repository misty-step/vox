import Foundation
import Testing
@testable import VoxAppKit
import VoxMac

@Suite("PreferencesStore key status cache")
@MainActor
struct PreferencesStoreCacheTests {
    /// True when an env-var override is active (env takes precedence over Keychain).
    private func envOverride(_ var: String) -> Bool {
        !(ProcessInfo.processInfo.environment[`var`] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @Test("Cache reflects effective state after key is cleared")
    func cacheReflectsClearedKey() {
        let prefs = PreferencesStore.shared
        prefs.openRouterAPIKey = ""
        // Env var overrides Keychain; cache must match effective configured state.
        #expect(prefs.keyStatusCache[.openRouterAPIKey] == envOverride("OPENROUTER_API_KEY"))
    }

    @Test("Cache reflects true after key is written")
    func cacheUpdatesOnWrite() {
        let prefs = PreferencesStore.shared
        prefs.openRouterAPIKey = "sk-test-cache-write"
        #expect(prefs.keyStatusCache[.openRouterAPIKey] == true)
        // Cleanup
        prefs.openRouterAPIKey = ""
    }

    @Test("Cache reflects effective state after key is written then cleared")
    func cacheUpdatesOnClear() {
        let prefs = PreferencesStore.shared
        prefs.openRouterAPIKey = "sk-test-cache-clear"
        prefs.openRouterAPIKey = ""
        #expect(prefs.keyStatusCache[.openRouterAPIKey] == envOverride("OPENROUTER_API_KEY"))
    }

    @Test("Cache tracks all four keys independently")
    func cacheTracksAllKeys() {
        let prefs = PreferencesStore.shared
        // Clear all first
        prefs.elevenLabsAPIKey = ""
        prefs.deepgramAPIKey = ""
        prefs.openRouterAPIKey = ""
        prefs.geminiAPIKey = ""

        // Set only Deepgram
        prefs.deepgramAPIKey = "sk-test-independent"

        // Deepgram must be true (set via Keychain or env var — either way non-empty).
        #expect(prefs.keyStatusCache[.deepgramAPIKey] == true)
        // Others reflect their effective state (env var if present, otherwise false).
        #expect(prefs.keyStatusCache[.elevenLabsAPIKey] == envOverride("ELEVENLABS_API_KEY"))
        #expect(prefs.keyStatusCache[.openRouterAPIKey] == envOverride("OPENROUTER_API_KEY"))
        #expect(prefs.keyStatusCache[.geminiAPIKey] == envOverride("GEMINI_API_KEY"))

        // Cleanup
        prefs.deepgramAPIKey = ""
    }
}
