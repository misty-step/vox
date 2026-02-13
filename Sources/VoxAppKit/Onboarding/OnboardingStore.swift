import Combine
import Foundation

@MainActor
final class OnboardingStore: ObservableObject {
    @Published var hasShownChecklist: Bool {
        didSet { defaults.set(hasShownChecklist, forKey: Keys.hasShownChecklist) }
    }

    @Published var hasCompletedFirstDictation: Bool {
        didSet { defaults.set(hasCompletedFirstDictation, forKey: Keys.hasCompletedFirstDictation) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasShownChecklist = defaults.bool(forKey: Keys.hasShownChecklist)
        hasCompletedFirstDictation = defaults.bool(forKey: Keys.hasCompletedFirstDictation)
    }

    func markChecklistShown() {
        hasShownChecklist = true
    }

    func markFirstDictationCompleted() {
        hasCompletedFirstDictation = true
    }
}

private enum Keys {
    static let hasShownChecklist = "onboarding.hasShownChecklist"
    static let hasCompletedFirstDictation = "onboarding.hasCompletedFirstDictation"
}
