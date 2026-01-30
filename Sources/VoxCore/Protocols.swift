import Foundation

/// Speech-to-text provider protocol
public protocol STTProvider: Sendable {
    func transcribe(audioURL: URL) async throws -> String
}

/// Text rewriting/processing provider protocol
public protocol RewriteProvider: Sendable {
    func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String
}

/// Text pasting abstraction (already exists as ClipboardPaster, extract protocol)
public protocol TextPaster: Sendable {
    @MainActor func paste(text: String) throws
}
