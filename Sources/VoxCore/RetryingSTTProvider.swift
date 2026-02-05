import Foundation

public struct RetryingSTTProvider: STTProvider {
    private let provider: STTProvider
    private let maxRetries: Int
    private let baseDelay: TimeInterval
    private let name: String
    private let onRetry: (@Sendable (_ attempt: Int, _ maxRetries: Int, _ delay: TimeInterval) -> Void)?

    public init(
        provider: STTProvider,
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 0.5,
        name: String = "STT",
        onRetry: (@Sendable (_ attempt: Int, _ maxRetries: Int, _ delay: TimeInterval) -> Void)? = nil
    ) {
        self.provider = provider
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.name = name
        self.onRetry = onRetry
    }

    public func transcribe(audioURL: URL) async throws -> String {
        var attempt = 0
        while true {
            do {
                return try await provider.transcribe(audioURL: audioURL)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let sttError = (error as? STTError) ?? .network(error.localizedDescription)

                if !sttError.isRetryable || attempt >= maxRetries {
                    if attempt > 0 {
                        print("[STT] \(name): failed after \(attempt) retries — \(sttError.localizedDescription)")
                    }
                    throw sttError
                }

                attempt += 1
                let jitter = Double.random(in: 0...baseDelay)
                let delay = baseDelay * pow(2.0, Double(attempt - 1)) + jitter
                print("[STT] \(name): retry \(attempt)/\(maxRetries) — \(sttError.localizedDescription)")
                onRetry?(attempt, maxRetries, delay)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
}
