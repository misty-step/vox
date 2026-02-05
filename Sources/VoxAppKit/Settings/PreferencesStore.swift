import Foundation
import VoxCore
import VoxMac

public final class PreferencesStore: ObservableObject, PreferencesReading, @unchecked Sendable {
    public static let shared = PreferencesStore()
    private let defaults = UserDefaults.standard

    @Published public var processingLevel: ProcessingLevel {
        didSet { defaults.set(processingLevel.rawValue, forKey: "processingLevel") }
    }

    @Published public var customContext: String {
        didSet { defaults.set(customContext, forKey: "customContext") }
    }

    @Published public var selectedInputDeviceUID: String? {
        didSet {
            if let uid = selectedInputDeviceUID {
                defaults.set(uid, forKey: "selectedInputDeviceUID")
            } else {
                defaults.removeObject(forKey: "selectedInputDeviceUID")
            }
        }
    }

    private init() {
        processingLevel = ProcessingLevel(rawValue: defaults.string(forKey: "processingLevel") ?? "light") ?? .light
        customContext = defaults.string(forKey: "customContext") ?? ""
        selectedInputDeviceUID = defaults.string(forKey: "selectedInputDeviceUID")
    }

    public var elevenLabsAPIKey: String {
        get { apiKey(env: "ELEVENLABS_API_KEY", keychain: .elevenLabsAPIKey) }
        set { setAPIKey(newValue, for: .elevenLabsAPIKey) }
    }

    public var openRouterAPIKey: String {
        get { apiKey(env: "OPENROUTER_API_KEY", keychain: .openRouterAPIKey) }
        set { setAPIKey(newValue, for: .openRouterAPIKey) }
    }

    public var deepgramAPIKey: String {
        get { apiKey(env: "DEEPGRAM_API_KEY", keychain: .deepgramAPIKey) }
        set { setAPIKey(newValue, for: .deepgramAPIKey) }
    }

    public var openAIAPIKey: String {
        get { apiKey(env: "OPENAI_API_KEY", keychain: .openAIAPIKey) }
        set { setAPIKey(newValue, for: .openAIAPIKey) }
    }

    private func apiKey(env: String, keychain: KeychainHelper.Key) -> String {
        if let envKey = ProcessInfo.processInfo.environment[env], !envKey.isEmpty {
            return envKey
        }
        return KeychainHelper.load(keychain) ?? ""
    }

    private func setAPIKey(_ value: String, for key: KeychainHelper.Key) {
        KeychainHelper.save(value, for: key)
        objectWillChange.send()
    }
}
