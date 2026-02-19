import Foundation

/// Speech-to-text provider protocol
public protocol STTProvider: Sendable {
    func transcribe(audioURL: URL) async throws -> String
}

/// Incremental transcript update from a realtime provider.
public struct PartialTranscript: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool

    public init(text: String, isFinal: Bool) {
        self.text = text
        self.isFinal = isFinal
    }
}

/// PCM audio payload pushed into streaming STT sessions.
public struct AudioChunk: Sendable, Equatable {
    public let pcm16LEData: Data
    public let sampleRate: Int
    public let channels: Int

    public init(
        pcm16LEData: Data,
        sampleRate: Int = 16_000,
        channels: Int = 1
    ) {
        self.pcm16LEData = pcm16LEData
        self.sampleRate = sampleRate
        self.channels = channels
    }
}

/// Stateful realtime STT lifecycle.
public protocol StreamingSTTSession: Sendable {
    var partialTranscripts: AsyncStream<PartialTranscript> { get }
    func sendAudioChunk(_ chunk: AudioChunk) async throws
    func finish() async throws -> String
    func cancel() async
}

/// Factory for provider-specific streaming sessions.
public protocol StreamingSTTProvider: Sendable {
    func makeSession() async throws -> any StreamingSTTSession
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

/// Provides access to an ephemeral per-recording key for encrypted temp files.
@MainActor
public protocol EncryptedAudioRecording: AudioRecording {
    /// Returns and clears the in-memory key for the current recording.
    func consumeRecordingEncryptionKey() -> Data?

    /// Clears any cached in-memory key without exposing it.
    func discardRecordingEncryptionKey()
}

extension AudioRecording {
    public func start() throws { try start(inputDeviceUID: nil) }
}

/// Recorder seam for realtime chunk forwarding.
@MainActor
public protocol AudioChunkStreaming: AudioRecording {
    func setAudioChunkHandler(_ handler: (@Sendable (AudioChunk) -> Void)?)
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

/// Reuse rewrite/paste semantics from a precomputed transcript.
public protocol TranscriptProcessing: Sendable {
    func process(transcript: String) async throws -> String
}

/// Read-only preferences abstraction for dependency injection.
@MainActor
public protocol PreferencesReading: AnyObject, Sendable {
    var processingLevel: ProcessingLevel { get }
    var selectedInputDeviceUID: String? { get }
    var elevenLabsAPIKey: String { get }
    var openRouterAPIKey: String { get }
    var deepgramAPIKey: String { get }
    var geminiAPIKey: String { get }
}
