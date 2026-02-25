import Foundation
import VoxCore

public enum OpenRouterRoutingMode: String, Sendable, Equatable {
    case strictParameters = "strict"
    case relaxedParameters = "relaxed"
}

public struct OpenRouterRewriteDiagnostic: Sendable, Equatable {
    public enum Outcome: String, Sendable, Equatable {
        case success
        case failure
        case relaxedRetry
    }

    public let outcome: Outcome
    public let requestedModel: String
    public let routerModel: String
    public let servedModel: String?
    public let attempt: Int
    public let isFallbackModel: Bool
    public let routingMode: OpenRouterRoutingMode
    public let elapsedMs: Int?
    public let httpStatusCode: Int?
    public let errorCode: String?
    public let errorMessage: String?

    public init(
        outcome: Outcome,
        requestedModel: String,
        routerModel: String,
        servedModel: String?,
        attempt: Int,
        isFallbackModel: Bool,
        routingMode: OpenRouterRoutingMode,
        elapsedMs: Int?,
        httpStatusCode: Int?,
        errorCode: String?,
        errorMessage: String?
    ) {
        self.outcome = outcome
        self.requestedModel = requestedModel
        self.routerModel = routerModel
        self.servedModel = servedModel
        self.attempt = attempt
        self.isFallbackModel = isFallbackModel
        self.routingMode = routingMode
        self.elapsedMs = elapsedMs
        self.httpStatusCode = httpStatusCode
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

public final class OpenRouterClient: RewriteProvider {
    private let apiKey: String
    private let session: URLSession
    private let fallbackModels: [String]
    private let onModelUsed: (@Sendable (_ routerModel: String, _ isFallback: Bool) -> Void)?
    private let onDiagnostic: (@Sendable (OpenRouterRewriteDiagnostic) -> Void)?

    public init(
        apiKey: String,
        session: URLSession = .shared,
        fallbackModels: [String] = [],
        onModelUsed: (@Sendable (_ routerModel: String, _ isFallback: Bool) -> Void)? = nil,
        onDiagnostic: (@Sendable (OpenRouterRewriteDiagnostic) -> Void)? = nil
    ) {
        self.apiKey = apiKey
        self.session = session
        self.fallbackModels = fallbackModels
        self.onModelUsed = onModelUsed
        self.onDiagnostic = onDiagnostic
    }

    public func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        let models = modelChain(primary: model)
        var lastError: Error?

        for (index, currentModel) in models.enumerated() {
            try Task.checkCancellation()
            let start = CFAbsoluteTimeGetCurrent()
            let attempt = index + 1
            let isFallbackModel = index > 0

            do {
                let rewriteResult = try await executeRequestWithRoutingFallback(
                    transcript: transcript,
                    systemPrompt: systemPrompt,
                    model: currentModel,
                    attempt: attempt,
                    isFallbackModel: isFallbackModel
                )
                onModelUsed?(rewriteResult.servedModel, isFallbackModel)
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                if isFallbackModel {
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
        let routingMode: OpenRouterRoutingMode
    }

    private func executeRequestWithRoutingFallback(
        transcript: String,
        systemPrompt: String,
        model: String,
        attempt: Int,
        isFallbackModel: Bool
    ) async throws -> RewriteResult {
        // OpenRouter requires provider-prefixed model names (e.g. "google/gemini-2.5-flash-lite")
        let routerModel = model.contains("/") ? model : "google/\(model)"

        do {
            return try await performRequest(
                transcript: transcript,
                systemPrompt: systemPrompt,
                requestedModel: model,
                routerModel: routerModel,
                attempt: attempt,
                isFallbackModel: isFallbackModel,
                routingMode: .strictParameters
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard shouldRetryWithRelaxedProviderParameters(after: error) else {
                throw error
            }

            emitDiagnostic(
                OpenRouterRewriteDiagnostic(
                    outcome: .relaxedRetry,
                    requestedModel: model,
                    routerModel: routerModel,
                    servedModel: nil,
                    attempt: attempt,
                    isFallbackModel: isFallbackModel,
                    routingMode: .strictParameters,
                    elapsedMs: nil,
                    httpStatusCode: nil,
                    errorCode: errorCode(for: error),
                    errorMessage: errorMessage(for: error)
                )
            )

            print("[Rewrite] \(routerModel) has no strict-route endpoints; retrying with relaxed provider parameters")

            return try await performRequest(
                transcript: transcript,
                systemPrompt: systemPrompt,
                requestedModel: model,
                routerModel: routerModel,
                attempt: attempt,
                isFallbackModel: isFallbackModel,
                routingMode: .relaxedParameters
            )
        }
    }

    private func performRequest(
        transcript: String,
        systemPrompt: String,
        requestedModel: String,
        routerModel: String,
        attempt: Int,
        isFallbackModel: Bool,
        routingMode: OpenRouterRoutingMode
    ) async throws -> RewriteResult {
        let start = CFAbsoluteTimeGetCurrent()
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var didEmitFailure = false

        let body: [String: Any] = [
            "model": routerModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcript],
            ],
            // Avoid optional request params that can force strict-routing endpoint misses.
            // Some models (including Mercury) do not advertise `reasoning` support in OpenRouter metadata.
            "provider": [
                "sort": "latency",
                "allow_fallbacks": true,
                "require_parameters": routingMode == .strictParameters,
            ],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://github.com/misty-step/vox", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Vox", forHTTPHeaderField: "X-Title")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RewriteError.network("Invalid response")
            }

            if httpResponse.statusCode == 200 {
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

                let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
                emitDiagnostic(
                    OpenRouterRewriteDiagnostic(
                        outcome: .success,
                        requestedModel: requestedModel,
                        routerModel: routerModel,
                        servedModel: resolvedModel,
                        attempt: attempt,
                        isFallbackModel: isFallbackModel,
                        routingMode: routingMode,
                        elapsedMs: elapsedMs,
                        httpStatusCode: httpResponse.statusCode,
                        errorCode: nil,
                        errorMessage: nil
                    )
                )

                return RewriteResult(content: content, servedModel: resolvedModel, routingMode: routingMode)
            }

            let mappedError: RewriteError
            switch httpResponse.statusCode {
            case 400, 404, 422:
                mappedError = .invalidRequest(extractErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)")
            case 401:
                mappedError = .auth
            case 402:
                mappedError = .quotaExceeded
            case 429:
                mappedError = .throttled
            case 500...599:
                mappedError = .network("HTTP \(httpResponse.statusCode)")
            default:
                if let detail = extractErrorMessage(from: data), !detail.isEmpty {
                    mappedError = .unknown("HTTP \(httpResponse.statusCode): \(detail)")
                } else {
                    mappedError = .unknown("HTTP \(httpResponse.statusCode)")
                }
            }

            let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            emitDiagnostic(
                OpenRouterRewriteDiagnostic(
                    outcome: .failure,
                    requestedModel: requestedModel,
                    routerModel: routerModel,
                    servedModel: nil,
                    attempt: attempt,
                    isFallbackModel: isFallbackModel,
                    routingMode: routingMode,
                    elapsedMs: elapsedMs,
                    httpStatusCode: httpResponse.statusCode,
                    errorCode: errorCode(for: mappedError),
                    errorMessage: errorMessage(for: mappedError)
                )
            )
            didEmitFailure = true
            throw mappedError
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if !didEmitFailure {
                let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
                emitDiagnostic(
                    OpenRouterRewriteDiagnostic(
                        outcome: .failure,
                        requestedModel: requestedModel,
                        routerModel: routerModel,
                        servedModel: nil,
                        attempt: attempt,
                        isFallbackModel: isFallbackModel,
                        routingMode: routingMode,
                        elapsedMs: elapsedMs,
                        httpStatusCode: nil,
                        errorCode: errorCode(for: error),
                        errorMessage: errorMessage(for: error)
                    )
                )
            }
            throw error
        }
    }

    private func shouldTryNextModel(after error: Error) -> Bool {
        if isRetryable(error) {
            return true
        }
        return isModelUnavailable(error)
    }

    private func shouldRetryWithRelaxedProviderParameters(after error: Error) -> Bool {
        guard case let .invalidRequest(message)? = error as? RewriteError else {
            return false
        }

        let normalized = message.lowercased()
        return normalized.contains("no endpoints") && normalized.contains("requested parameters")
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

    private func emitDiagnostic(_ event: OpenRouterRewriteDiagnostic) {
        onDiagnostic?(event)
    }

    private func errorCode(for error: Error) -> String {
        guard let rewriteError = error as? RewriteError else {
            if error is URLError {
                return "network"
            }
            return String(describing: type(of: error))
        }

        switch rewriteError {
        case .auth:
            return "auth"
        case .quotaExceeded:
            return "quotaExceeded"
        case .throttled:
            return "throttled"
        case .invalidRequest:
            return "invalidRequest"
        case .network:
            return "network"
        case .timeout:
            return "timeout"
        case .unknown:
            return "unknown"
        }
    }

    private func errorMessage(for error: Error) -> String? {
        guard let rewriteError = error as? RewriteError else {
            return nil
        }

        let raw: String
        switch rewriteError {
        case .invalidRequest(let message):
            raw = message
        case .network(let message):
            raw = message
        case .unknown(let message):
            raw = message
        default:
            return nil
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.count > 240 ? String(trimmed.prefix(240)) : trimmed
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
