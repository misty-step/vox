import Foundation

public struct FallbackSTTProvider: STTProvider {
    private let primary: STTProvider
    private let fallback: STTProvider
    private let primaryName: String
    private let onFallback: (@Sendable () -> Void)?

    public init(
        primary: STTProvider,
        fallback: STTProvider,
        primaryName: String = "primary",
        onFallback: (@Sendable () -> Void)? = nil
    ) {
        self.primary = primary
        self.fallback = fallback
        self.primaryName = primaryName
        self.onFallback = onFallback
    }

    public func transcribe(audioURL: URL) async throws -> String {
        do {
            return try await primary.transcribe(audioURL: audioURL)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let sttError = error as? STTError, !sttError.isFallbackEligible {
                throw sttError
            }
            print("[STT] \(primaryName) failed: \(error.localizedDescription) — falling back")
            await MainActor.run { onFallback?() }
            return try await fallback.transcribe(audioURL: audioURL)
        }
    }
}
