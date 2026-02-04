import Foundation

public enum STTError: Error, Sendable, Equatable, LocalizedError {
    case auth
    case quotaExceeded
    case throttled
    case sessionLimit
    case invalidAudio
    case network(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .auth:
            return "ElevenLabs authentication failed. Check your API key."
        case .quotaExceeded:
            return "ElevenLabs quota exceeded."
        case .throttled:
            return "ElevenLabs rate limited. Try again shortly."
        case .sessionLimit:
            return "ElevenLabs session limit reached."
        case .invalidAudio:
            return "Invalid audio format."
        case .network(let msg):
            return "Network error: \(msg)"
        case .unknown(let msg):
            return "STT error: \(msg)"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .throttled, .network:
            return true
        default:
            return false
        }
    }

    public var isFallbackEligible: Bool {
        switch self {
        case .invalidAudio:
            return false
        default:
            return true
        }
    }
}

public enum RewriteError: Error, Sendable, Equatable, LocalizedError {
    case auth
    case quotaExceeded
    case throttled
    case invalidRequest(String)
    case network(String)
    case timeout
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .auth:
            return "OpenRouter authentication failed. Check your API key."
        case .quotaExceeded:
            return "OpenRouter quota exceeded."
        case .throttled:
            return "OpenRouter rate limited. Try again shortly."
        case .invalidRequest(let msg):
            return "Invalid request: \(msg)"
        case .network(let msg):
            return "Network error: \(msg)"
        case .timeout:
            return "Request timed out."
        case .unknown(let msg):
            return "Rewrite error: \(msg)"
        }
    }
}

public enum VoxError: Error, Sendable, Equatable, LocalizedError {
    case permissionDenied(String)
    case noFocusedElement
    case noTranscript
    case insertionFailed
    case provider(String)
    case internalError(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let msg):
            return msg
        case .noFocusedElement:
            return "No text field focused."
        case .noTranscript:
            return "No transcript returned."
        case .insertionFailed:
            return "Failed to insert text."
        case .provider(let msg):
            return msg
        case .internalError(let msg):
            return msg
        }
    }
}
