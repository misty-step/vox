import Foundation
import VoxCore

enum RewriteConfigResolver {
    static func resolve(_ config: AppConfig.RewriteConfig) throws -> RewriteProviderSelection {
        let selection = try config.resolvedProvider()
        switch selection.id {
        case "gemini":
            let modelId = GeminiModelPolicy.normalizedModelId(selection.modelId)
            try GeminiModelPolicy.ensureSupported(modelId)
            return RewriteProviderSelection(
                id: selection.id,
                apiKey: selection.apiKey,
                modelId: modelId,
                temperature: selection.temperature,
                maxOutputTokens: selection.maxOutputTokens,
                thinkingLevel: selection.thinkingLevel
            )
        case "openrouter":
            try OpenRouterModelPolicy.ensureSupported(selection.modelId)
            return selection
        default:
            throw VoxError.internalError("Unsupported rewrite provider: \(selection.id)")
        }
    }
}
