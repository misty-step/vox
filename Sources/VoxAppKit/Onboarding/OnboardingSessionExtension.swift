import VoxCore

@MainActor
final class OnboardingSessionExtension: SessionExtension {
    private let onboarding: OnboardingStore

    init(onboarding: OnboardingStore) {
        self.onboarding = onboarding
    }

    func didCompleteDictation(event: DictationUsageEvent) async {
        onboarding.markFirstDictationCompleted()
    }
}
