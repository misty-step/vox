import Foundation
import VoxCore
import VoxMac

public final class PreferencesStore: ObservableObject {
    public static let shared = PreferencesStore()
    private let defaults = UserDefaults.standard

    @Published public var processingLevel: ProcessingLevel {
        didSet { defaults.set(processingLevel.rawValue, forKey: "processingLevel") }
    }

    @Published public var selectedModel: String {
        didSet { defaults.set(selectedModel, forKey: "selectedModel") }
    }

    @Published public var customContext: String {
        didSet { defaults.set(customContext, forKey: "customContext") }
    }

    public static let availableModels = [
        "google/gemini-2.5-flash-lite",
        "xiaomi/mimo-v2-flash",
        "deepseek/deepseek-v3.2",
        "google/gemini-2.5-flash",
        "moonshotai/kimi-k2.5",
        "google/gemini-3-flash-preview"
    ]

    private init() {
        processingLevel = ProcessingLevel(rawValue: defaults.string(forKey: "processingLevel") ?? "light") ?? .light
        selectedModel = defaults.string(forKey: "selectedModel") ?? "google/gemini-2.5-flash-lite"
        customContext = defaults.string(forKey: "customContext") ?? ""
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
}
