import Foundation
import VoxCore

/// Owns all gateway API communication.
/// Hides: endpoints, auth headers, encoding/decoding, auth failure handling.
final class VoxGateway: @unchecked Sendable {
    private let baseURL: URL
    private let auth: VoxAuth
    private let http: VoxGatewayHTTPClient
    private let tokenProvider: @Sendable () async -> String?

    convenience init(baseURL: URL, auth: VoxAuth) {
        self.init(baseURL: baseURL, auth: auth, http: URLSession.shared, tokenProvider: nil)
    }

    /// Internal test seam.
    init(
        baseURL: URL,
        auth: VoxAuth,
        http: VoxGatewayHTTPClient,
        tokenProvider: (@Sendable () async -> String?)? = nil
    ) {
        self.baseURL = baseURL
        self.auth = auth
        self.http = http
        if let tokenProvider {
            self.tokenProvider = tokenProvider
        } else {
            self.tokenProvider = { await auth.currentToken() }
        }
    }

    // MARK: - Public Interface

    func transcribe(_ audio: Data) async throws -> String {
        Diagnostics.info("Gateway: transcribe request.")

        var form = MultipartFormData()
        form.addField(name: "model_id", value: "")
        form.addFile(
            name: "file",
            filename: "audio.wav",
            mimeType: "audio/wav",
            data: audio
        )

        let request = try await authorizedRequest(
            method: "POST",
            path: "v1/stt/transcribe",
            contentType: "multipart/form-data; boundary=\(form.boundary)",
            body: form.finalize()
        )

        let data = try await send(request)
        do {
            let response = try JSONDecoder().decode(TranscriptResponse.self, from: data)
            return response.text
        } catch {
            Diagnostics.error("Gateway: malformed transcribe response: \(String(describing: error))")
            throw VoxGatewayError.malformedResponse
        }
    }

    func rewrite(_ text: String, level: ProcessingLevel) async throws -> String {
        Diagnostics.info("Gateway: rewrite request (\(level.rawValue)).")

        let body = RewriteRequest(
            sessionId: UUID(),
            locale: localeIdentifier(),
            transcript: TranscriptPayload(text: text),
            context: "",
            processingLevel: level
        )

        let data = try JSONEncoder().encode(body)
        let request = try await authorizedRequest(
            method: "POST",
            path: "v1/rewrite",
            contentType: "application/json",
            body: data
        )

        let responseData = try await send(request)
        do {
            let response = try JSONDecoder().decode(RewriteResponse.self, from: responseData)
            return response.finalText
        } catch {
            Diagnostics.error("Gateway: malformed rewrite response: \(String(describing: error))")
            throw VoxGatewayError.malformedResponse
        }
    }

    func getEntitlements() async throws -> EntitlementResponse {
        Diagnostics.info("Gateway: entitlements request.")

        let request = try await authorizedRequest(
            method: "GET",
            path: "v1/entitlements",
            contentType: "application/json",
            body: nil
        )

        let data = try await send(request)
        do {
            return try JSONDecoder().decode(EntitlementResponse.self, from: data)
        } catch {
            Diagnostics.error("Gateway: malformed entitlements response: \(String(describing: error))")
            throw VoxGatewayError.malformedResponse
        }
    }

    // MARK: - Internal HTTP

    private func authorizedRequest(
        method: String,
        path: String,
        contentType: String?,
        body: Data?
    ) async throws -> URLRequest {
        let token = try await resolveToken()
        let url = baseURL.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if let body {
            request.httpBody = body
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await http.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                Diagnostics.error("Gateway: missing HTTP response.")
                throw VoxGatewayError.malformedResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                await handleAuthFailureIfNeeded(statusCode: httpResponse.statusCode)
                Diagnostics.error("Gateway: HTTP \(httpResponse.statusCode).")
                throw VoxGatewayError.httpError(httpResponse.statusCode, body)
            }

            return data
        } catch let error as VoxGatewayError {
            throw error
        } catch {
            Diagnostics.error("Gateway: network failure: \(String(describing: error))")
            throw error
        }
    }

    private func resolveToken() async throws -> String {
        let raw = await tokenProvider()?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let token = raw, !token.isEmpty else {
            Diagnostics.error("Gateway: missing auth token.")
            throw VoxGatewayError.missingToken
        }
        return token
    }

    private func handleAuthFailureIfNeeded(statusCode: Int) async {
        guard statusCode == 401 || statusCode == 403 else { return }
        Diagnostics.info("Gateway: auth failure (\(statusCode)). Signing out.")
        await MainActor.run { auth.signOut() }
    }

    private func localeIdentifier() -> String {
        let raw = Locale.current.identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "en-US" : raw
    }
}

// MARK: - Internal Collaborators

protocol VoxGatewayHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: VoxGatewayHTTPClient {}

enum VoxGatewayError: Error, LocalizedError, Equatable {
    case missingToken
    case httpError(Int, String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Missing gateway auth token."
        case .httpError(let status, let body):
            return "Gateway HTTP \(status): \(body)"
        case .malformedResponse:
            return "Gateway returned malformed response."
        }
    }
}
