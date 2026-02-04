import Foundation
import XCTest
@testable import VoxCore

final class RetryingSTTProviderTests: XCTestCase {
    private let audioURL = URL(fileURLWithPath: "/tmp/audio.wav")

    func test_transcribe_successOnFirstTry_noRetry() async throws {
        let mock = MockSTTProvider(results: [.success("ok")])
        let recorder = RetryRecorder()
        let provider = RetryingSTTProvider(
            provider: mock,
            maxRetries: 2,
            baseDelay: 0,
            onRetry: { attempt, maxRetries, delay in
                recorder.record(attempt: attempt, maxRetries: maxRetries, delay: delay)
            }
        )

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "ok")
        XCTAssertEqual(mock.callCount, 1)
        XCTAssertTrue(recorder.events.isEmpty)
    }

    func test_transcribe_retriesOnThrottledError() async throws {
        let mock = MockSTTProvider(results: [.failure(STTError.throttled), .success("ok")])
        let recorder = RetryRecorder()
        let provider = RetryingSTTProvider(
            provider: mock,
            maxRetries: 2,
            baseDelay: 0,
            onRetry: { attempt, maxRetries, delay in
                recorder.record(attempt: attempt, maxRetries: maxRetries, delay: delay)
            }
        )

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "ok")
        XCTAssertEqual(mock.callCount, 2)
        XCTAssertEqual(recorder.events.count, 1)
        if let event = recorder.events.first {
            XCTAssertEqual(event.0, 1)
            XCTAssertEqual(event.1, 2)
            XCTAssertEqual(event.2, 0, accuracy: 0.0001)
        }
    }

    func test_transcribe_retriesOnNetworkError() async throws {
        let mock = MockSTTProvider(results: [.failure(STTError.network("timeout")), .success("ok")])
        let recorder = RetryRecorder()
        let provider = RetryingSTTProvider(
            provider: mock,
            maxRetries: 2,
            baseDelay: 0,
            onRetry: { attempt, maxRetries, delay in
                recorder.record(attempt: attempt, maxRetries: maxRetries, delay: delay)
            }
        )

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "ok")
        XCTAssertEqual(mock.callCount, 2)
        XCTAssertEqual(recorder.events.count, 1)
    }

    func test_transcribe_givesUpAfterMaxRetries() async {
        let mock = MockSTTProvider(results: [.failure(STTError.throttled), .failure(STTError.throttled)])
        let provider = RetryingSTTProvider(provider: mock, maxRetries: 1, baseDelay: 0)

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? STTError, .throttled)
        }
        XCTAssertEqual(mock.callCount, 2)
    }

    func test_transcribe_noRetryOnNonThrottledErrors() async {
        let errors: [STTError] = [
            .auth,
            .invalidAudio,
            .quotaExceeded,
        ]

        for error in errors {
            let mock = MockSTTProvider(results: [.failure(error)])
            let recorder = RetryRecorder()
            let provider = RetryingSTTProvider(
                provider: mock,
                maxRetries: 2,
                baseDelay: 0,
                onRetry: { attempt, maxRetries, delay in
                    recorder.record(attempt: attempt, maxRetries: maxRetries, delay: delay)
                }
            )

            do {
                _ = try await provider.transcribe(audioURL: audioURL)
                XCTFail("Expected error to be thrown")
            } catch let thrown {
                XCTAssertEqual(thrown as? STTError, error)
            }
            XCTAssertEqual(mock.callCount, 1)
            XCTAssertTrue(recorder.events.isEmpty)
        }
    }

    func test_transcribe_onRetryCallback_receivesExpectedParams() async throws {
        let mock = MockSTTProvider(results: [.failure(STTError.throttled), .success("ok")])
        let recorder = RetryRecorder()
        let provider = RetryingSTTProvider(
            provider: mock,
            maxRetries: 3,
            baseDelay: 0,
            onRetry: { attempt, maxRetries, delay in
                recorder.record(attempt: attempt, maxRetries: maxRetries, delay: delay)
            }
        )

        _ = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(recorder.events.count, 1)
        if let event = recorder.events.first {
            XCTAssertEqual(event.0, 1)
            XCTAssertEqual(event.1, 3)
            XCTAssertEqual(event.2, 0, accuracy: 0.0001)
        }
    }
}

private final class RetryRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [(Int, Int, TimeInterval)] = []
    var events: [(Int, Int, TimeInterval)] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    func record(attempt: Int, maxRetries: Int, delay: TimeInterval) {
        lock.lock()
        _events.append((attempt, maxRetries, delay))
        lock.unlock()
    }
}
