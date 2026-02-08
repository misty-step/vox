import Foundation
import XCTest
@testable import VoxCore

final class HedgedSTTProviderTests: XCTestCase {
    private let audioURL = URL(fileURLWithPath: "/tmp/audio.wav")

    func test_transcribe_returnsFirstSuccessfulResult() async throws {
        let slowCancelled = expectation(description: "slow provider cancelled")
        let slow = ScriptedHedgeProvider(
            delay: 0.25,
            result: .success("slow"),
            onCancel: { slowCancelled.fulfill() }
        )
        let fast = ScriptedHedgeProvider(delay: 0.01, result: .success("fast"))
        let provider = HedgedSTTProvider(entries: [
            .init(name: "slow", provider: slow, delay: 0),
            .init(name: "fast", provider: fast, delay: 0),
        ])

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "fast")
        XCTAssertEqual(fast.callCount, 1)
        XCTAssertEqual(slow.callCount, 1)
        await fulfillment(of: [slowCancelled], timeout: 1.0)
    }

    func test_transcribe_skipsDelayedProviderWhenEarlierWinnerCompletes() async throws {
        let winner = ScriptedHedgeProvider(delay: 0.01, result: .success("winner"))
        let delayed = ScriptedHedgeProvider(delay: 0, result: .success("delayed"))
        let provider = HedgedSTTProvider(entries: [
            .init(name: "winner", provider: winner, delay: 0),
            .init(name: "delayed", provider: delayed, delay: 0.2),
        ])

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "winner")
        XCTAssertEqual(winner.callCount, 1)
        XCTAssertEqual(delayed.callCount, 0)
    }

    func test_transcribe_failsFastOnNonFallbackEligibleError() async {
        let invalid = ScriptedHedgeProvider(delay: 0, result: .failure(STTError.invalidAudio))
        let delayed = ScriptedHedgeProvider(delay: 0, result: .success("should-not-run"))
        let provider = HedgedSTTProvider(entries: [
            .init(name: "invalid", provider: invalid, delay: 0),
            .init(name: "delayed", provider: delayed, delay: 0.2),
        ])

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected invalidAudio error")
        } catch let error as STTError {
            XCTAssertEqual(error, .invalidAudio)
        } catch {
            XCTFail("Expected STTError.invalidAudio, got \(error)")
        }
        XCTAssertEqual(delayed.callCount, 0)
    }

    func test_transcribe_allFallbackEligibleFailures_throwLastError() async {
        let first = ScriptedHedgeProvider(delay: 0, result: .failure(STTError.throttled))
        let second = ScriptedHedgeProvider(delay: 0, result: .failure(STTError.unknown("still down")))
        let provider = HedgedSTTProvider(entries: [
            .init(name: "first", provider: first, delay: 0),
            .init(name: "second", provider: second, delay: 0.05),
        ])

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected fallback-eligible error")
        } catch let error as STTError {
            XCTAssertEqual(error, .unknown("still down"))
        } catch {
            XCTFail("Expected STTError, got \(error)")
        }
    }

    func test_transcribe_propagatesCancellation() async {
        let slow = ScriptedHedgeProvider(delay: 1.0, result: .success("done"))
        let provider = HedgedSTTProvider(entries: [
            .init(name: "slow", provider: slow, delay: 0),
        ])

        let task = Task {
            try await provider.transcribe(audioURL: audioURL)
        }

        try? await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
}

private final class ScriptedHedgeProvider: STTProvider, @unchecked Sendable {
    private let lock = NSLock()
    private let delay: TimeInterval
    private let result: Result<String, Error>
    private let onStart: (@Sendable () -> Void)?
    private let onCancel: (@Sendable () -> Void)?
    private var _callCount = 0

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }

    init(
        delay: TimeInterval,
        result: Result<String, Error>,
        onStart: (@Sendable () -> Void)? = nil,
        onCancel: (@Sendable () -> Void)? = nil
    ) {
        self.delay = delay
        self.result = result
        self.onStart = onStart
        self.onCancel = onCancel
    }

    func transcribe(audioURL _: URL) async throws -> String {
        incrementCallCount()

        onStart?()

        if delay > 0 {
            do {
                try await Task.sleep(nanoseconds: nanoseconds(from: delay))
            } catch is CancellationError {
                onCancel?()
                throw CancellationError()
            }
        }

        switch result {
        case .success(let transcript):
            return transcript
        case .failure(let error):
            throw error
        }
    }

    private func nanoseconds(from duration: TimeInterval) -> UInt64 {
        let nanoseconds = max(0, duration) * 1_000_000_000
        if nanoseconds >= Double(UInt64.max) {
            return UInt64.max
        }
        return UInt64(nanoseconds.rounded())
    }

    private func incrementCallCount() {
        lock.lock()
        _callCount += 1
        lock.unlock()
    }
}
