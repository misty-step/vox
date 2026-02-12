import Foundation
import VoxCore

internal enum PhaseAwareSTTTimeoutPhase: String, Sendable, Equatable {
    case uploadStall = "upload_stall"
    case processingTimeout = "processing_timeout"
}

/// State machine for deciding which phase timed out based on upload progress.
internal struct PhaseAwareSTTTimeoutState: Sendable {
    private var lastBytesSent: Int64
    private var lastProgressAt: Duration
    private var uploadCompletedAt: Duration?

    internal init(now: Duration = .zero, bytesSent: Int64 = 0) {
        self.lastBytesSent = bytesSent
        self.lastProgressAt = now
        self.uploadCompletedAt = nil
    }

    internal mutating func poll(
        now: Duration,
        bytesSent: Int64,
        expectedBytes: Int64,
        uploadStallTimeout: Duration,
        processingTimeout: Duration
    ) -> PhaseAwareSTTTimeoutPhase? {
        if bytesSent > lastBytesSent {
            lastBytesSent = bytesSent
            lastProgressAt = now
        }

        if uploadCompletedAt == nil, expectedBytes > 0, bytesSent >= expectedBytes {
            uploadCompletedAt = now
        }

        if let uploadCompletedAt {
            if now - uploadCompletedAt > processingTimeout {
                return .processingTimeout
            }
            return nil
        }

        if now - lastProgressAt > uploadStallTimeout, bytesSent < expectedBytes {
            return .uploadStall
        }

        return nil
    }
}

internal enum BatchSTTTimeouts {
    static let uploadStallTimeoutSeconds: TimeInterval = 10

    // Keep existing size-based timeout budget, but apply it to server-side processing only.
    static let processingBaseTimeoutSeconds: TimeInterval = 30
    static let processingSecondsPerMB: TimeInterval = 2

    static func processingTimeoutSeconds(forExpectedBytes expectedBytes: Int64) -> TimeInterval {
        let sizeMB = Double(expectedBytes) / 1_048_576
        return max(processingBaseTimeoutSeconds, processingBaseTimeoutSeconds + sizeMB * processingSecondsPerMB)
    }
}

