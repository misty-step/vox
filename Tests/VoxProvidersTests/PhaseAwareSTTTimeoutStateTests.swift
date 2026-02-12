import Foundation
@testable import VoxProviders
import XCTest

final class PhaseAwareSTTTimeoutStateTests: XCTestCase {
    func test_uploadStallTimeout_firesAfterNoProgress() {
        var state = PhaseAwareSTTTimeoutState()

        let expectedBytes: Int64 = 100
        let stallTimeout = Duration.milliseconds(300)
        let processingTimeout = Duration.seconds(10)

        // Initial poll: no timeout.
        XCTAssertNil(state.poll(
            now: .milliseconds(0),
            bytesSent: 0,
            expectedBytes: expectedBytes,
            uploadStallTimeout: stallTimeout,
            processingTimeout: processingTimeout
        ))

        // Some progress at t=200ms resets stall timer.
        XCTAssertNil(state.poll(
            now: .milliseconds(200),
            bytesSent: 10,
            expectedBytes: expectedBytes,
            uploadStallTimeout: stallTimeout,
            processingTimeout: processingTimeout
        ))

        // No more progress; stall not yet exceeded at t=450ms (250ms since last progress).
        XCTAssertNil(state.poll(
            now: .milliseconds(450),
            bytesSent: 10,
            expectedBytes: expectedBytes,
            uploadStallTimeout: stallTimeout,
            processingTimeout: processingTimeout
        ))

        // Stall exceeded at t=600ms (400ms since last progress).
        XCTAssertEqual(state.poll(
            now: .milliseconds(600),
            bytesSent: 10,
            expectedBytes: expectedBytes,
            uploadStallTimeout: stallTimeout,
            processingTimeout: processingTimeout
        ), .uploadStall)
    }

    func test_uploadStallTimeout_doesNotFireWhileProgressContinues() {
        var state = PhaseAwareSTTTimeoutState()

        let expectedBytes: Int64 = 100
        let stallTimeout = Duration.milliseconds(200)
        let processingTimeout = Duration.seconds(10)

        // Progress arrives every 150ms (< stallTimeout).
        var now = Duration.zero
        var sent: Int64 = 0
        for _ in 0..<5 {
            now += .milliseconds(150)
            sent += 10
            XCTAssertNil(state.poll(
                now: now,
                bytesSent: sent,
                expectedBytes: expectedBytes,
                uploadStallTimeout: stallTimeout,
                processingTimeout: processingTimeout
            ))
        }
    }

    func test_processingTimeout_firesOnlyAfterUploadCompletes() {
        var state = PhaseAwareSTTTimeoutState()

        let expectedBytes: Int64 = 100
        let stallTimeout = Duration.milliseconds(300)
        let processingTimeout = Duration.milliseconds(200)

        // Upload completes at t=50ms.
        XCTAssertNil(state.poll(
            now: .milliseconds(50),
            bytesSent: 100,
            expectedBytes: expectedBytes,
            uploadStallTimeout: stallTimeout,
            processingTimeout: processingTimeout
        ))

        // Still within processing timeout at t=200ms (150ms after completion).
        XCTAssertNil(state.poll(
            now: .milliseconds(200),
            bytesSent: 100,
            expectedBytes: expectedBytes,
            uploadStallTimeout: stallTimeout,
            processingTimeout: processingTimeout
        ))

        // Processing timeout exceeded at t=300ms (250ms after completion).
        XCTAssertEqual(state.poll(
            now: .milliseconds(300),
            bytesSent: 100,
            expectedBytes: expectedBytes,
            uploadStallTimeout: stallTimeout,
            processingTimeout: processingTimeout
        ), .processingTimeout)
    }
}
