import Foundation

public struct TimeoutSTTProvider: STTProvider {
    private let provider: STTProvider
    private let computeTimeout: @Sendable (URL) -> TimeInterval

    /// Fixed timeout — use for tests or when file size doesn't matter.
    public init(provider: STTProvider, timeout duration: TimeInterval) {
        self.provider = provider
        self.computeTimeout = { _ in duration }
    }

    /// Dynamic timeout that scales with file size.
    /// Timeout = max(baseTimeout, baseTimeout + fileSizeMB * secondsPerMB)
    public init(provider: STTProvider, baseTimeout: TimeInterval, secondsPerMB: TimeInterval) {
        self.provider = provider
        self.computeTimeout = { url in
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            let sizeMB = Double(fileSize) / 1_048_576
            return max(baseTimeout, baseTimeout + sizeMB * secondsPerMB)
        }
    }

    public func transcribe(audioURL: URL) async throws -> String {
        let duration = computeTimeout(audioURL)
        return try await withThrowingTaskGroup(of: String.self) { group in
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
