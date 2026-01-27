import Foundation
import VoxCore

/// Token refresher that validates the current token via the gateway.
final class GatewayTokenRefresher: TokenRefresher, @unchecked Sendable {
    private let client: GatewayClient

    init(client: GatewayClient) {
        self.client = client
    }

    func refresh() async throws -> (token: String, expiresAt: Date?) {
        guard let currentToken = KeychainHelper.sessionToken else {
            throw TokenError.noToken
        }

        do {
            _ = try await client.getEntitlements()
            return (currentToken, KeychainHelper.tokenExpiry)
        } catch let error as GatewayError {
            switch error {
            case .httpError(let code, _) where code == 401 || code == 403:
                Diagnostics.warning("Gateway token invalid: HTTP \(code)")
                throw TokenError.invalidToken
            default:
                Diagnostics.warning("Gateway token refresh failed: \(error.localizedDescription)")
                throw TokenError.refreshFailed
            }
        } catch {
            Diagnostics.warning("Gateway token refresh failed: \(String(describing: error))")
            throw TokenError.refreshFailed
        }
    }
}

