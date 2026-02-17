import Foundation
import VoxCore

public final class OpenRouterClient: RewriteProvider {
    private let apiKey: String
    private let session: URLSession
    private let fallbackModels: [String]
    private let onModelUsed: (@Sendable (_ routerModel: String, _ isFallback: Bool) -> Void)?

    public init(
        apiKey: String,
        session: URLSession = .shared,
        fallbackModels: [String] = [],
        onModelUsed: (@Sendable (_ routerModel: String, _ isFallback: Bool) -> Void)? = nil
    ) {
        self.apiKey = apiKey
        self.session = session
        self.fallbackModels = fallbackModels
        self.onModelUsed = onModelUsed
    }

    public func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        let models = [model] + fallbackModels
        var lastError: Error?

        for (index, currentModel) in models.enumerated() {
            try Task.checkCancellation()
            let start = CFAbsoluteTimeGetCurrent()
            do {
                let routerModel = currentModel.contains("/") ? currentModel : "google/\(currentModel)"
                let result = try await executeRequest(
                    transcript: transcript,
                    systemPrompt: systemPrompt,
                    model: currentModel
                )
                onModelUsed?(routerModel, index > 0)
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                if index > 0 {
                    print("[Rewrite] Fallback \(currentModel) succeeded in \(String(format: "%.2f", elapsed))s")
                } else {
                    print("[Rewrite] \(currentModel) completed in \(String(format: "%.2f", elapsed))s")
                }
                return result
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                lastError = error
                if index < models.count - 1, isRetryable(error) {
                    print("[Rewrite] \(currentModel) failed (\(String(format: "%.2f", elapsed))s), trying fallback: \(errorSummary(error))")
                    continue
                }
                throw error
            }
        }

        throw lastError ?? RewriteError.unknown("No models available")
    }

    // MARK: - Private

    private func executeRequest(
        transcript: String,
        systemPrompt: String,
        model: String
    ) async throws -> String {
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        // OpenRouter requires provider-prefixed model names (e.g. "google/gemini-2.5-flash-lite")
        let routerModel = model.contains("/") ? model : "google/\(model)"

        let body: [String: Any] = [
            "model": routerModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcript]
            ],
            "reasoning": [
                "enabled": false
            ],
            "provider": [
                "sort": "latency",
                "allow_fallbacks": true,
                "require_parameters": true
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://github.com/misty-step/vox", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Vox", forHTTPHeaderField: "X-Title")
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
        case 502, 503: throw RewriteError.network("HTTP \(httpResponse.statusCode)")
        default: throw RewriteError.unknown("HTTP \(httpResponse.statusCode)")
        }
    }

    private func isRetryable(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        guard let rewriteError = error as? RewriteError else {
            // Only retry known transient network errors, not arbitrary failures
            return error is URLError
        }
        switch rewriteError {
        case .throttled, .network: return true
        case .auth, .invalidRequest, .quotaExceeded, .timeout: return false
        case .unknown(let msg):
            if let code = Int(msg.replacingOccurrences(of: "HTTP ", with: "")),
               (500...599).contains(code) {
                return true
            }
            return false
        }
    }

    private func errorSummary(_ error: Error) -> String {
        if let rewriteError = error as? RewriteError {
            switch rewriteError {
            case .auth: return "auth"
            case .quotaExceeded: return "quotaExceeded"
            case .throttled: return "throttled"
            case .invalidRequest: return "invalidRequest"
            case .network(let msg): return "network(\(msg))"
            case .timeout: return "timeout"
            case .unknown(let msg): return msg
            }
        }
        return String(describing: type(of: error))
    }
}

private struct OpenRouterResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}
