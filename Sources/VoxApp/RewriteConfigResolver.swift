import Foundation
import VoxCore

enum RewriteConfigResolver {
    static func resolve(_ config: AppConfig.RewriteConfig) throws -> RewriteProviderSelection {
        let selection = try config.resolvedProvider()
        switch selection.id {
        case "gemini":
            try GeminiModelPolicy.ensureSupported(selection.modelId)
        case "openrouter":
            try OpenRouterModelPolicy.ensureSupported(selection.modelId)
        default:
            throw VoxError.internalError("Unsupported rewrite provider: \(selection.id)")
        }
        return selection
    }
}
