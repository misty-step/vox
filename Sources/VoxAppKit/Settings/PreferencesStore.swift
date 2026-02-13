import Foundation
import VoxCore
import VoxMac

@MainActor
public final class PreferencesStore: ObservableObject, PreferencesReading {
    public static let shared = PreferencesStore()
    private let defaults = UserDefaults.standard

    @Published public var processingLevel: ProcessingLevel {
        didSet { defaults.set(processingLevel.rawValue, forKey: "processingLevel") }
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

    public var geminiAPIKey: String {
        get { apiKey(env: "GEMINI_API_KEY", keychain: .geminiAPIKey) }
        set { setAPIKey(newValue, for: .geminiAPIKey) }
    }

    public var voxCloudToken: String {
        get { token(env: "VOX_CLOUD_TOKEN", keychain: .voxCloudToken) }
        set { setToken(newValue, for: .voxCloudToken) }
    }

    /// Whether Vox Cloud mode is enabled (token is set and valid)
    @Published public var voxCloudEnabled: Bool = false

    private func token(env: String, keychain: KeychainHelper.Key) -> String {
        if let rawEnvKey = ProcessInfo.processInfo.environment[env] {
            let envKey = rawEnvKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !envKey.isEmpty {
                return envKey
            }
        }
        return (KeychainHelper.load(keychain) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func setToken(_ value: String, for key: KeychainHelper.Key) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainHelper.delete(key)
            voxCloudEnabled = false
        } else {
            KeychainHelper.save(trimmed, for: key)
            // Will be set to true after successful connection test
        }
        objectWillChange.send()
    }

    private func apiKey(env: String, keychain: KeychainHelper.Key) -> String {
        if let rawEnvKey = ProcessInfo.processInfo.environment[env] {
            let envKey = rawEnvKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !envKey.isEmpty {
                return envKey
            }
        }
        return (KeychainHelper.load(keychain) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func setAPIKey(_ value: String, for key: KeychainHelper.Key) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainHelper.delete(key)
        } else {
            KeychainHelper.save(trimmed, for: key)
        }
        objectWillChange.send()
    }
}
