import Foundation
import VoxCore
import VoxMac

@MainActor
public final class PreferencesStore: ObservableObject, PreferencesReading {
    public static let shared = PreferencesStore()
    private let defaults = UserDefaults.standard

    @Published public var processingLevel: ProcessingLevel {
        didSet {
            defaults.set(processingLevel.rawValue, forKey: "processingLevel")
            #if DEBUG
            if oldValue != processingLevel {
                print("[Vox] Processing level updated: \(oldValue.rawValue) -> \(processingLevel.rawValue)")
            }
            #endif
        }
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

    /// Cached configured-status for each Keychain key. Updated on every write; avoids
    /// synchronous Keychain reads in SwiftUI `body` during view re-renders.
    @Published public private(set) var keyStatusCache: [KeychainHelper.Key: Bool] = [:]

    private init() {
        let stored = defaults.string(forKey: "processingLevel") ?? "clean"
        processingLevel = ProcessingLevel(rawValue: stored) ?? .clean
        if processingLevel.rawValue != stored {
            defaults.set(processingLevel.rawValue, forKey: "processingLevel")
        }
        selectedInputDeviceUID = defaults.string(forKey: "selectedInputDeviceUID")
        keyStatusCache = [
            .elevenLabsAPIKey: !apiKey(env: "ELEVENLABS_API_KEY", keychain: .elevenLabsAPIKey).isEmpty,
            .deepgramAPIKey: !apiKey(env: "DEEPGRAM_API_KEY", keychain: .deepgramAPIKey).isEmpty,
            .openRouterAPIKey: !apiKey(env: "OPENROUTER_API_KEY", keychain: .openRouterAPIKey).isEmpty,
            .geminiAPIKey: !apiKey(env: "GEMINI_API_KEY", keychain: .geminiAPIKey).isEmpty,
        ]
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

    public var geminiAPIKey: String {
        get { apiKey(env: "GEMINI_API_KEY", keychain: .geminiAPIKey) }
        set { setAPIKey(newValue, for: .geminiAPIKey) }
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
        // Re-evaluate effective status so env-var overrides are respected.
        keyStatusCache[key] = isEffectivelyConfigured(key)
        objectWillChange.send()
    }

    private func isEffectivelyConfigured(_ key: KeychainHelper.Key) -> Bool {
        switch key {
        case .elevenLabsAPIKey: return !elevenLabsAPIKey.isEmpty
        case .deepgramAPIKey:   return !deepgramAPIKey.isEmpty
        case .openRouterAPIKey: return !openRouterAPIKey.isEmpty
        case .geminiAPIKey:     return !geminiAPIKey.isEmpty
        }
    }
}
