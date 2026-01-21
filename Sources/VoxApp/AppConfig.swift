import Foundation
import VoxCore

struct RewriteProviderConfig: Codable {
    let id: String
    let apiKey: String
    let modelId: String
    let temperature: Double?
    let maxOutputTokens: Int?
    let thinkingLevel: String?

    var normalizedId: String {
        id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct RewriteProviderSelection {
    let id: String
    let apiKey: String
    let modelId: String
    let temperature: Double?
    let maxOutputTokens: Int?
    let thinkingLevel: String?
}

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
        let providers: [RewriteProviderConfig]?
        let apiKey: String?
        let modelId: String?
        let temperature: Double?
        let maxOutputTokens: Int?
        let thinkingLevel: String?

        func resolvedProvider() throws -> RewriteProviderSelection {
            let selectedId = provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !selectedId.isEmpty else {
                throw VoxError.internalError("Rewrite provider is required.")
            }

            let rawConfig: RewriteProviderConfig
            if let providers {
                guard let match = providers.first(where: { $0.normalizedId == selectedId }) else {
                    throw VoxError.internalError("Missing rewrite provider config for '\(selectedId)'.")
                }
                rawConfig = match
            } else {
                rawConfig = RewriteProviderConfig(
                    id: selectedId,
                    apiKey: apiKey ?? "",
                    modelId: modelId ?? "",
                    temperature: temperature,
                    maxOutputTokens: maxOutputTokens,
                    thinkingLevel: thinkingLevel
                )
            }

            let apiKey = rawConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let modelId = rawConfig.modelId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !apiKey.isEmpty else {
                throw VoxError.internalError("Missing API key for rewrite provider '\(selectedId)'.")
            }
            guard !modelId.isEmpty else {
                throw VoxError.internalError("Missing model id for rewrite provider '\(selectedId)'.")
            }
            return RewriteProviderSelection(
                id: selectedId,
                apiKey: apiKey,
                modelId: modelId,
                temperature: rawConfig.temperature,
                maxOutputTokens: rawConfig.maxOutputTokens,
                thinkingLevel: rawConfig.thinkingLevel
            )
        }
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

struct ProcessingLevelOverride: Equatable {
    let level: ProcessingLevel
    let sourceKey: String
}

enum ConfigLoader {
    enum Source {
        case envLocal
        case file
    }

    struct LoadedConfig {
        let config: AppConfig
        let source: Source
        let processingLevelOverride: ProcessingLevelOverride?
    }

    static let configURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/Vox/config.json")
    }()

    static func load() throws -> LoadedConfig {
        if let loaded = try loadFromDotEnv() {
            Diagnostics.info("Loaded config from .env.local")
            return loaded
        }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: configURL.path) {
            try createSampleConfig(at: configURL)
            throw VoxError.internalError("Missing config. Sample created at \(configURL.path).")
        }

        let data = try Data(contentsOf: configURL)
        var config = try JSONDecoder().decode(AppConfig.self, from: data)
        _ = try RewriteConfigResolver.resolve(config.rewrite)
        config.normalized()
        Diagnostics.info("Loaded config from \(configURL.path)")
        return LoadedConfig(config: config, source: .file, processingLevelOverride: nil)
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
                providers: [
                    RewriteProviderConfig(
                        id: "gemini",
                        apiKey: "YOUR_GEMINI_API_KEY",
                        modelId: "gemini-3-pro-preview",
                        temperature: 0.2,
                        maxOutputTokens: GeminiModelPolicy.maxOutputTokens(for: "gemini-3-pro-preview"),
                        thinkingLevel: "high"
                    )
                ],
                apiKey: nil,
                modelId: nil,
                temperature: nil,
                maxOutputTokens: nil,
                thinkingLevel: nil
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

    private static func loadFromDotEnv() throws -> LoadedConfig? {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".env.local")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let env = try DotEnvLoader.load(from: url)

        guard let elevenKey = env["ELEVENLABS_API_KEY"] else {
            throw VoxError.internalError("Missing ELEVENLABS_API_KEY in .env.local")
        }

        let sttModel = env["ELEVENLABS_MODEL_ID"] ?? "scribe_v2"
        let sttLanguage = env["ELEVENLABS_LANGUAGE"]

        let rewriteProvider = env["VOX_REWRITE_PROVIDER"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "gemini"
        var rewriteProviders: [RewriteProviderConfig] = []

        if let geminiKey = env["GEMINI_API_KEY"] {
            let rewriteModel = env["GEMINI_MODEL_ID"] ?? "gemini-3-pro-preview"
            let temperature = Double(env["GEMINI_TEMPERATURE"] ?? "") ?? 0.2
            let requestedMaxTokens = Int(env["GEMINI_MAX_TOKENS"] ?? "")
            let maxTokens = GeminiModelPolicy.effectiveMaxOutputTokens(
                requested: requestedMaxTokens,
                modelId: rewriteModel
            )
            let thinking = env["GEMINI_THINKING_LEVEL"]
            rewriteProviders.append(
                RewriteProviderConfig(
                    id: "gemini",
                    apiKey: geminiKey,
                    modelId: rewriteModel,
                    temperature: temperature,
                    maxOutputTokens: maxTokens,
                    thinkingLevel: thinking
                )
            )
        }

        if let openRouterKey = env["OPENROUTER_API_KEY"] {
            let modelId = env["OPENROUTER_MODEL_ID"] ?? ""
            let temperature = Double(env["OPENROUTER_TEMPERATURE"] ?? "")
            let maxTokens = Int(env["OPENROUTER_MAX_TOKENS"] ?? "")
            rewriteProviders.append(
                RewriteProviderConfig(
                    id: "openrouter",
                    apiKey: openRouterKey,
                    modelId: modelId,
                    temperature: temperature,
                    maxOutputTokens: maxTokens,
                    thinkingLevel: nil
                )
            )
        }

        if rewriteProviders.isEmpty {
            throw VoxError.internalError("Missing rewrite provider config in .env.local")
        }

        let contextPath = env["VOX_CONTEXT_PATH"] ?? AppConfig.defaultContextPath
        let processingLevelOverride = processingLevelOverride(from: env)
        let envProcessingLevel = processingLevelOverride?.level
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
                provider: rewriteProvider,
                providers: rewriteProviders,
                apiKey: nil,
                modelId: nil,
                temperature: nil,
                maxOutputTokens: nil,
                thinkingLevel: nil
            ),
            processingLevel: processingLevel,
            hotkey: .default,
            contextPath: contextPath
        )
        _ = try RewriteConfigResolver.resolve(config.rewrite)
        config.normalized()
        return LoadedConfig(
            config: config,
            source: .envLocal,
            processingLevelOverride: processingLevelOverride
        )
    }

    private static func loadProcessingLevelFromConfigFile() -> ProcessingLevel? {
        guard FileManager.default.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return nil
        }
        return config.processingLevel
    }

    static func processingLevelOverride(from env: [String: String]) -> ProcessingLevelOverride? {
        if let raw = env["VOX_PROCESSING_LEVEL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let level = ProcessingLevel(rawValue: raw.lowercased()) {
            return ProcessingLevelOverride(level: level, sourceKey: "VOX_PROCESSING_LEVEL")
        }
        if let raw = env["VOX_REWRITE_LEVEL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let level = ProcessingLevel(rawValue: raw.lowercased()) {
            return ProcessingLevelOverride(level: level, sourceKey: "VOX_REWRITE_LEVEL")
        }
        return nil
    }
}
