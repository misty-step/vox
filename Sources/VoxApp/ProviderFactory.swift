import Foundation
import VoxCore

enum ProviderFactory {
    static func makeSTT(config: AppConfig.STTConfig, useDefaultGateway: Bool = false) throws -> STTProvider {
        guard let gateway = try gatewayClient(useDefaultGateway: useDefaultGateway) else {
            throw VoxError.internalError("VOX_GATEWAY_URL not configured. Gateway is required.")
        }
        return GatewaySTTProvider(gateway: gateway, config: config)
    }

    static func makeRewrite(selection: RewriteProviderSelection, useDefaultGateway: Bool = false) throws -> RewriteProvider {
        guard let gateway = try gatewayClient(useDefaultGateway: useDefaultGateway) else {
            throw VoxError.internalError("VOX_GATEWAY_URL not configured. Gateway is required.")
        }
        return GatewayRewriteProvider(gateway: gateway)
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
