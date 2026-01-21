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
        let selection = try RewriteConfigResolver.resolve(config)
        switch selection.id {
        case "gemini":
            let maxTokens = GeminiModelPolicy.effectiveMaxOutputTokens(
                requested: selection.maxOutputTokens,
                modelId: selection.modelId
            )
            return GeminiRewriteProvider(
                config: GeminiConfig(
                    apiKey: selection.apiKey,
                    modelId: selection.modelId,
                    temperature: selection.temperature ?? 0.2,
                    maxOutputTokens: maxTokens,
                    thinkingLevel: selection.thinkingLevel
                )
            )
        case "openrouter":
            let maxTokens = selection.maxOutputTokens.flatMap { $0 > 0 ? $0 : nil }
            return OpenRouterRewriteProvider(
                config: OpenRouterConfig(
                    apiKey: selection.apiKey,
                    modelId: selection.modelId,
                    temperature: selection.temperature ?? 0.2,
                    maxOutputTokens: maxTokens
                )
            )
        default:
            throw VoxError.internalError("Unsupported rewrite provider: \(selection.id)")
        }
    }
}
