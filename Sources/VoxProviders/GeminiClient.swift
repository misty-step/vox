import Foundation
import VoxCore

public final class GeminiClient: RewriteProvider {
    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        let start = CFAbsoluteTimeGetCurrent()
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": transcript]]
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RewriteError.network("Invalid response")
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start

        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(GeminiResponse.self, from: data)
            guard let content = result.candidates?.first?.content.parts.first?.text else {
                throw RewriteError.unknown("No content in response")
            }
            print("[Rewrite] \(model) completed in \(String(format: "%.2f", elapsed))s (direct)")
            return content
        case 400:
            throw RewriteError.invalidRequest(extractErrorMessage(from: data))
        case 401, 403:
            throw RewriteError.auth
        case 429:
            throw RewriteError.throttled
        case 502, 503:
            throw RewriteError.network("HTTP \(httpResponse.statusCode)")
        default:
            throw RewriteError.unknown("HTTP \(httpResponse.statusCode)")
        }
    }

    private func extractErrorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return "Bad request"
    }
}

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]?
}
