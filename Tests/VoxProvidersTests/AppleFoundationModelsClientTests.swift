import Foundation
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
}
