import Foundation
import VoxLocalCore

public final class OpenRouterClient {
    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcript]
            ],
            // Disable reasoning for faster responses
            "reasoning": [
                "enabled": false
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://voxlocal.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("VoxLocal", forHTTPHeaderField: "X-Title")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RewriteError.network("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
            guard let content = result.choices.first?.message.content else {
                throw RewriteError.unknown("No content")
            }
            return content
        case 401: throw RewriteError.auth
        case 429: throw RewriteError.throttled
        default: throw RewriteError.unknown("HTTP \(httpResponse.statusCode)")
        }
    }
}

private struct OpenRouterResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}
