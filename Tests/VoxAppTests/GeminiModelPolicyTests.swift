import XCTest
@testable import VoxApp

final class GeminiModelPolicyTests: XCTestCase {
    func testAcceptsGemini3ProAndFlash() throws {
        XCTAssertTrue(GeminiModelPolicy.isSupported("gemini-3-pro-preview"))
        XCTAssertTrue(GeminiModelPolicy.isSupported("gemini-3-flash-preview"))
        XCTAssertNoThrow(try GeminiModelPolicy.ensureSupported("gemini-3-pro-preview"))
    }

    func testRejectsNonGemini3OrImageModels() {
        XCTAssertFalse(GeminiModelPolicy.isSupported("gemini-1.5-pro"))
        XCTAssertFalse(GeminiModelPolicy.isSupported("gemini-3-pro-image-preview"))
    }

    func testEffectiveMaxTokensClampsToLimit() {
        let max = GeminiModelPolicy.maxOutputTokens(for: "gemini-3-pro-preview")

        XCTAssertEqual(GeminiModelPolicy.effectiveMaxOutputTokens(requested: nil, modelId: "gemini-3-pro-preview"), max)
        XCTAssertEqual(GeminiModelPolicy.effectiveMaxOutputTokens(requested: max + 1, modelId: "gemini-3-pro-preview"), max)
        XCTAssertEqual(GeminiModelPolicy.effectiveMaxOutputTokens(requested: max - 1, modelId: "gemini-3-pro-preview"), max - 1)
    }
}
