import Foundation
import XCTest
@testable import VoxProviders

final class BatchSTTTimeoutsTests: XCTestCase {

    func test_processingTimeoutSeconds_returnsBaseForZeroBytes() {
        let timeout = BatchSTTTimeouts.processingTimeoutSeconds(forExpectedBytes: 0)
        XCTAssertEqual(timeout, BatchSTTTimeouts.processingBaseTimeoutSeconds)
    }

    func test_processingTimeoutSeconds_scalesWithFileSize() {
        let oneMB: Int64 = 1_048_576
        let timeout = BatchSTTTimeouts.processingTimeoutSeconds(forExpectedBytes: oneMB)
        let expected = BatchSTTTimeouts.processingBaseTimeoutSeconds + BatchSTTTimeouts.processingSecondsPerMB
        XCTAssertEqual(timeout, expected, accuracy: 0.001)
    }

    func test_processingTimeoutSeconds_neverBelowBase() {
        let timeout = BatchSTTTimeouts.processingTimeoutSeconds(forExpectedBytes: 1)
        XCTAssertGreaterThanOrEqual(timeout, BatchSTTTimeouts.processingBaseTimeoutSeconds)
    }

    func test_processingTimeoutSeconds_largeFile() {
        let tenMB: Int64 = 10 * 1_048_576
        let timeout = BatchSTTTimeouts.processingTimeoutSeconds(forExpectedBytes: tenMB)
        let expected = BatchSTTTimeouts.processingBaseTimeoutSeconds + 10 * BatchSTTTimeouts.processingSecondsPerMB
        XCTAssertEqual(timeout, expected, accuracy: 0.001)
    }

    func test_uploadStallTimeoutSeconds_isPositive() {
        XCTAssertGreaterThan(BatchSTTTimeouts.uploadStallTimeoutSeconds, 0)
    }
}
