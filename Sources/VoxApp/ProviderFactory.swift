import Foundation
import VoxCore
import VoxProviders

enum ProviderFactory {
    static func makeSTT(config: AppConfig.STTConfig, useDefaultGateway: Bool = false) throws -> STTProvider {
        if let gateway = try gatewayClient(useDefaultGateway: useDefaultGateway) {
            return GatewaySTTProvider(gateway: gateway, config: config)
        }
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

    static func makeRewrite(selection: RewriteProviderSelection, useDefaultGateway: Bool = false) throws -> RewriteProvider {
        if let gateway = try gatewayClient(useDefaultGateway: useDefaultGateway) {
            return GatewayRewriteProvider(gateway: gateway)
        }
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

    private static func gatewayClient(
        env: [String: String] = ProcessInfo.processInfo.environment,
        useDefaultGateway: Bool = false
    ) throws -> GatewayClient? {
        if let rawURL = env["VOX_GATEWAY_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawURL.isEmpty {
            guard let url = URL(string: rawURL), url.scheme != nil else {
                throw VoxError.internalError("Invalid VOX_GATEWAY_URL: \(rawURL)")
            }
            return GatewayClient(baseURL: url, tokenProvider: tokenProvider(env: env))
        }
        guard useDefaultGateway, let url = GatewayURL.api, url.scheme != nil else {
            return nil
        }
        return GatewayClient(baseURL: url, tokenProvider: tokenProvider(env: env))
    }

    private static func tokenProvider(env: [String: String]) -> @Sendable () -> String? {
        let envToken = trimmed(env["VOX_GATEWAY_TOKEN"])
        return {
            let keychainToken: String? = if Thread.isMainThread {
                trimmed(MainActor.assumeIsolated { AuthManager.shared.token })
            } else {
                trimmed(KeychainHelper.load())
            }
            return keychainToken ?? envToken
        }
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
