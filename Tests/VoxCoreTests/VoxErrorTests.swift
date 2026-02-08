import XCTest
@testable import VoxCore

final class VoxErrorTests: XCTestCase {

    // MARK: - Error Description Tests

    func test_errorDescription_permissionDenied() {
        let error = VoxError.permissionDenied("Microphone access required")
        XCTAssertEqual(error.errorDescription, "Microphone access required")
    }

    func test_errorDescription_noFocusedElement() {
        let error = VoxError.noFocusedElement
        XCTAssertEqual(error.errorDescription, "No text field focused.")
    }

    func test_errorDescription_noTranscript() {
        let error = VoxError.noTranscript
        XCTAssertEqual(error.errorDescription, "No transcript returned.")
    }

    func test_errorDescription_returnsMessageWhenEmptyCapture() {
        let error = VoxError.emptyCapture
        XCTAssertEqual(error.errorDescription, "No audio captured. Check input device routing and retry.")
    }

    func test_errorDescription_audioCaptureFailed() {
        let error = VoxError.audioCaptureFailed("Tap write failed")
        XCTAssertEqual(error.errorDescription, "Tap write failed")
    }

    func test_errorDescription_insertionFailed() {
        let error = VoxError.insertionFailed
        XCTAssertEqual(error.errorDescription, "Failed to insert text.")
    }

    func test_errorDescription_provider() {
        let error = VoxError.provider("STT service unavailable")
        XCTAssertEqual(error.errorDescription, "STT service unavailable")
    }

    func test_errorDescription_internalError() {
        let error = VoxError.internalError("Something went wrong")
        XCTAssertEqual(error.errorDescription, "Something went wrong")
    }

    func test_errorDescription_pipelineTimeout() {
        let error = VoxError.pipelineTimeout
        XCTAssertEqual(error.errorDescription, "Processing timed out. Try again or check your connection.")
    }

    // MARK: - Equatable Tests

    func test_equatable() {
        XCTAssertEqual(VoxError.noTranscript, VoxError.noTranscript)
        XCTAssertEqual(VoxError.emptyCapture, VoxError.emptyCapture)
        XCTAssertEqual(VoxError.audioCaptureFailed("tap"), VoxError.audioCaptureFailed("tap"))
        XCTAssertEqual(VoxError.insertionFailed, VoxError.insertionFailed)
        XCTAssertEqual(VoxError.provider("msg"), VoxError.provider("msg"))
        XCTAssertEqual(VoxError.pipelineTimeout, VoxError.pipelineTimeout)

        XCTAssertNotEqual(VoxError.noTranscript, VoxError.insertionFailed)
        XCTAssertNotEqual(VoxError.emptyCapture, VoxError.noTranscript)
        XCTAssertNotEqual(VoxError.audioCaptureFailed("a"), VoxError.audioCaptureFailed("b"))
        XCTAssertNotEqual(VoxError.provider("a"), VoxError.provider("b"))
    }
}
