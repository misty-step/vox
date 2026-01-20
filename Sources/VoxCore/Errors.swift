import Foundation

public enum STTError: Error, Sendable, Equatable {
    case auth
    case quotaExceeded
    case throttled
    case sessionLimit
    case invalidAudio
    case network(String)
    case unknown(String)
}

public enum RewriteError: Error, Sendable, Equatable {
    case auth
    case quotaExceeded
    case throttled
    case invalidRequest(String)
    case network(String)
    case timeout
    case unknown(String)
}

public enum VoxError: Error, Sendable, Equatable {
    case permissionDenied(String)
    case noFocusedElement
    case noTranscript
    case insertionFailed
    case provider(String)
    case internalError(String)
}
