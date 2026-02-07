import Foundation

public struct ConcurrencyLimitedSTTProvider: STTProvider {
    private let provider: STTProvider
    private let semaphore: AsyncSemaphore

    public init(provider: STTProvider, maxConcurrent: Int) {
        self.provider = provider
        self.semaphore = AsyncSemaphore(maxConcurrent: max(1, maxConcurrent))
    }

    public func transcribe(audioURL: URL) async throws -> String {
        try await semaphore.wait()
        defer { semaphore.signal() }
        try Task.checkCancellation()
        return try await provider.transcribe(audioURL: audioURL)
    }
}

private final class AsyncSemaphore: @unchecked Sendable {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    private var available: Int
    private var waiters: [Waiter] = []

    init(maxConcurrent: Int) {
        self.available = maxConcurrent
    }

    func wait() async throws {
        try Task.checkCancellation()

        if withLock({
            guard available > 0 else { return false }
            available -= 1
            return true
        }) {
            return
        }

        let waiterID = UUID()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let resumeImmediately = withLock {
                    guard available > 0 else {
                        waiters.append(Waiter(id: waiterID, continuation: continuation))
                        return false
                    }
                    available -= 1
                    return true
                }

                if resumeImmediately {
                    continuation.resume(returning: ())
                    return
                }

                if Task.isCancelled {
                    cancel(waiterID: waiterID)
                }
            }
        } onCancel: {
            cancel(waiterID: waiterID)
        }
    }

    func signal() {
        let waiter: Waiter? = withLock {
            if waiters.isEmpty {
                available += 1
                return nil
            }
            return waiters.removeFirst()
        }

        waiter?.continuation.resume(returning: ())
    }

    private func cancel(waiterID: UUID) {
        let continuation: CheckedContinuation<Void, Error>? = withLock {
            guard let index = waiters.firstIndex(where: { $0.id == waiterID }) else {
                return nil
            }
            return waiters.remove(at: index).continuation
        }

        continuation?.resume(throwing: CancellationError())
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
