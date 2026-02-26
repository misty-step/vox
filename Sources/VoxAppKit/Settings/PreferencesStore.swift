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
        // Read all keys once — reuse for both first-launch default and keyStatusCache.
        let statuses: [KeychainHelper.Key: Bool] = [
            .elevenLabsAPIKey: !Self.apiKey(env: "ELEVENLABS_API_KEY", keychain: .elevenLabsAPIKey).isEmpty,
            .deepgramAPIKey: !Self.apiKey(env: "DEEPGRAM_API_KEY", keychain: .deepgramAPIKey).isEmpty,
            .openRouterAPIKey: !Self.apiKey(env: "OPENROUTER_API_KEY", keychain: .openRouterAPIKey).isEmpty,
            .geminiAPIKey: !Self.apiKey(env: "GEMINI_API_KEY", keychain: .geminiAPIKey).isEmpty,
        ]

        let stored = defaults.string(forKey: "processingLevel")
        if let stored, let level = ProcessingLevel(rawValue: stored) {
            processingLevel = level
            // Normalize legacy aliases (e.g. "light" → "clean")
            if level.rawValue != stored {
                defaults.set(level.rawValue, forKey: "processingLevel")
            }
        } else {
            // First launch (or unrecognized stored value): capability-aware default.
            // Avoids silently broken Clean dictations on macOS < 26 with no rewrite keys.
            // ElevenLabs and Deepgram are STT keys — they do not enable rewrite, so they
            // are excluded here even though they appear in `statuses`.
            let hasRewrite = statuses[.geminiAPIKey, default: false]
                || statuses[.openRouterAPIKey, default: false]
            let level = Self.capabilityAwareDefaultLevel(hasRewrite: hasRewrite)
            processingLevel = level
            defaults.set(level.rawValue, forKey: "processingLevel")
        }

        selectedInputDeviceUID = defaults.string(forKey: "selectedInputDeviceUID")
        keyStatusCache = statuses
    }

    public var elevenLabsAPIKey: String {
        get { Self.apiKey(env: "ELEVENLABS_API_KEY", keychain: .elevenLabsAPIKey) }
        set { setAPIKey(newValue, for: .elevenLabsAPIKey) }
    }

    public var openRouterAPIKey: String {
        get { Self.apiKey(env: "OPENROUTER_API_KEY", keychain: .openRouterAPIKey) }
        set { setAPIKey(newValue, for: .openRouterAPIKey) }
    }

    public var deepgramAPIKey: String {
        get { Self.apiKey(env: "DEEPGRAM_API_KEY", keychain: .deepgramAPIKey) }
        set { setAPIKey(newValue, for: .deepgramAPIKey) }
    }

    public var geminiAPIKey: String {
        get { Self.apiKey(env: "GEMINI_API_KEY", keychain: .geminiAPIKey) }
        set { setAPIKey(newValue, for: .geminiAPIKey) }
    }

    private static func apiKey(env: String, keychain: KeychainHelper.Key) -> String {
        if let rawEnvKey = ProcessInfo.processInfo.environment[env] {
            let envKey = rawEnvKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !envKey.isEmpty { return envKey }
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

    /// Capability-aware first-launch default. Returns `.clean` when any AI rewrite key is
    /// present, or on macOS 26+ where Foundation Models provides on-device rewrite.
    /// Returns `.raw` otherwise so first-run Clean dictations never silently fall back.
    static func capabilityAwareDefaultLevel(hasRewrite: Bool) -> ProcessingLevel {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) { return .clean }
        #endif
        return hasRewrite ? .clean : .raw
    }
}
