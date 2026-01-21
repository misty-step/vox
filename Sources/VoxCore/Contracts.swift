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
    public let processingLevel: ProcessingLevel

    public init(
        sessionId: UUID,
        locale: String,
        transcript: TranscriptPayload,
        context: String,
        processingLevel: ProcessingLevel = .light
    ) {
        self.sessionId = sessionId
        self.locale = locale
        self.transcript = transcript
        self.context = context
        self.processingLevel = processingLevel
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId
        case locale
        case transcript
        case context
        case processingLevel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sessionId = try container.decode(UUID.self, forKey: .sessionId)
        let locale = try container.decode(String.self, forKey: .locale)
        let transcript = try container.decode(TranscriptPayload.self, forKey: .transcript)
        let context = try container.decode(String.self, forKey: .context)
        let processingLevel = try container.decodeIfPresent(ProcessingLevel.self, forKey: .processingLevel) ?? .light
        self.init(
            sessionId: sessionId,
            locale: locale,
            transcript: transcript,
            context: context,
            processingLevel: processingLevel
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(locale, forKey: .locale)
        try container.encode(transcript, forKey: .transcript)
        try container.encode(context, forKey: .context)
        try container.encode(processingLevel, forKey: .processingLevel)
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
