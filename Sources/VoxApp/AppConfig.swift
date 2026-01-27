import Darwin
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
        return home.appendingPathComponent("Library/Application Support/Vox/context.md").path
    }
}

struct ProcessingLevelOverride: Equatable {
    let level: ProcessingLevel
    let sourceKey: String
}

enum ConfigLoader {
    enum Source: CustomStringConvertible {
        case envLocal
        case file
        case defaults

        var description: String {
            switch self {
            case .envLocal: ".env.local"
            case .file: "config.json"
            case .defaults: "defaults"
            }
        }
    }

    struct LoadedConfig {
        let config: AppConfig
        let source: Source
        let processingLevelOverride: ProcessingLevelOverride?
    }

    static let configURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Application Support/Vox/config.json")
    }()

    static func load() throws -> LoadedConfig {
        if let loaded = try loadFromDotEnv() {
            return loaded
        }
        return try loadFromFileOrDefaults()
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

        let sample = sampleConfig()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sample)
        try data.write(to: url, options: .atomic)
    }

    private static func sampleConfig() -> AppConfig {
        AppConfig(
            stt: AppConfig.STTConfig(
                provider: "elevenlabs",
                apiKey: "YOUR_ELEVENLABS_API_KEY",
                modelId: "scribe_v2",
                languageCode: "en",
                fileFormat: nil
            ),
            rewrite: AppConfig.RewriteConfig(
                provider: "openrouter",
                providers: [
                    RewriteProviderConfig(
                        id: "openrouter",
                        apiKey: "YOUR_OPENROUTER_API_KEY",
                        modelId: "xiaomi/mimo-v2-flash",
                        temperature: 0.2,
                        maxOutputTokens: 4096,
                        thinkingLevel: nil
                    ),
                    RewriteProviderConfig(
                        id: "gemini",
                        apiKey: "YOUR_GEMINI_API_KEY",
                        modelId: "gemini-3-flash-preview",
                        temperature: 0.2,
                        maxOutputTokens: GeminiModelPolicy.maxOutputTokens(for: "gemini-3-flash-preview"),
                        thinkingLevel: nil
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
    }

    private static func loadFromDotEnv() throws -> LoadedConfig? {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".env.local")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let env = try DotEnvLoader.load(from: url)
        applyGatewayEnvOverrides(from: env)
        let processingLevelOverride = processingLevelOverride(from: env)
        let envProcessingLevel = processingLevelOverride?.level
        let storedProcessingLevel = ProcessingLevelStore.load() ?? loadProcessingLevelFromConfigFile()

        var loaded = try loadFromFileOrDefaults()
        var config = loaded.config
        let processingLevel = envProcessingLevel ?? storedProcessingLevel ?? config.processingLevel ?? .light
        if let contextPath = trimmed(env["VOX_CONTEXT_PATH"]) {
            config.contextPath = contextPath
        }
        config.processingLevel = processingLevel
        config.normalized()
        Diagnostics.info("Loaded env overrides from .env.local")
        return LoadedConfig(
            config: config,
            source: loaded.source,
            processingLevelOverride: processingLevelOverride
        )
    }

    private static func loadFromFileOrDefaults() throws -> LoadedConfig {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: configURL.path) {
            do {
                try createSampleConfig(at: configURL)
            } catch {
                Diagnostics.warning("Failed to create sample config: \(String(describing: error))")
            }
            var config = sampleConfig()
            let storedProcessingLevel = ProcessingLevelStore.load()
            if config.processingLevel == nil {
                config.processingLevel = storedProcessingLevel ?? .light
            } else if let storedProcessingLevel {
                config.processingLevel = storedProcessingLevel
            }
            _ = try RewriteConfigResolver.resolve(config.rewrite)
            config.normalized()
            Diagnostics.info("No config file found. Using defaults.")
            return LoadedConfig(config: config, source: .defaults, processingLevelOverride: nil)
        }

        let data = try Data(contentsOf: configURL)
        var config = try JSONDecoder().decode(AppConfig.self, from: data)
        _ = try RewriteConfigResolver.resolve(config.rewrite)
        config.normalized()
        Diagnostics.info("Loaded config from \(configURL.path)")
        return LoadedConfig(config: config, source: .file, processingLevelOverride: nil)
    }

    private static func applyGatewayEnvOverrides(from env: [String: String]) {
        setEnvIfMissing("VOX_GATEWAY_URL", env: env)
        setEnvIfMissing("VOX_WEB_URL", env: env)
    }

    private static func setEnvIfMissing(_ key: String, env: [String: String]) {
        guard let value = trimmed(env[key]) else { return }
        if let existing = trimmed(ProcessInfo.processInfo.environment[key]), !existing.isEmpty {
            return
        }
        setenv(key, value, 0)
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
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
