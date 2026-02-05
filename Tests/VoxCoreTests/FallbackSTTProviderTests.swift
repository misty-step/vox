import Foundation
import XCTest
@testable import VoxCore

final class FallbackSTTProviderTests: XCTestCase {
    private let audioURL = URL(fileURLWithPath: "/tmp/audio.wav")

    func test_transcribe_successOnPrimary_noFallback() async throws {
        let primary = MockSTTProvider(results: [.success("primary")])
        let fallback = MockSTTProvider(results: [.success("fallback")])
        let counter = CallbackCounter()
        let provider = FallbackSTTProvider(
            primary: primary,
            fallback: fallback,
            onFallback: { counter.increment() }
        )

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "primary")
        XCTAssertEqual(primary.callCount, 1)
        XCTAssertEqual(fallback.callCount, 0)
        XCTAssertEqual(counter.count, 0)
    }

    func test_transcribe_fallsBackOnSpecificErrors() async throws {
        let fallbackErrors: [STTError] = [
            .throttled,
            .quotaExceeded,
            .auth,
            .network("offline"),
            .unknown("boom"),
            .sessionLimit,
        ]

        for error in fallbackErrors {
            let primary = MockSTTProvider(results: [.failure(error)])
            let fallback = MockSTTProvider(results: [.success("fallback")])
            let counter = CallbackCounter()
            let provider = FallbackSTTProvider(
                primary: primary,
                fallback: fallback,
                onFallback: { counter.increment() }
            )

            let result = try await provider.transcribe(audioURL: audioURL)

            XCTAssertEqual(result, "fallback", "Failed for error: \(error)")
            XCTAssertEqual(primary.callCount, 1, "Failed for error: \(error)")
            XCTAssertEqual(fallback.callCount, 1, "Failed for error: \(error)")
            XCTAssertEqual(counter.count, 1, "Failed for error: \(error)")
        }
    }

    func test_transcribe_noFallbackOnNonFallbackErrors() async {
        let errors: [STTError] = [
            .invalidAudio,
        ]

        for error in errors {
            let primary = MockSTTProvider(results: [.failure(error)])
            let fallback = MockSTTProvider(results: [.success("fallback")])
            let counter = CallbackCounter()
            let provider = FallbackSTTProvider(
                primary: primary,
                fallback: fallback,
                onFallback: { counter.increment() }
            )

            do {
                _ = try await provider.transcribe(audioURL: audioURL)
                XCTFail("Expected error to be thrown")
            } catch let thrown {
                XCTAssertEqual(thrown as? STTError, error)
            }
            XCTAssertEqual(primary.callCount, 1)
            XCTAssertEqual(fallback.callCount, 0)
            XCTAssertEqual(counter.count, 0)
        }
    }

    func test_transcribe_fallsBackOnNonSTTError() async throws {
        let urlError = URLError(.notConnectedToInternet)
        let primary = MockSTTProvider(results: [.failure(urlError)])
        let fallback = MockSTTProvider(results: [.success("fallback")])
        let counter = CallbackCounter()
        let provider = FallbackSTTProvider(
            primary: primary,
            fallback: fallback,
            onFallback: { counter.increment() }
        )

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "fallback")
        XCTAssertEqual(counter.count, 1)
    }

    func test_transcribe_bothFailPropagatesError() async {
        let primary = MockSTTProvider(results: [.failure(STTError.network("down"))])
        let fallback = MockSTTProvider(results: [.failure(STTError.unknown("also down"))])
        let provider = FallbackSTTProvider(primary: primary, fallback: fallback)

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected error")
        } catch let error as STTError {
            XCTAssertEqual(error, .unknown("also down"))
        } catch {
            XCTFail("Expected STTError, got \(error)")
        }
    }

    func test_transcribe_onFallbackCallback_isCalled() async throws {
        let primary = MockSTTProvider(results: [.failure(STTError.throttled)])
        let fallback = MockSTTProvider(results: [.success("fallback")])
        let counter = CallbackCounter()
        let provider = FallbackSTTProvider(
            primary: primary,
            fallback: fallback,
            onFallback: { counter.increment() }
        )

        _ = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(counter.count, 1)
    }

    // MARK: - Additional Edge Cases

    func test_transcribe_cancellationPropagatesImmediately() async {
        let primary = MockSTTProvider(results: [.failure(CancellationError())])
        let fallback = MockSTTProvider(results: [.success("fallback")])
        let provider = FallbackSTTProvider(primary: primary, fallback: fallback)

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
        XCTAssertEqual(primary.callCount, 1)
        XCTAssertEqual(fallback.callCount, 0)
    }

    func test_transcribe_primaryNameLoggedOnFallback() async throws {
        let primary = MockSTTProvider(results: [.failure(STTError.network("timeout"))])
        let fallback = MockSTTProvider(results: [.success("fallback")])
        let provider = FallbackSTTProvider(
            primary: primary,
            fallback: fallback,
            primaryName: "ElevenLabs"
        )

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "fallback")
        XCTAssertEqual(primary.callCount, 1)
        XCTAssertEqual(fallback.callCount, 1)
    }

    func test_transcribe_multipleFallbackEligibleErrors_allTriggerFallback() async throws {
        let errors: [STTError] = [
            .auth,
            .quotaExceeded,
            .throttled,
            .sessionLimit,
            .network("any network"),
            .unknown("any unknown"),
        ]

        for error in errors {
            let primary = MockSTTProvider(results: [.failure(error)])
            let fallback = MockSTTProvider(results: [.success("fallback")])
            let provider = FallbackSTTProvider(primary: primary, fallback: fallback)

            let result = try await provider.transcribe(audioURL: audioURL)

            XCTAssertEqual(result, "fallback", "Failed for error: \(error)")
        }
    }

    func test_transcribe_nestedNSError_fallsBack() async throws {
        let nsError = NSError(domain: "NSURLErrorDomain", code: -1009, userInfo: [
            NSLocalizedDescriptionKey: "The Internet connection appears to be offline."
        ])
        let primary = MockSTTProvider(results: [.failure(nsError)])
        let fallback = MockSTTProvider(results: [.success("fallback")])
        let provider = FallbackSTTProvider(primary: primary, fallback: fallback)

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "fallback")
    }

    func test_transcribe_fallbackAlsoFailsWithCancellation() async {
        let primary = MockSTTProvider(results: [.failure(STTError.throttled)])
        let fallback = MockSTTProvider(results: [.failure(CancellationError())])
        let provider = FallbackSTTProvider(primary: primary, fallback: fallback)

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func test_transcribe_fallbackFailsWithNonFallbackEligibleError() async {
        let primary = MockSTTProvider(results: [.failure(STTError.throttled)])
        let fallback = MockSTTProvider(results: [.failure(STTError.invalidAudio)])
        let provider = FallbackSTTProvider(primary: primary, fallback: fallback)

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected error")
        } catch let error as STTError {
            XCTAssertEqual(error, .invalidAudio)
        } catch {
            XCTFail("Expected STTError, got \(error)")
        }
    }
}

private final class CallbackCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }

    func increment() {
        lock.lock()
        _count += 1
        lock.unlock()
    }
}
