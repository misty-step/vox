import Foundation
import VoxCore

public struct GeminiConfig: Sendable {
    public let apiKey: String
    public let modelId: String
    public let endpoint: URL
    public let temperature: Double
    public let maxOutputTokens: Int
    public let thinkingLevel: String?

    public init(
        apiKey: String,
        modelId: String,
        endpoint: URL? = nil,
        temperature: Double,
        maxOutputTokens: Int,
        thinkingLevel: String?
    ) {
        self.apiKey = apiKey
        self.modelId = modelId
        self.endpoint = endpoint
            ?? URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelId):generateContent")!
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
        self.thinkingLevel = thinkingLevel
    }
}

public final class GeminiRewriteProvider: RewriteProvider {
    public let id = "gemini"
    private let config: GeminiConfig

    public init(config: GeminiConfig) {
        self.config = config
    }

    public func rewrite(_ request: RewriteRequest) async throws -> RewriteResponse {
        let prompt = GeminiPromptBuilder.build(for: request)

        let payload = GeminiGenerateRequest(
            contents: [
                GeminiContent(role: "user", parts: [GeminiPart(text: prompt.userPrompt)])
            ],
            systemInstruction: GeminiSystemInstruction(parts: [GeminiPart(text: prompt.systemInstruction)]),
            generationConfig: GeminiGenerationConfig(
                temperature: config.temperature,
                maxOutputTokens: config.maxOutputTokens,
                thinkingConfig: config.thinkingLevel.map { GeminiThinkingConfig(thinkingLevel: $0) }
            )
        )

        var urlRequest = URLRequest(url: config.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(config.apiKey, forHTTPHeaderField: "x-goog-api-key")
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

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.firstText else {
            throw RewriteError.invalidRequest("No text in Gemini response.")
        }

        return RewriteResponse(finalText: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private struct GeminiGenerateRequest: Encodable {
    let contents: [GeminiContent]
    let systemInstruction: GeminiSystemInstruction
    let generationConfig: GeminiGenerationConfig
}

private struct GeminiContent: Encodable {
    let role: String
    let parts: [GeminiPart]
}

private struct GeminiSystemInstruction: Encodable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Encodable {
    let text: String
}

private struct GeminiGenerationConfig: Encodable {
    let temperature: Double
    let maxOutputTokens: Int
    let thinkingConfig: GeminiThinkingConfig?
}

private struct GeminiThinkingConfig: Encodable {
    let thinkingLevel: String
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?

    var firstText: String? {
        candidates?.first?.content.parts.first?.text
    }
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContentResponse
}

private struct GeminiContentResponse: Decodable {
    let parts: [GeminiPartResponse]
}

private struct GeminiPartResponse: Decodable {
    let text: String?
}
