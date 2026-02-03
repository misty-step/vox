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

public protocol AudioRecording: AnyObject {
    func start() throws
    func currentLevel() -> (average: Float, peak: Float)
    func stop() throws -> URL
}

public protocol DictationProcessing: Sendable {
    func process(audioURL: URL) async throws -> String
}

public protocol HUDDisplaying: AnyObject {
    @MainActor func showRecording(average: Float, peak: Float)
    @MainActor func updateLevels(average: Float, peak: Float)
    @MainActor func showProcessing(message: String)
    @MainActor func hide()
}
