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

    /// Fetch a short-lived STT provider token from the gateway
    public func getSTTToken() async throws -> STTTokenResponse {
        let url = baseURL.appendingPathComponent("v1/stt/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GatewayError.network("Missing HTTP response")
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GatewayError.httpError(http.statusCode, body)
        }

        return try JSONDecoder().decode(STTTokenResponse.self, from: data)
    }

    /// Proxy a rewrite request through the gateway
    public func rewrite(_ request: RewriteRequest) async throws -> RewriteResponse {
        let url = baseURL.appendingPathComponent("v1/rewrite")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw GatewayError.network("Missing HTTP response")
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GatewayError.httpError(http.statusCode, body)
        }

        return try JSONDecoder().decode(RewriteResponse.self, from: data)
    }
}

/// Response from /v1/stt/token
public struct STTTokenResponse: Codable, Sendable {
    public let token: String
    public let provider: String
    public let expiresAt: String
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
