import Foundation
import VoxCore

/// Client for communicating with the Vox gateway API
public final class GatewayClient: Sendable {
    private let baseURL: URL
    private let tokenProvider: @Sendable () -> String?

    public init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.tokenProvider = { token }
    }

    init(baseURL: URL, tokenProvider: @escaping @Sendable () -> String?) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
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

    /// Transcribe audio via gateway proxy
    public func transcribe(
        audioData: Data,
        filename: String,
        mimeType: String,
        modelId: String?,
        languageCode: String?,
        sessionId: String?,
        fileFormat: String?
    ) async throws -> TranscriptResponse {
        var form = MultipartFormData()

        form.addField(name: "model_id", value: modelId ?? "")

        if let languageCode {
            form.addField(name: "language_code", value: languageCode)
        }

        if let sessionId {
            form.addField(name: "session_id", value: sessionId)
        }

        if let fileFormat {
            form.addField(name: "file_format", value: fileFormat)
        }

        form.addFile(
            name: "file",
            filename: filename,
            mimeType: mimeType,
            data: audioData
        )

        let body = form.finalize()
        let url = baseURL.appendingPathComponent("v1/stt/transcribe")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let token = try resolveToken()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(
            "multipart/form-data; boundary=\(form.boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GatewayError.network("Missing HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw GatewayError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(TranscriptResponse.self, from: data)
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
        let token = try resolveToken()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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

    private func resolveToken() throws -> String {
        guard let raw = tokenProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            throw GatewayError.network("Missing auth token")
        }
        return raw
    }
}

private struct EmptyBody: Encodable {}

/// Response from /v1/stt/token
public struct STTTokenResponse: Codable, Sendable {
    public let token: String
    public let provider: String
    public let expiresAt: String
}

/// Response from /v1/stt/transcribe
public struct TranscriptResponse: Codable, Sendable {
    public let text: String
    public let languageCode: String?
    public let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case text
        case languageCode = "language_code"
        case sessionId = "session_id"
    }
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
    private static let productionAPI = URL(string: "https://gateway-theta-beige.vercel.app")!
    private static let productionWeb = URL(string: "https://web-nine-gamma-73.vercel.app")!

    /// API gateway base URL (for programmatic requests)
    static var api: URL? {
        envURL("VOX_GATEWAY_URL") ?? productionAPI
    }

    /// Web app base URL (for browser-opened pages)
    static var web: URL? {
        envURL("VOX_WEB_URL") ?? envURL("VOX_GATEWAY_URL") ?? productionWeb
    }

    /// Alias for api (backward compatibility)
    static var current: URL? { api }

    /// Auth page for desktop sign-in flow (opens in browser)
    static var authDesktop: URL? {
        webURL(path: "/auth/desktop")
    }

    /// Checkout page URL builder (opens in browser with token)
    static func checkoutPage(token: String) -> URL? {
        webURL(path: "/checkout", queryItems: [URLQueryItem(name: "token", value: token)])
    }

    // MARK: - Private Helpers

    private static func envURL(_ key: String) -> URL? {
        guard let raw = ProcessInfo.processInfo.environment[key], !raw.isEmpty else {
            return nil
        }
        return URL(string: raw)
    }

    private static func webURL(path: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        guard let base = web,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = path
        components.queryItems = queryItems
        return components.url
    }
}
