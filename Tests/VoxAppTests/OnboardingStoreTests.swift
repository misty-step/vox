import Foundation
import Testing
@testable import VoxAppKit

@Suite("Onboarding store")
struct OnboardingStoreTests {
    @Test("Defaults to false")
    @MainActor func defaultsToFalse() {
        let defaults = makeDefaults()
        let store = OnboardingStore(defaults: defaults)

        #expect(store.hasShownChecklist == false)
        #expect(store.hasCompletedFirstDictation == false)
    }

    @Test("Persists flags via UserDefaults")
    @MainActor func persistsFlags() {
        let defaults = makeDefaults()
        var store = OnboardingStore(defaults: defaults)
        store.hasShownChecklist = true
        store.hasCompletedFirstDictation = true

        store = OnboardingStore(defaults: defaults)
        #expect(store.hasShownChecklist == true)
        #expect(store.hasCompletedFirstDictation == true)
    }
}

private func makeDefaults() -> UserDefaults {
    let suite = "vox.tests.onboarding.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
