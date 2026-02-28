import Foundation
import VoxCore

public final class InceptionLabsClient: RewriteProvider {
    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        let start = CFAbsoluteTimeGetCurrent()
        let url = URL(string: "https://api.inceptionlabs.ai/v1/chat/completions")!

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcript],
            ],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RewriteError.network("Invalid response")
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start

        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(InceptionResponse.self, from: data)
            guard let content = result.choices.first?.message.content else {
                throw RewriteError.unknown("No content in response")
            }
            print("[Rewrite] \(model) completed in \(String(format: "%.2f", elapsed))s (inception)")
            return content
        case 401:
            throw RewriteError.auth
        case 402:
            throw RewriteError.quotaExceeded
        case 429:
            throw RewriteError.throttled
        case 400, 404, 422:
            throw RewriteError.invalidRequest(extractErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)")
        case 500...599:
            throw RewriteError.network("HTTP \(httpResponse.statusCode)")
        default:
            throw RewriteError.unknown("HTTP \(httpResponse.statusCode)")
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let error = object["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }
        if let message = object["message"] as? String,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct InceptionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}
