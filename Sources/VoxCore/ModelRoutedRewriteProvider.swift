import Foundation

/// Routes rewrite requests to the right provider based on the requested model id.
///
/// Routing lanes (checked in order):
/// - `gemini-*` / `google/gemini-*` → GeminiClient (fallback: openRouter, then error)
/// - `mercury-*` → InceptionLabsClient (fallback: gemini fallback model, then error)
/// - everything else → OpenRouterClient (fallback: gemini fallback model, then error)
public final class ModelRoutedRewriteProvider: RewriteProvider, @unchecked Sendable {
    private let gemini: (any RewriteProvider)?
    private let openRouter: (any RewriteProvider)?
    private let inception: (any RewriteProvider)?
    private let fallbackGeminiModel: String

    public init(
        gemini: (any RewriteProvider)?,
        openRouter: (any RewriteProvider)?,
        inception: (any RewriteProvider)? = nil,
        fallbackGeminiModel: String
    ) {
        self.gemini = gemini
        self.openRouter = openRouter
        self.inception = inception
        self.fallbackGeminiModel = fallbackGeminiModel
    }

    public func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        try Task.checkCancellation()

        if let geminiModel = geminiModelName(from: model) {
            // Prefer direct Gemini when available for Gemini models.
            if let gemini {
                #if DEBUG
                logRoute(path: "gemini_direct", requestedModel: model, targetModel: geminiModel)
                #endif
                do {
                    return try await gemini.rewrite(
                        transcript: transcript,
                        systemPrompt: systemPrompt,
                        model: geminiModel
                    )
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    if let openRouter {
                        #if DEBUG
                        print("[RewriteRoute] path=gemini_direct_to_openrouter requested=\(model) error=\(errorSummary(error))")
                        #endif
                        return try await openRouter.rewrite(
                            transcript: transcript,
                            systemPrompt: systemPrompt,
                            model: model
                        )
                    }
                    throw error
                }
            }

            if let openRouter {
                #if DEBUG
                logRoute(path: "gemini_via_openrouter", requestedModel: model, targetModel: model)
                #endif
                return try await openRouter.rewrite(
                    transcript: transcript,
                    systemPrompt: systemPrompt,
                    model: model
                )
            }

            throw RewriteError.auth
        }

        if let inceptionModel = inceptionModelName(from: model) {
            // Mercury models route to InceptionLabs direct; fallback to Gemini on failure.
            if let inception {
                #if DEBUG
                logRoute(path: "inception_direct", requestedModel: model, targetModel: inceptionModel)
                #endif
                do {
                    return try await inception.rewrite(
                        transcript: transcript,
                        systemPrompt: systemPrompt,
                        model: inceptionModel
                    )
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    if let gemini {
                        #if DEBUG
                        print("[RewriteRoute] path=inception_to_gemini requested=\(model) fallback_model=\(fallbackGeminiModel) error=\(errorSummary(error))")
                        #endif
                        return try await gemini.rewrite(
                            transcript: transcript,
                            systemPrompt: systemPrompt,
                            model: fallbackGeminiModel
                        )
                    }
                    throw error
                }
            }

            // No inception client; fall back to gemini.
            if let gemini {
                #if DEBUG
                print("[RewriteRoute] path=no_inception_fallback_to_gemini requested=\(model) fallback_model=\(fallbackGeminiModel)")
                #endif
                return try await gemini.rewrite(
                    transcript: transcript,
                    systemPrompt: systemPrompt,
                    model: fallbackGeminiModel
                )
            }

            throw RewriteError.auth
        }

        // Non-Gemini, non-Mercury model ids (e.g. "x-ai/grok-4.1-fast") require OpenRouter.
        if let openRouter {
            #if DEBUG
            logRoute(path: "openrouter_primary", requestedModel: model, targetModel: model)
            #endif
            do {
                return try await openRouter.rewrite(
                    transcript: transcript,
                    systemPrompt: systemPrompt,
                    model: model
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Best-effort fallback: if OpenRouter is down but Gemini is configured, keep the UX working.
                if let gemini {
                    #if DEBUG
                    print("[RewriteRoute] path=openrouter_to_gemini requested=\(model) fallback_model=\(fallbackGeminiModel) error=\(errorSummary(error))")
                    #endif
                    return try await gemini.rewrite(
                        transcript: transcript,
                        systemPrompt: systemPrompt,
                        model: fallbackGeminiModel
                    )
                }
                throw error
            }
        }

        if let gemini {
            #if DEBUG
            print("[RewriteRoute] path=no_openrouter_fallback_to_gemini requested=\(model) fallback_model=\(fallbackGeminiModel)")
            #endif
            return try await gemini.rewrite(
                transcript: transcript,
                systemPrompt: systemPrompt,
                model: fallbackGeminiModel
            )
        }

        throw RewriteError.auth
    }

    private func geminiModelName(from model: String) -> String? {
        if model.hasPrefix("gemini-") { return model }
        if model.hasPrefix("google/gemini-") {
            // OpenRouter-style id -> Gemini direct id.
            return model.split(separator: "/", maxSplits: 1).last.map(String.init)
        }
        return nil
    }

    private func inceptionModelName(from model: String) -> String? {
        model.hasPrefix("mercury-") ? model : nil
    }

    #if DEBUG
    private func logRoute(path: String, requestedModel: String, targetModel: String) {
        print("[RewriteRoute] path=\(path) requested=\(requestedModel) target=\(targetModel)")
    }
    #endif

    private func errorSummary(_ error: Error) -> String {
        if let r = error as? RewriteError { return r.localizedDescription }
        return String(describing: type(of: error))
    }
}
