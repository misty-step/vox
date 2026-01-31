import Foundation

public struct FallbackSTTProvider: STTProvider {
    private let primary: STTProvider
    private let fallback: STTProvider
    private let onFallback: (@Sendable () -> Void)?

    public init(
        primary: STTProvider,
        fallback: STTProvider,
        onFallback: (@Sendable () -> Void)? = nil
    ) {
        self.primary = primary
        self.fallback = fallback
        self.onFallback = onFallback
    }

    public func transcribe(audioURL: URL) async throws -> String {
        do {
            return try await primary.transcribe(audioURL: audioURL)
        } catch let error as STTError {
            switch error {
            case .throttled, .quotaExceeded, .auth:
                await MainActor.run { onFallback?() }
                return try await fallback.transcribe(audioURL: audioURL)
            default:
                throw error
            }
        }
    }
}
