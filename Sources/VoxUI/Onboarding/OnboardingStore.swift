import Combine
import Foundation

@MainActor
public final class OnboardingStore: ObservableObject {
    @Published public var hasShownChecklist: Bool {
        didSet { defaults.set(hasShownChecklist, forKey: Keys.hasShownChecklist) }
    }

    @Published public var hasCompletedFirstDictation: Bool {
        didSet { defaults.set(hasCompletedFirstDictation, forKey: Keys.hasCompletedFirstDictation) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasShownChecklist = defaults.bool(forKey: Keys.hasShownChecklist)
        hasCompletedFirstDictation = defaults.bool(forKey: Keys.hasCompletedFirstDictation)
    }

    public func markChecklistShown() {
        hasShownChecklist = true
    }

    public func markFirstDictationCompleted() {
        hasCompletedFirstDictation = true
    }
}

private enum Keys {
    static let hasShownChecklist = "onboarding.hasShownChecklist"
    static let hasCompletedFirstDictation = "onboarding.hasCompletedFirstDictation"
}
