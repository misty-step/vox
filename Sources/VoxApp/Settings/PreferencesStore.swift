import Foundation
import VoxCore
import VoxMac

public final class PreferencesStore: ObservableObject {
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
        get {
            if let envKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"], !envKey.isEmpty {
                return envKey
            }
            return KeychainHelper.load(.elevenLabsAPIKey) ?? ""
        }
        set { KeychainHelper.save(newValue, for: .elevenLabsAPIKey); objectWillChange.send() }
    }

    public var openRouterAPIKey: String {
        get {
            if let envKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !envKey.isEmpty {
                return envKey
            }
            return KeychainHelper.load(.openRouterAPIKey) ?? ""
        }
        set { KeychainHelper.save(newValue, for: .openRouterAPIKey); objectWillChange.send() }
    }

    public var deepgramAPIKey: String {
        get {
            if let envKey = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"], !envKey.isEmpty {
                return envKey
            }
            return KeychainHelper.load(.deepgramAPIKey) ?? ""
        }
        set { KeychainHelper.save(newValue, for: .deepgramAPIKey); objectWillChange.send() }
    }

    public var openAIAPIKey: String {
        get {
            if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
                return envKey
            }
            return KeychainHelper.load(.openAIAPIKey) ?? ""
        }
        set { KeychainHelper.save(newValue, for: .openAIAPIKey); objectWillChange.send() }
    }
}
