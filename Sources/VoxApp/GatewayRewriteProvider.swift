import Foundation
import VoxCore

/// Rewrite provider that proxies requests through the Vox gateway
public final class GatewayRewriteProvider: RewriteProvider, @unchecked Sendable {
    public let id = "gateway"
    private let client: GatewayClient

    public init(gateway: GatewayClient) {
        self.client = gateway
    }

    public func rewrite(_ request: RewriteRequest) async throws -> RewriteResponse {
        return try await client.rewrite(request)
    }
}
