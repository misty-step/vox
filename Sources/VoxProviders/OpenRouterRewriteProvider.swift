import Foundation
import VoxCore

public struct OpenRouterConfig: Sendable {
    public let apiKey: String
    public let modelId: String
    public let endpoint: URL
    public let temperature: Double
    public let maxOutputTokens: Int?

    public init(
        apiKey: String,
        modelId: String,
        endpoint: URL? = nil,
        temperature: Double,
        maxOutputTokens: Int?
    ) {
        self.apiKey = apiKey
        self.modelId = modelId
        self.endpoint = endpoint ?? URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
    }
}

public final class OpenRouterRewriteProvider: RewriteProvider {
    public let id = "openrouter"
    private let config: OpenRouterConfig

    public init(config: OpenRouterConfig) {
        self.config = config
    }

    public func rewrite(_ request: RewriteRequest) async throws -> RewriteResponse {
        let prompt = GeminiPromptBuilder.build(for: request)

        let payload = OpenRouterChatRequest(
            model: config.modelId,
            messages: [
                OpenRouterMessage(role: "system", content: prompt.systemInstruction),
                OpenRouterMessage(role: "user", content: prompt.userPrompt)
            ],
            temperature: config.temperature,
            maxTokens: config.maxOutputTokens
        )

        var urlRequest = URLRequest(url: config.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw RewriteError.network("Missing HTTP response.")
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            let message = body.isEmpty ? "Rewrite failed with status \(http.statusCode)." : "Rewrite failed with status \(http.statusCode): \(body)"
            throw RewriteError.network(message)
        }

        let decoded = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        guard let text = decoded.firstText else {
            throw RewriteError.invalidRequest("No text in OpenRouter response.")
        }

        return RewriteResponse(finalText: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private struct OpenRouterChatRequest: Encodable {
    let model: String
    let messages: [OpenRouterMessage]
    let temperature: Double
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct OpenRouterMessage: Encodable {
    let role: String
    let content: String
}

private struct OpenRouterResponse: Decodable {
    let choices: [OpenRouterChoice]?

    var firstText: String? {
        if let content = choices?.first?.message?.content, !content.isEmpty {
            return content
        }
        if let text = choices?.first?.text, !text.isEmpty {
            return text
        }
        return nil
    }
}

private struct OpenRouterChoice: Decodable {
    let message: OpenRouterMessageResponse?
    let text: String?
}

private struct OpenRouterMessageResponse: Decodable {
    let content: String?
}
