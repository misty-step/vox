import VoxCore

@MainActor
public final class OnboardingSessionExtension: SessionExtension {
    private let onboarding: OnboardingStore

    public init(onboarding: OnboardingStore) {
        self.onboarding = onboarding
    }

    public func didCompleteDictation(event: DictationUsageEvent) async {
        onboarding.markFirstDictationCompleted()
    }
}
