import Foundation
import VoxCore

struct GeminiPrompt {
    let systemInstruction: String
    let userPrompt: String
}

enum GeminiPromptBuilder {
    static func build(for request: RewriteRequest) -> GeminiPrompt {
        let systemInstruction: String
        switch request.processingLevel {
        case .light:
            systemInstruction = """
            You are a precise transcript cleaner. Perform light cleanup only.
            Fix punctuation, capitalization, and sentence breaks. Preserve wording, order, and tone.
            You may remove obvious filler words and stutters when they add no meaning. Do not remove hedge words.
            Do not paraphrase or summarize.
            Keep original perspective and tense.
            Keep all numbers, names, acronyms, code, and file paths verbatim.
            Output only the cleaned transcript with no commentary.
            """
        case .aggressive:
            systemInstruction = """
            You are an executive editor. Elevate the transcript into concise, high-impact writing for directing a coding agent or LLM.
            Preserve meaning and intent. Do not add facts.
            Do not change the speech act: statements stay statements, questions stay questions, commands stay commands.
            Keep the original perspective and modality (I/we/you, can/could/should/might).
            Keep every specific noun, name, number, requirement, and constraint. Do not drop any.
            You may reorder for clarity and remove filler words.
            If unsure about a phrase, keep the original wording.
            Output only the rewritten text with no commentary.
            """
        case .off:
            systemInstruction = """
            You are an expert editor. Rewrite the transcript into clear, articulate text while preserving meaning.
            Do not add new facts. Do not invent details. Keep it faithful.
            Output only the rewritten text with no commentary.
            """
        }

        var prompt = "Transcript:\n<<<\n\(request.transcript.text)\n>>>\n"
        if !request.context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt.append("\nContext:\n<<<\n\(request.context)\n>>>\n")
        }
        prompt.append("\nRewrite now.")

        return GeminiPrompt(systemInstruction: systemInstruction, userPrompt: prompt)
    }
}
