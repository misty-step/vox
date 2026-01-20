import Foundation
import VoxCore
import VoxProviders

enum ProviderFactory {
    static func makeSTT(config: AppConfig.STTConfig) throws -> STTProvider {
        switch config.provider {
        case "elevenlabs":
            return ElevenLabsSTTProvider(
                config: ElevenLabsSTTConfig(
                    apiKey: config.apiKey,
                    modelId: config.modelId,
                    languageCode: config.languageCode,
                    fileFormat: config.fileFormat,
                    enableLogging: true
                )
            )
        default:
            throw VoxError.internalError("Unsupported STT provider: \(config.provider)")
        }
    }

    static func makeRewrite(config: AppConfig.RewriteConfig) throws -> RewriteProvider {
        switch config.provider {
        case "gemini":
            return GeminiRewriteProvider(
                config: GeminiConfig(
                    apiKey: config.apiKey,
                    modelId: config.modelId,
                    temperature: config.temperature ?? 0.2,
                    maxOutputTokens: config.maxOutputTokens ?? 2048,
                    thinkingLevel: config.thinkingLevel
                )
            )
        default:
            throw VoxError.internalError("Unsupported rewrite provider: \(config.provider)")
        }
    }
}
