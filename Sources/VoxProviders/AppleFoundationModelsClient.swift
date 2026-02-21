import Foundation
import FoundationModels
import VoxCore

/// macOS 26+ on-device rewrite using Apple Foundation Models (system language model).
/// Availability-gated; use isAvailable before constructing or calling.
@available(macOS 26.0, *)
public final class AppleFoundationModelsClient: RewriteProvider {
    public init() {}

    /// Quick check without constructing a session. Use this before inserting into provider chains.
    public static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    public func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        guard SystemLanguageModel.default.isAvailable else {
            throw RewriteError.unknown("Apple Intelligence not available on this device")
        }

        let session = LanguageModelSession(instructions: systemPrompt)
        do {
            let response = try await session.respond(to: transcript)
            return response.content
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as LanguageModelSession.GenerationError {
            throw mapGenerationError(error)
        } catch {
            throw RewriteError.unknown(error.localizedDescription)
        }
    }

    private func mapGenerationError(_ error: LanguageModelSession.GenerationError) -> RewriteError {
        switch error {
        case .rateLimited:
            return .throttled
        case .assetsUnavailable:
            return .unknown("Apple Intelligence assets unavailable. Download may be in progress.")
        case .guardrailViolation:
            return .unknown("Content blocked by Apple safety filter")
        case .exceededContextWindowSize:
            return .invalidRequest("Input exceeds context window")
        case .unsupportedLanguageOrLocale:
            return .unknown("Language or locale not supported by Apple Intelligence")
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
