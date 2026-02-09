import Foundation
import XCTest
@testable import VoxCore

final class ConcurrencyLimitedSTTProviderTests: XCTestCase {
    private let audioURL = URL(fileURLWithPath: "/tmp/audio.wav")

    func test_transcribe_blocksUntilPermitIsReleased() async throws {
        let gate = GateSTTProvider()
        let provider = ConcurrencyLimitedSTTProvider(provider: gate, maxConcurrent: 1)

        let firstTask = Task { try await provider.transcribe(audioURL: audioURL) }
        try await waitUntil { gate.pendingWaiterCount == 1 }
        XCTAssertEqual(gate.callCount, 1)

        let secondTask = Task { try await provider.transcribe(audioURL: audioURL) }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(gate.callCount, 1)

        gate.resumeNext(with: .success("first"))
        let firstResult = try await firstTask.value
        XCTAssertEqual(firstResult, "first")

        try await waitUntil { gate.callCount == 2 && gate.pendingWaiterCount == 1 }
        gate.resumeNext(with: .success("second"))
        let secondResult = try await secondTask.value
        XCTAssertEqual(secondResult, "second")
        XCTAssertEqual(gate.maxInFlight, 1)
    }

    func test_transcribe_releasesPermitWhenWrappedProviderThrows() async throws {
        let base = MockSTTProvider(results: [.failure(STTError.throttled), .success("ok")])
        let provider = ConcurrencyLimitedSTTProvider(provider: base, maxConcurrent: 1)

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected throttled error")
        } catch let error as STTError {
            XCTAssertEqual(error, .throttled)
        } catch {
            XCTFail("Expected STTError, got \(error)")
        }

        let second = try await provider.transcribe(audioURL: audioURL)
        XCTAssertEqual(second, "ok")
        XCTAssertEqual(base.callCount, 2)
    }

    func test_transcribe_waitingCancellation_doesNotLeakPermit() async throws {
        let gate = GateSTTProvider()
        let provider = ConcurrencyLimitedSTTProvider(provider: gate, maxConcurrent: 1)

        let firstTask = Task { try await provider.transcribe(audioURL: audioURL) }
        try await waitUntil { gate.pendingWaiterCount == 1 }
        XCTAssertEqual(gate.callCount, 1)

        let cancelledTask = Task { try await provider.transcribe(audioURL: audioURL) }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(gate.callCount, 1)

        cancelledTask.cancel()
        do {
            _ = try await cancelledTask.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        gate.resumeNext(with: .success("first"))
        let firstResult = try await firstTask.value
        XCTAssertEqual(firstResult, "first")

        let thirdTask = Task { try await provider.transcribe(audioURL: audioURL) }
        try await waitUntil { gate.callCount == 2 && gate.pendingWaiterCount == 1 }
        gate.resumeNext(with: .success("third"))
        let thirdResult = try await thirdTask.value
        XCTAssertEqual(thirdResult, "third")
        XCTAssertEqual(gate.maxInFlight, 1)
    }

    func test_transcribe_sharesLimitAcrossProviderInstances() async throws {
        let firstBase = GateSTTProvider()
        let secondBase = GateSTTProvider()
        let first = ConcurrencyLimitedSTTProvider(provider: firstBase, maxConcurrent: 1)
        let second = ConcurrencyLimitedSTTProvider(provider: secondBase, maxConcurrent: 1)

        let firstTask = Task { try await first.transcribe(audioURL: audioURL) }
        try await waitUntil { firstBase.pendingWaiterCount == 1 }
        XCTAssertEqual(firstBase.callCount, 1)

        let secondTask = Task { try await second.transcribe(audioURL: audioURL) }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(secondBase.callCount, 0)

        firstBase.resumeNext(with: .success("first"))
        let firstResult = try await firstTask.value
        XCTAssertEqual(firstResult, "first")

        try await waitUntil { secondBase.callCount == 1 && secondBase.pendingWaiterCount == 1 }
        secondBase.resumeNext(with: .success("second"))
        let secondResult = try await secondTask.value
        XCTAssertEqual(secondResult, "second")
        XCTAssertEqual(firstBase.maxInFlight, 1)
        XCTAssertEqual(secondBase.maxInFlight, 1)
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for condition")
        throw NSError(domain: "ConcurrencyLimitedSTTProviderTests", code: 1)
    }
}

private final class GateSTTProvider: STTProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var waiters: [CheckedContinuation<String, Error>] = []
    private var _callCount = 0
    private var _inFlight = 0
    private var _maxInFlight = 0

    var callCount: Int {
        withLock { _callCount }
    }

    var maxInFlight: Int {
        withLock { _maxInFlight }
    }

    var pendingWaiterCount: Int {
        withLock { waiters.count }
    }

    func transcribe(audioURL: URL) async throws -> String {
        withLock {
            _callCount += 1
            _inFlight += 1
            _maxInFlight = max(_maxInFlight, _inFlight)
        }

        defer {
            withLock { _inFlight -= 1 }
        }

        return try await withCheckedThrowingContinuation { continuation in
            withLock { waiters.append(continuation) }
        }
    }

    func resumeNext(with result: Result<String, Error>) {
        let continuation: CheckedContinuation<String, Error>? = withLock {
            if waiters.isEmpty {
                return nil
            }
            return waiters.removeFirst()
        }

        guard let continuation else { return }
        switch result {
        case .success(let text):
            continuation.resume(returning: text)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
