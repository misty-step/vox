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
            return "Authentication failed. Check your API key."
        case .quotaExceeded:
            return "API quota exceeded."
        case .throttled:
            return "Rate limited. Try again shortly."
        case .sessionLimit:
            return "Session limit reached."
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

    /// Health scoring semantics for provider routing.
    /// Transient failures should not permanently penalize a provider.
    public var isTransientForHealthScoring: Bool {
        guard isFallbackEligible else {
            return false
        }
        if isRetryable {
            return true
        }
        switch self {
        case .unknown:
            return true
        default:
            return false
        }
    }
}

public enum StreamingSTTError: Error, Sendable, Equatable, LocalizedError {
    case connectionFailed(String)
    case sendFailed(String)
    case receiveFailed(String)
    case provider(String)
    case finalizationTimeout
    case cancelled
    case invalidState(String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg):
            return "Streaming connection failed: \(msg)"
        case .sendFailed(let msg):
            return "Streaming send failed: \(msg)"
        case .receiveFailed(let msg):
            return "Streaming receive failed: \(msg)"
        case .provider(let msg):
            return "Streaming provider error: \(msg)"
        case .finalizationTimeout:
            return "Streaming finalize timed out."
        case .cancelled:
            return "Streaming session cancelled."
        case .invalidState(let msg):
            return "Streaming state error: \(msg)"
        }
    }

    public var isFallbackEligible: Bool {
        switch self {
        case .invalidState:
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
    case emptyCapture
    case audioCaptureFailed(String)
    case insertionFailed
    case provider(String)
    case internalError(String)
    case pipelineTimeout

    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let msg):
            return msg
        case .noFocusedElement:
            return "No text field focused."
        case .noTranscript:
            return "No transcript returned."
        case .emptyCapture:
            return "No audio captured. Check input device routing and retry."
        case .audioCaptureFailed(let msg):
            return msg
        case .insertionFailed:
            return "Failed to insert text."
        case .provider(let msg):
            return msg
        case .internalError(let msg):
            return msg
        case .pipelineTimeout:
            return "Processing timed out. Try again or check your connection."
        }
    }
}
