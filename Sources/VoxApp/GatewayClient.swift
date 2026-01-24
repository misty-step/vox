import Foundation
import VoxCore

/// Client for communicating with the Vox gateway API
public final class GatewayClient: Sendable {
    private let baseURL: URL
    private let authToken: String

    public init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.authToken = token
    }

    // MARK: - Public API

    /// Fetch a short-lived STT provider token from the gateway
    public func getSTTToken() async throws -> STTTokenResponse {
        try await request("POST", path: "v1/stt/token")
    }

    /// Fetch entitlements for the current user from the gateway
    public func getEntitlements() async throws -> EntitlementResponse {
        try await request("GET", path: "v1/entitlements")
    }

    /// Proxy a rewrite request through the gateway
    public func rewrite(_ body: RewriteRequest) async throws -> RewriteResponse {
        try await request("POST", path: "v1/rewrite", body: body)
    }

    // MARK: - Private HTTP Helper

    private func request<T: Decodable>(
        _ method: String,
        path: String,
        body: (some Encodable)? = nil as EmptyBody?
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { req.httpBody = try JSONEncoder().encode(body) }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GatewayError.network("Missing HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw GatewayError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct EmptyBody: Encodable {}

/// Response from /v1/stt/token
public struct STTTokenResponse: Codable, Sendable {
    public let token: String
    public let provider: String
    public let expiresAt: String
}

/// Response from /v1/entitlements
public struct EntitlementResponse: Codable, Sendable {
    public let subject: String
    public let plan: String
    public let status: String
    public let features: [String]
    public let currentPeriodEnd: Int?
}

/// Errors from gateway communication
public enum GatewayError: Error, LocalizedError {
    case network(String)
    case httpError(Int, String)

    public var errorDescription: String? {
        switch self {
        case .network(let message):
            return "Gateway network error: \(message)"
        case .httpError(let status, let body):
            return "Gateway HTTP \(status): \(body)"
        }
    }
}

/// Gateway URL from environment
enum GatewayURL {
    static var current: URL? {
        guard let raw = ProcessInfo.processInfo.environment["VOX_GATEWAY_URL"],
              !raw.isEmpty else {
            return nil
        }
        return URL(string: raw)
    }

    /// Auth page for desktop sign-in flow
    static var authDesktop: URL? {
        guard let base = current,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = "/auth/desktop"
        return components.url
    }

    /// Stripe checkout page
    static var checkout: URL? {
        current?.appendingPathComponent("api/stripe/checkout")
    }
}
