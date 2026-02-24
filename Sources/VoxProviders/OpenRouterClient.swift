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
        let models = modelChain(primary: model)
        var lastError: Error?

        for (index, currentModel) in models.enumerated() {
            try Task.checkCancellation()
            let start = CFAbsoluteTimeGetCurrent()
            do {
                let rewriteResult = try await executeRequest(
                    transcript: transcript,
                    systemPrompt: systemPrompt,
                    model: currentModel
                )
                onModelUsed?(rewriteResult.servedModel, index > 0)
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                if index > 0 {
                    print("[Rewrite] Fallback \(currentModel) succeeded in \(String(format: "%.2f", elapsed))s")
                } else {
                    print("[Rewrite] \(currentModel) completed in \(String(format: "%.2f", elapsed))s")
                }
                return rewriteResult.content
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                lastError = error
                if index < models.count - 1, shouldTryNextModel(after: error) {
                    print("[Rewrite] \(currentModel) failed (\(String(format: "%.2f", elapsed))s), trying fallback: \(errorSummary(error))")
                    continue
                }
                throw error
            }
        }

        throw lastError ?? RewriteError.unknown("No models available")
    }

    // MARK: - Private

    private struct RewriteResult {
        let content: String
        let servedModel: String
    }

    private func executeRequest(
        transcript: String,
        systemPrompt: String,
        model: String
    ) async throws -> RewriteResult {
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
            let servedModel = result.model?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedModel: String
            if let servedModel, !servedModel.isEmpty {
                resolvedModel = servedModel
            } else {
                resolvedModel = routerModel
            }
            return RewriteResult(content: content, servedModel: resolvedModel)
        case 400, 404, 422:
            throw RewriteError.invalidRequest(extractErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)")
        case 401:
            throw RewriteError.auth
        case 402:
            throw RewriteError.quotaExceeded
        case 429:
            throw RewriteError.throttled
        case 500...599:
            throw RewriteError.network("HTTP \(httpResponse.statusCode)")
        default:
            if let detail = extractErrorMessage(from: data), !detail.isEmpty {
                throw RewriteError.unknown("HTTP \(httpResponse.statusCode): \(detail)")
            }
            throw RewriteError.unknown("HTTP \(httpResponse.statusCode)")
        }
    }

    private func shouldTryNextModel(after error: Error) -> Bool {
        if isRetryable(error) {
            return true
        }
        return isModelUnavailable(error)
    }

    private func isRetryable(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        guard let rewriteError = error as? RewriteError else {
            // Only retry known transient network errors, not arbitrary failures
            return error is URLError
        }
        switch rewriteError {
        case .throttled, .network:
            return true
        case .auth, .invalidRequest, .quotaExceeded, .timeout:
            return false
        case .unknown(let msg):
            if let code = Int(msg.replacingOccurrences(of: "HTTP ", with: "")),
               (500...599).contains(code) {
                return true
            }
            return false
        }
    }

    private func isModelUnavailable(_ error: Error) -> Bool {
        guard case let .invalidRequest(message)? = error as? RewriteError else {
            return false
        }
        let normalized = message.lowercased()
        let unavailableSignals = [
            "no endpoints",
            "not found",
            "unknown model",
            "model not found",
            "not available",
            "does not exist",
            "unsupported",
        ]
        return unavailableSignals.contains(where: normalized.contains)
    }

    private func modelChain(primary: String) -> [String] {
        var chain = [primary]

        // OpenRouter model alias bridge: some accounts expose Mercury as `inception/mercury-coder`.
        // Keep requested model as primary, then try coder alias before generic fallbacks.
        if primary == "inception/mercury" {
            chain.append("inception/mercury-coder")
        }

        chain.append(contentsOf: fallbackModels)

        var seen = Set<String>()
        return chain.filter { seen.insert($0).inserted }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if
            let error = object["error"] as? [String: Any],
            let message = error["message"] as? String,
            !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return message
        }

        if
            let message = object["message"] as? String,
            !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return message
        }

        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
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
    let model: String?
    let choices: [Choice]
}
