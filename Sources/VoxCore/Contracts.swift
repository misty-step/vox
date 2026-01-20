import Foundation

public struct Transcript: Sendable, Equatable, Codable {
    public let sessionId: UUID
    public let text: String
    public let language: String?

    public init(sessionId: UUID, text: String, language: String? = nil) {
        self.sessionId = sessionId
        self.text = text
        self.language = language
    }
}

public struct TranscriptionRequest: Sendable, Equatable {
    public let sessionId: UUID
    public let audioFileURL: URL
    public let locale: String?
    public let modelId: String?

    public init(sessionId: UUID, audioFileURL: URL, locale: String?, modelId: String?) {
        self.sessionId = sessionId
        self.audioFileURL = audioFileURL
        self.locale = locale
        self.modelId = modelId
    }
}

public protocol STTProvider: Sendable {
    var id: String { get }
    func transcribe(_ request: TranscriptionRequest) async throws -> Transcript
}

public protocol RewriteProvider: Sendable {
    var id: String { get }
    func rewrite(_ request: RewriteRequest) async throws -> RewriteResponse
}

public struct RewriteRequest: Sendable, Equatable, Codable {
    public let sessionId: UUID
    public let locale: String
    public let transcript: TranscriptPayload
    public let context: String

    public init(
        sessionId: UUID,
        locale: String,
        transcript: TranscriptPayload,
        context: String
    ) {
        self.sessionId = sessionId
        self.locale = locale
        self.transcript = transcript
        self.context = context
    }
}

public struct TranscriptPayload: Sendable, Equatable, Codable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public struct RewriteResponse: Sendable, Equatable, Codable {
    public let finalText: String

    public init(finalText: String) {
        self.finalText = finalText
    }
}
