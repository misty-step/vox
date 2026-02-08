import XCTest
@testable import VoxCore

final class STTErrorTests: XCTestCase {
    func test_isRetryable() {
        XCTAssertTrue(STTError.throttled.isRetryable)
        XCTAssertTrue(STTError.network("timeout").isRetryable)

        XCTAssertFalse(STTError.auth.isRetryable)
        XCTAssertFalse(STTError.quotaExceeded.isRetryable)
        XCTAssertFalse(STTError.sessionLimit.isRetryable)
        XCTAssertFalse(STTError.invalidAudio.isRetryable)
        XCTAssertFalse(STTError.unknown("?").isRetryable)
    }

    func test_isFallbackEligible() {
        XCTAssertTrue(STTError.auth.isFallbackEligible)
        XCTAssertTrue(STTError.quotaExceeded.isFallbackEligible)
        XCTAssertTrue(STTError.throttled.isFallbackEligible)
        XCTAssertTrue(STTError.sessionLimit.isFallbackEligible)
        XCTAssertTrue(STTError.network("offline").isFallbackEligible)
        XCTAssertTrue(STTError.unknown("?").isFallbackEligible)

        XCTAssertFalse(STTError.invalidAudio.isFallbackEligible)
    }

    func test_isTransientForHealthScoring() {
        XCTAssertTrue(STTError.throttled.isTransientForHealthScoring)
        XCTAssertTrue(STTError.network("offline").isTransientForHealthScoring)
        XCTAssertTrue(STTError.unknown("oops").isTransientForHealthScoring)

        XCTAssertFalse(STTError.auth.isTransientForHealthScoring)
        XCTAssertFalse(STTError.quotaExceeded.isTransientForHealthScoring)
        XCTAssertFalse(STTError.sessionLimit.isTransientForHealthScoring)
        XCTAssertFalse(STTError.invalidAudio.isTransientForHealthScoring)
    }

    // MARK: - Error Description Tests

    func test_errorDescription() {
        XCTAssertEqual(STTError.auth.errorDescription, "Authentication failed. Check your API key.")
        XCTAssertEqual(STTError.quotaExceeded.errorDescription, "API quota exceeded.")
        XCTAssertEqual(STTError.throttled.errorDescription, "Rate limited. Try again shortly.")
        XCTAssertEqual(STTError.sessionLimit.errorDescription, "Session limit reached.")
        XCTAssertEqual(STTError.invalidAudio.errorDescription, "Invalid audio format.")
        XCTAssertEqual(STTError.network("timeout").errorDescription, "Network error: timeout")
        XCTAssertEqual(STTError.unknown("something").errorDescription, "STT error: something")
    }

    // MARK: - Equatable Tests

    func test_equatable() {
        XCTAssertEqual(STTError.auth, STTError.auth)
        XCTAssertEqual(STTError.throttled, STTError.throttled)
        XCTAssertEqual(STTError.network("timeout"), STTError.network("timeout"))

        XCTAssertNotEqual(STTError.auth, STTError.throttled)
        XCTAssertNotEqual(STTError.network("timeout"), STTError.network("offline"))
    }
}
