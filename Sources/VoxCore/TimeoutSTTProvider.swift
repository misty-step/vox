import Foundation

public struct TimeoutSTTProvider: STTProvider {
    private let provider: STTProvider
    private let duration: TimeInterval

    public init(provider: STTProvider, timeout duration: TimeInterval) {
        self.provider = provider
        self.duration = duration
    }

    public func transcribe(audioURL: URL) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await provider.transcribe(audioURL: audioURL)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                throw STTError.network("timed out after \(Int(duration))s")
            }
            guard let result = try await group.next() else {
                throw STTError.network("timed out after \(Int(duration))s")
            }
            group.cancelAll()
            return result
        }
    }
}
