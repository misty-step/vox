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
    @MainActor func paste(text: String) async throws
}

/// Audio recording abstraction
@MainActor
public protocol AudioRecording: AnyObject {
    func start(inputDeviceUID: String?) throws
    func currentLevel() -> (average: Float, peak: Float)
    func stop() throws -> URL
}

extension AudioRecording {
    public func start() throws { try start(inputDeviceUID: nil) }
}

/// HUD display abstraction
@MainActor
public protocol HUDDisplaying: AnyObject {
    func showRecording(average: Float, peak: Float)
    func updateLevels(average: Float, peak: Float)
    func showProcessing(message: String)
    func showSuccess()
    func hide()
}

extension HUDDisplaying {
    public func showProcessing() { showProcessing(message: "Transcribing") }
    public func showSuccess() { hide() }
}

/// Dictation processing abstraction.
/// Implementations must be safe for repeated calls across recording sessions.
public protocol DictationProcessing: Sendable {
    func process(audioURL: URL) async throws -> String
}

/// Read-only preferences abstraction for dependency injection.
@MainActor
public protocol PreferencesReading: AnyObject, Sendable {
    var processingLevel: ProcessingLevel { get }
    var selectedInputDeviceUID: String? { get }
    var elevenLabsAPIKey: String { get }
    var openRouterAPIKey: String { get }
    var deepgramAPIKey: String { get }
    var openAIAPIKey: String { get }
}
