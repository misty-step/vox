import Testing
import VoxCore
@testable import VoxProviders

@Suite("RewritePrompts")
struct RewritePromptsTests {
    @Test("Clean prompt emphasizes paragraph formatting")
    func cleanPromptFormattingGuidance() {
        let prompt = RewritePrompts.prompt(for: .clean)

        #expect(prompt.contains("Be proactive about formatting for readability"))
        #expect(prompt.contains("split into multiple short paragraphs"))
        #expect(prompt.contains("Separate paragraphs with a single blank line"))
        #expect(prompt.contains("Output only the cleaned text with paragraph breaks preserved"))
    }

    @Test("Clean prompt transcript context includes ASR sizing and formatting guidance")
    func cleanPromptTranscriptContext() {
        let transcript = "this is a test transcript"
        let prompt = RewritePrompts.prompt(for: .clean, transcript: transcript)

        #expect(prompt.contains("ASR CONTEXT (signal only):"))
        #expect(prompt.contains("Transcript size: 25 chars, ~5 words."))
        #expect(prompt.contains("Prioritize sentence boundaries and paragraph breaks for readability"))
    }
}