extension URLSession {
    /// Phase-aware upload for batch STT:
    /// - Upload phase: fail fast on true stalls (no progress for `uploadStallTimeoutSeconds`).
    /// - Processing phase: once upload completes, start a separate processing timeout.
    ///
    /// Important: this deliberately does NOT cap slow-but-progressing uploads; the pipeline timeout is the final guardrail.
    internal func uploadWithPhaseAwareSTTTimeout(
        for request: URLRequest,
        fromFile fileURL: URL,
        expectedBytes: Int64,
        uploadStallTimeoutSeconds: TimeInterval,
        processingTimeoutSeconds: TimeInterval,
        pollIntervalSeconds: TimeInterval = 0.25
    ) async throws -> (Data, URLResponse) {
        guard expectedBytes >= 0 else {
            throw STTError.network("timeout(internal): invalid expectedBytes=\(expectedBytes)")
        }
        guard uploadStallTimeoutSeconds > 0, uploadStallTimeoutSeconds.isFinite else {
            throw STTError.network("timeout(internal): invalid uploadStallTimeoutSeconds=\(uploadStallTimeoutSeconds)")
        }
        guard processingTimeoutSeconds > 0, processingTimeoutSeconds.isFinite else {
            throw STTError.network("timeout(internal): invalid processingTimeoutSeconds=\(processingTimeoutSeconds)")
        }
        guard pollIntervalSeconds > 0, pollIntervalSeconds.isFinite else {
            throw STTError.network("timeout(internal): invalid pollIntervalSeconds=\(pollIntervalSeconds)")
        }

        let state = UploadCompletionState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                state.setContinuation(continuation)

                if Task.isCancelled {
                    state.cancelFromCaller()
                    return
                }

                let clock = ContinuousClock()
                let startedAt = clock.now
                var timeoutState = PhaseAwareSTTTimeoutState()

                let task = uploadTask(with: request, fromFile: fileURL) { data, response, error in
                    if let error {
                        state.resumeOnce(.failure(error))
                        return
                    }
                    guard let data, let response else {
                        state.resumeOnce(.failure(URLError(.badServerResponse)))
                        return
                    }
                    state.resumeOnce(.success((data, response)))
                }
                state.setTask(task)

                let pollInterval = Duration.milliseconds(max(1, Int(pollIntervalSeconds * 1000)))
                let stallTimeout = Duration.milliseconds(max(1, Int(uploadStallTimeoutSeconds * 1000)))
                let processingTimeout = Duration.milliseconds(max(1, Int(processingTimeoutSeconds * 1000)))

                let monitor = Task { [weak task] in
                    guard let task else { return }

                    while !Task.isCancelled {
                        let bytesSent = task.countOfBytesSent
                        let elapsed = startedAt.duration(to: clock.now)
                        if let phase = timeoutState.poll(
                            now: elapsed,
                            bytesSent: bytesSent,
                            expectedBytes: expectedBytes,
                            uploadStallTimeout: stallTimeout,
                            processingTimeout: processingTimeout
                        ) {
                            let waitedMs: Int
                            switch phase {
                            case .uploadStall:
                                waitedMs = Int(uploadStallTimeoutSeconds * 1000)
                            case .processingTimeout:
                                waitedMs = Int(processingTimeoutSeconds * 1000)
                            }
                            let msg = "timeout(\(phase.rawValue)): waited=\(waitedMs)ms (sent=\(bytesSent) expected=\(expectedBytes))"
                            state.resumeOnce(.failure(STTError.network(msg)))
                            task.cancel()
                            return
                        }

                        do {
                            try await Task.sleep(for: pollInterval)
                        } catch {
                            return
                        }
                    }
                }
                state.setMonitor(monitor)

                task.resume()
            }
        } onCancel: {
            state.cancelFromCaller()
        }
    }
}

/// Thread-safe one-shot resume + cancellation plumbing for URLSession task bridging.
private final class UploadCompletionState: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    private var continuation: CheckedContinuation<(Data, URLResponse), Error>?
    private var task: URLSessionTask?
    private var monitor: Task<Void, Never>?
    private var pendingCancellation = false

    func setContinuation(_ continuation: CheckedContinuation<(Data, URLResponse), Error>) {
        lock.lock()
        self.continuation = continuation
        let shouldCancel = pendingCancellation
        lock.unlock()

        if shouldCancel {
            cancelFromCaller()
        }
    }

    func setTask(_ task: URLSessionTask) {
        lock.lock()
        self.task = task
        let shouldCancel = pendingCancellation
        lock.unlock()

        if shouldCancel {
            cancelFromCaller()
        }
    }

    func setMonitor(_ monitor: Task<Void, Never>) {
        lock.lock()
        self.monitor = monitor
        let shouldCancel = pendingCancellation
        lock.unlock()

        if shouldCancel {
            cancelFromCaller()
        }
    }

    func cancelFromCaller() {
        lock.lock()
        pendingCancellation = true
        let hasContinuation = continuation != nil
        let task = task
        let monitor = monitor
        lock.unlock()

        // If the continuation is not set yet, defer resumption until `setContinuation`.
        guard hasContinuation else {
            monitor?.cancel()
            task?.cancel()
            return
        }

        resumeOnce(.failure(CancellationError()))
        task?.cancel()
    }

    func resumeOnce(_ result: Result<(Data, URLResponse), Error>) {
        lock.lock()
        guard !resumed else { lock.unlock(); return }
        resumed = true

        let continuation = continuation
        self.continuation = nil
        let monitor = monitor
        self.monitor = nil
        let task = task
        self.task = nil
        lock.unlock()

        monitor?.cancel()
        // If we are resuming due to timeout/cancel, ensure we stop the underlying request.
        if case .failure = result {
            task?.cancel()
        }

        switch result {
        case .success(let value):
            continuation?.resume(returning: value)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }
}
