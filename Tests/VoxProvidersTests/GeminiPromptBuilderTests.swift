import XCTest
@testable import VoxProviders
@testable import VoxCore

final class GeminiPromptBuilderTests: XCTestCase {
    func testLightPromptEmphasizesMinimalEdits() {
        let request = RewriteRequest(
            sessionId: UUID(),
            locale: "en",
            transcript: TranscriptPayload(text: "uh hello world"),
            context: "",
            processingLevel: .light
        )

        let prompt = GeminiPromptBuilder.build(for: request)

        XCTAssertTrue(prompt.systemInstruction.contains("light cleanup"))
        XCTAssertTrue(prompt.systemInstruction.contains("remove obvious filler words"))
        XCTAssertTrue(prompt.systemInstruction.contains("Merge fragmented phrases"))
        XCTAssertTrue(prompt.systemInstruction.contains("Do not paraphrase or summarize"))
        XCTAssertTrue(prompt.systemInstruction.contains("Keep original perspective"))
    }

    func testAggressivePromptPreservesEntitiesAndIntent() {
        let request = RewriteRequest(
            sessionId: UUID(),
            locale: "en",
            transcript: TranscriptPayload(text: "Ship feature for Acme by Friday"),
            context: "Project: Vox",
            processingLevel: .aggressive
        )

        let prompt = GeminiPromptBuilder.build(for: request)

        XCTAssertTrue(prompt.systemInstruction.contains("executive editor"))
        XCTAssertTrue(prompt.systemInstruction.contains("Do not change the speech act"))
        XCTAssertTrue(prompt.systemInstruction.contains("Keep every specific noun"))
        XCTAssertTrue(prompt.userPrompt.contains("Context:"))
    }
}
