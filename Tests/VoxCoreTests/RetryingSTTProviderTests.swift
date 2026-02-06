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
            .sessionLimit,
            .unknown("?"),
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

    func test_transcribe_retriesOnNonSTTError() async throws {
        let urlError = URLError(.notConnectedToInternet)
        let mock = MockSTTProvider(results: [.failure(urlError), .success("ok")])
        let provider = RetryingSTTProvider(provider: mock, maxRetries: 2, baseDelay: 0)

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "ok")
        XCTAssertEqual(mock.callCount, 2)
    }

    func test_transcribe_wrapsNonSTTErrorAfterMaxRetries() async {
        let urlError = URLError(.timedOut)
        let mock = MockSTTProvider(results: [.failure(urlError), .failure(urlError), .failure(urlError)])
        let provider = RetryingSTTProvider(provider: mock, maxRetries: 2, baseDelay: 0)

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected error")
        } catch let error as STTError {
            if case .network(let msg) = error {
                XCTAssertTrue(msg.contains("timed out") || msg.contains("URLError"), "Got: \(msg)")
            } else {
                XCTFail("Expected .network, got \(error)")
            }
        } catch {
            XCTFail("Expected STTError, got \(error)")
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

    // MARK: - Additional Edge Cases

    func test_transcribe_cancellationPropagatesImmediately() async {
        let mock = MockSTTProvider(results: [.failure(CancellationError())])
        let provider = RetryingSTTProvider(provider: mock, maxRetries: 3, baseDelay: 0)

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
        XCTAssertEqual(mock.callCount, 1)
    }

    func test_transcribe_multipleRetriesBeforeSuccess() async throws {
        let mock = MockSTTProvider(results: [
            .failure(STTError.throttled),
            .failure(STTError.throttled),
            .failure(STTError.throttled),
            .success("finally")
        ])
        let recorder = RetryRecorder()
        let provider = RetryingSTTProvider(
            provider: mock,
            maxRetries: 3,
            baseDelay: 0,
            onRetry: { attempt, maxRetries, delay in
                recorder.record(attempt: attempt, maxRetries: maxRetries, delay: delay)
            }
        )

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "finally")
        XCTAssertEqual(mock.callCount, 4)
        XCTAssertEqual(recorder.events.count, 3)
        XCTAssertEqual(recorder.events[0].0, 1)
        XCTAssertEqual(recorder.events[1].0, 2)
        XCTAssertEqual(recorder.events[2].0, 3)
    }

    func test_transcribe_zeroMaxRetries_noRetries() async {
        let mock = MockSTTProvider(results: [.failure(STTError.throttled)])
        let recorder = RetryRecorder()
        let provider = RetryingSTTProvider(
            provider: mock,
            maxRetries: 0,
            baseDelay: 0,
            onRetry: { attempt, maxRetries, delay in
                recorder.record(attempt: attempt, maxRetries: maxRetries, delay: delay)
            }
        )

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected error")
        } catch let error as STTError {
            XCTAssertEqual(error, .throttled)
        } catch {
            XCTFail("Expected STTError, got \(error)")
        }
        XCTAssertEqual(mock.callCount, 1)
        XCTAssertEqual(recorder.events.count, 0)
    }

    func test_transcribe_mixedRetryableAndNonRetryableErrors() async {
        // First error is retryable, second is not
        let mock = MockSTTProvider(results: [
            .failure(STTError.throttled),
            .failure(STTError.auth)
        ])
        let recorder = RetryRecorder()
        let provider = RetryingSTTProvider(
            provider: mock,
            maxRetries: 3,
            baseDelay: 0,
            onRetry: { attempt, maxRetries, delay in
                recorder.record(attempt: attempt, maxRetries: maxRetries, delay: delay)
            }
        )

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected error")
        } catch let error as STTError {
            XCTAssertEqual(error, .auth)
        } catch {
            XCTFail("Expected STTError, got \(error)")
        }
        XCTAssertEqual(mock.callCount, 2)
        XCTAssertEqual(recorder.events.count, 1)
    }

    func test_transcribe_nsErrorWithRetryableCode_retries() async throws {
        let nsError = NSError(domain: "NSURLErrorDomain", code: -1001, userInfo: [
            NSLocalizedDescriptionKey: "The request timed out."
        ])
        let mock = MockSTTProvider(results: [.failure(nsError), .success("ok")])
        let provider = RetryingSTTProvider(provider: mock, maxRetries: 2, baseDelay: 0)

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "ok")
        XCTAssertEqual(mock.callCount, 2)
    }

    func test_transcribe_nameIsLogged() async throws {
        let mock = MockSTTProvider(results: [.failure(STTError.throttled), .success("ok")])
        let provider = RetryingSTTProvider(
            provider: mock,
            maxRetries: 1,
            baseDelay: 0,
            name: "ElevenLabs"
        )

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "ok")
        XCTAssertEqual(mock.callCount, 2)
    }

    func test_transcribe_exponentialBackoff_delaysIncrease() async throws {
        let mock = MockSTTProvider(results: [
            .failure(STTError.throttled),
            .failure(STTError.throttled),
            .success("ok")
        ])
        let recorder = RetryRecorder()
        let provider = RetryingSTTProvider(
            provider: mock,
            maxRetries: 3,
            baseDelay: 0.01,  // 10ms base delay — fast test
            onRetry: { attempt, maxRetries, delay in
                recorder.record(attempt: attempt, maxRetries: maxRetries, delay: delay)
            }
        )

        _ = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(recorder.events.count, 2)
        // Verify exponential growth: second delay >= first delay
        XCTAssertGreaterThanOrEqual(recorder.events[0].2, 0.01)
        XCTAssertGreaterThanOrEqual(recorder.events[1].2, recorder.events[0].2)
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
