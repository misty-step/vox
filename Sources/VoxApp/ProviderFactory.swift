import Foundation
import VoxCore
import VoxProviders

enum ProviderFactory {
    static func makeSTT(config: AppConfig.STTConfig) throws -> STTProvider {
        if let gateway = try gatewayClient() {
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

    static func makeRewrite(selection: RewriteProviderSelection) throws -> RewriteProvider {
        if let gateway = try gatewayClient() {
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
        env: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> GatewayClient? {
        guard let rawURL = env["VOX_GATEWAY_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawURL.isEmpty else {
            return nil
        }
        guard let url = URL(string: rawURL), url.scheme != nil else {
            throw VoxError.internalError("Invalid VOX_GATEWAY_URL: \(rawURL)")
        }
        let keychainToken: String? = {
            if Thread.isMainThread {
                return MainActor.assumeIsolated { AuthManager.shared.token }?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return KeychainHelper.load()?.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        let envToken = env["VOX_GATEWAY_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawToken = (keychainToken?.isEmpty == false) ? keychainToken : envToken
        guard let token = rawToken, !token.isEmpty else {
            throw VoxError.internalError("Missing gateway auth token (Keychain or VOX_GATEWAY_TOKEN).")
        }
        return GatewayClient(baseURL: url, token: token)
    }
}
