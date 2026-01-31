import Foundation

public struct RetryingSTTProvider: STTProvider {
    private let provider: STTProvider
    private let maxRetries: Int
    private let baseDelay: TimeInterval
    private let onRetry: (@Sendable (_ attempt: Int, _ maxRetries: Int, _ delay: TimeInterval) -> Void)?

    public init(
        provider: STTProvider,
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 0.5,
        onRetry: (@Sendable (_ attempt: Int, _ maxRetries: Int, _ delay: TimeInterval) -> Void)? = nil
    ) {
        self.provider = provider
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.onRetry = onRetry
    }

    public func transcribe(audioURL: URL) async throws -> String {
        var attempt = 0
        while true {
            do {
                return try await provider.transcribe(audioURL: audioURL)
            } catch let error as STTError {
                guard error == .throttled, attempt < maxRetries else { throw error }
                attempt += 1
                let jitter = Double.random(in: 0...baseDelay)
                let delay = baseDelay * pow(2.0, Double(attempt - 1)) + jitter
                let currentAttempt = attempt  // Capture for Sendable closure
                onRetry?(currentAttempt, maxRetries, delay)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
}
