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
}
