import Foundation
import VoxCore

struct AppConfig: Codable {
    struct STTConfig: Codable {
        let provider: String
        let apiKey: String
        let modelId: String
        let languageCode: String?
        let fileFormat: String?
    }

    struct RewriteConfig: Codable {
        let provider: String
        let apiKey: String
        let modelId: String
        let temperature: Double?
        let maxOutputTokens: Int?
        let thinkingLevel: String?
    }

    struct HotkeyConfig: Codable {
        let keyCode: UInt32
        let modifiers: [String]

        static let `default` = HotkeyConfig(keyCode: 49, modifiers: ["option"])
    }

    let stt: STTConfig
    let rewrite: RewriteConfig
    var processingLevel: ProcessingLevel?
    var hotkey: HotkeyConfig?
    var contextPath: String?

    mutating func normalized() {
        if hotkey == nil {
            hotkey = .default
        }
        if processingLevel == nil {
            processingLevel = .light
        }
        if contextPath == nil {
            contextPath = AppConfig.defaultContextPath
        }
    }

    static var defaultContextPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/Vox/context.md").path
    }
}

enum ConfigLoader {
    enum Source {
        case envLocal
        case file
    }

    struct LoadedConfig {
        let config: AppConfig
        let source: Source
    }

    static let configURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/Vox/config.json")
    }()

    static func load() throws -> LoadedConfig {
        if let config = try loadFromDotEnv() {
            Diagnostics.info("Loaded config from .env.local")
            return LoadedConfig(config: config, source: .envLocal)
        }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: configURL.path) {
            try createSampleConfig(at: configURL)
            throw VoxError.internalError("Missing config. Sample created at \(configURL.path).")
        }

        let data = try Data(contentsOf: configURL)
        var config = try JSONDecoder().decode(AppConfig.self, from: data)
        config.normalized()
        Diagnostics.info("Loaded config from \(configURL.path)")
        return LoadedConfig(config: config, source: .file)
    }

    static func save(_ config: AppConfig) throws {
        var normalized = config
        normalized.normalized()

        let dir = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(normalized)
        try data.write(to: configURL, options: .atomic)
        Diagnostics.info("Saved config to \(configURL.path)")
    }

    private static func createSampleConfig(at url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let sample = AppConfig(
            stt: AppConfig.STTConfig(
                provider: "elevenlabs",
                apiKey: "YOUR_ELEVENLABS_API_KEY",
                modelId: "scribe_v2",
                languageCode: "en",
                fileFormat: nil
            ),
            rewrite: AppConfig.RewriteConfig(
                provider: "gemini",
                apiKey: "YOUR_GEMINI_API_KEY",
                modelId: "gemini-3-flash-preview",
                temperature: 0.2,
                maxOutputTokens: 2048,
                thinkingLevel: "high"
            ),
            processingLevel: .light,
            hotkey: .default,
            contextPath: AppConfig.defaultContextPath
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sample)
        try data.write(to: url, options: .atomic)
    }

    private static func loadFromDotEnv() throws -> AppConfig? {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".env.local")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let env = try DotEnvLoader.load(from: url)

        guard let elevenKey = env["ELEVENLABS_API_KEY"], let geminiKey = env["GEMINI_API_KEY"] else {
            throw VoxError.internalError("Missing ELEVENLABS_API_KEY or GEMINI_API_KEY in .env.local")
        }

        let sttModel = env["ELEVENLABS_MODEL_ID"] ?? "scribe_v2"
        let sttLanguage = env["ELEVENLABS_LANGUAGE"]

        let rewriteModel = env["GEMINI_MODEL_ID"] ?? "gemini-3-flash-preview"
        let temperature = Double(env["GEMINI_TEMPERATURE"] ?? "") ?? 0.2
        let maxTokens = Int(env["GEMINI_MAX_TOKENS"] ?? "") ?? 2048
        let thinking = env["GEMINI_THINKING_LEVEL"]

        let contextPath = env["VOX_CONTEXT_PATH"] ?? AppConfig.defaultContextPath
        let processingLevelValue = env["VOX_PROCESSING_LEVEL"] ?? env["VOX_REWRITE_LEVEL"] ?? ""
        let envProcessingLevel = ProcessingLevel(rawValue: processingLevelValue.lowercased())
        let storedProcessingLevel = ProcessingLevelStore.load() ?? loadProcessingLevelFromConfigFile()
        let processingLevel = envProcessingLevel ?? storedProcessingLevel ?? .light

        var config = AppConfig(
            stt: AppConfig.STTConfig(
                provider: "elevenlabs",
                apiKey: elevenKey,
                modelId: sttModel,
                languageCode: sttLanguage,
                fileFormat: nil
            ),
            rewrite: AppConfig.RewriteConfig(
                provider: "gemini",
                apiKey: geminiKey,
                modelId: rewriteModel,
                temperature: temperature,
                maxOutputTokens: maxTokens,
                thinkingLevel: thinking
            ),
            processingLevel: processingLevel,
            hotkey: .default,
            contextPath: contextPath
        )
        config.normalized()
        return config
    }

    private static func loadProcessingLevelFromConfigFile() -> ProcessingLevel? {
        guard FileManager.default.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return nil
        }
        return config.processingLevel
    }
}
