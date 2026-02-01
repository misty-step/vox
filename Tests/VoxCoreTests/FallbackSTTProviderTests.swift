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
        let fallbackErrors: [STTError] = [.throttled, .quotaExceeded, .auth]

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
            .network("offline"),
            .invalidAudio,
            .unknown("boom"),
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
}

private final class CallbackCounter: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var count = 0

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}
