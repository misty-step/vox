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
