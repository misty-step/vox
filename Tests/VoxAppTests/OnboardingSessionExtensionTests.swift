import Foundation
import Testing
import VoxCore
@testable import VoxAppKit

@Suite("Onboarding session extension")
struct OnboardingSessionExtensionTests {
    @Test("Marks first dictation as completed")
    @MainActor func marksFirstDictationCompleted() async {
        let defaults = makeDefaults()
        let store = OnboardingStore(defaults: defaults)
        let ext = OnboardingSessionExtension(onboarding: store)

        #expect(store.hasCompletedFirstDictation == false)

        await ext.didCompleteDictation(event: DictationUsageEvent(
            recordingDuration: 1.2,
            outputCharacterCount: 42,
            processingLevel: .light
        ))

        #expect(store.hasCompletedFirstDictation == true)
    }
}

private func makeDefaults() -> UserDefaults {
    let suite = "vox.tests.onboarding.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
