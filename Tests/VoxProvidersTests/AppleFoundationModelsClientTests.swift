#if canImport(FoundationModels)
import Foundation
import FoundationModels
import Testing
@testable import VoxCore
@testable import VoxProviders

@Suite("AppleFoundationModelsClient")
struct AppleFoundationModelsClientTests {
    @Test("conforms to RewriteProvider")
    func test_conformsToRewriteProvider() {
        guard #available(macOS 26.0, *) else { return }
        let client = AppleFoundationModelsClient()
        let _: any RewriteProvider = client // compile-time check
    }

    @Test("isAvailable is a Bool")
    func test_isAvailable_returnsBool() {
        guard #available(macOS 26.0, *) else { return }
        let available = AppleFoundationModelsClient.isAvailable
        // Just checks it's callable and returns Bool; doesn't assert value
        // (model availability depends on device/hardware)
        _ = available
    }

    @Test("rewrite when unavailable throws RewriteError.unknown")
    func test_rewrite_whenUnavailable_throwsUnknown() async throws {
        guard #available(macOS 26.0, *) else { return }
        // Skip if actually available - we can't force unavailability in unit tests
        guard !AppleFoundationModelsClient.isAvailable else { return }

        let client = AppleFoundationModelsClient()
        do {
            _ = try await client.rewrite(
                transcript: "hello world",
                systemPrompt: "Fix typos",
                model: "apple"
            )
            Issue.record("Expected error when unavailable")
        } catch RewriteError.unknown {
            // expected
        } catch {
            Issue.record("Expected RewriteError.unknown, got: \(error)")
        }
    }

    @Test("maps foundation model generation errors to rewrite errors")
    func test_mapGenerationError_mapsKnownErrors() {
        guard #available(macOS 26.0, *) else { return }
        let client = AppleFoundationModelsClient()
        let context = LanguageModelSession.GenerationError.Context(
            debugDescription: "Fixture context"
        )

        let rateLimited = client.mapGenerationError(.rateLimited(context))
        let assetsUnavailable = client.mapGenerationError(.assetsUnavailable(context))
        let guardrailViolation = client.mapGenerationError(.guardrailViolation(context))
        let exceededContextWindow = client.mapGenerationError(.exceededContextWindowSize(context))
        let unsupportedLanguage = client.mapGenerationError(.unsupportedLanguageOrLocale(context))

        #expect(rateLimited == RewriteError.throttled)
        #expect(assetsUnavailable == RewriteError.unknown("Apple Intelligence assets unavailable. Download may be in progress."))
        #expect(guardrailViolation == RewriteError.unknown("Content blocked by Apple safety filter"))
        #expect(exceededContextWindow == RewriteError.invalidRequest("Input exceeds context window"))
        #expect(unsupportedLanguage == RewriteError.unknown("Language or locale not supported by Apple Intelligence"))
    }
}
#endif
