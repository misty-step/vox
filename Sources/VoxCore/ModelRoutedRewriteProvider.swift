import Foundation

/// Routes rewrite requests to the right provider based on the requested model id.
///
/// Motivation:
/// - Gemini direct API expects bare Gemini model ids (e.g. "gemini-2.5-flash-lite")
/// - OpenRouter expects provider-prefixed ids for non-Google models (e.g. "x-ai/grok-4.1-fast")
/// - Some processing levels may default to OpenRouter-only models; we must not call Gemini with those ids.
public final class ModelRoutedRewriteProvider: RewriteProvider, @unchecked Sendable {
    private let gemini: (any RewriteProvider)?
    private let openRouter: (any RewriteProvider)?
    private let fallbackGeminiModel: String

    public init(
        gemini: (any RewriteProvider)?,
        openRouter: (any RewriteProvider)?,
        fallbackGeminiModel: String
    ) {
        self.gemini = gemini
        self.openRouter = openRouter
        self.fallbackGeminiModel = fallbackGeminiModel
    }

    public func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        try Task.checkCancellation()

        if let geminiModel = geminiModelName(from: model) {
            // Prefer direct Gemini when available for Gemini models.
            if let gemini {
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
                        print("[Rewrite] Gemini direct failed: \(errorSummary(error)), falling back to OpenRouter")
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
                return try await openRouter.rewrite(
                    transcript: transcript,
                    systemPrompt: systemPrompt,
                    model: model
                )
            }

            throw RewriteError.auth
        }

        // Non-Gemini model ids (e.g. "x-ai/grok-4.1-fast") require OpenRouter.
        if let openRouter {
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
                    print("[Rewrite] OpenRouter failed: \(errorSummary(error)), falling back to Gemini '\(fallbackGeminiModel)'")
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
            print("[Rewrite] No OpenRouter configured for '\(model)'; falling back to Gemini '\(fallbackGeminiModel)'")
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

    private func errorSummary(_ error: Error) -> String {
        if let r = error as? RewriteError { return r.localizedDescription }
        return String(describing: type(of: error))
    }
}
