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

    func test_errorDescription_pipelineTimeout_stt() {
        let error = VoxError.pipelineTimeout(stage: .stt)
        XCTAssertEqual(error.errorDescription, "Transcription timed out. Try again or check your connection.")
    }

    func test_errorDescription_pipelineTimeout_rewrite() {
        let error = VoxError.pipelineTimeout(stage: .rewrite)
        XCTAssertEqual(error.errorDescription, "Text processing timed out. Try again or check your connection.")
    }

    func test_errorDescription_pipelineTimeout_fullPipeline() {
        let error = VoxError.pipelineTimeout(stage: .fullPipeline)
        XCTAssertEqual(error.errorDescription, "Processing timed out. Try again or check your connection.")
    }

    // MARK: - Equatable Tests

    func test_equatable() {
        XCTAssertEqual(VoxError.noTranscript, VoxError.noTranscript)
        XCTAssertEqual(VoxError.insertionFailed, VoxError.insertionFailed)
        XCTAssertEqual(VoxError.provider("msg"), VoxError.provider("msg"))

        XCTAssertNotEqual(VoxError.noTranscript, VoxError.insertionFailed)
        XCTAssertNotEqual(VoxError.provider("a"), VoxError.provider("b"))
    }

    func test_equatable_pipelineTimeout() {
        XCTAssertEqual(
            VoxError.pipelineTimeout(stage: .stt),
            VoxError.pipelineTimeout(stage: .stt)
        )
        XCTAssertNotEqual(
            VoxError.pipelineTimeout(stage: .stt),
            VoxError.pipelineTimeout(stage: .rewrite)
        )
    }
}

// MARK: - PipelineStage Tests

final class PipelineStageTests: XCTestCase {

    func test_displayName() {
        XCTAssertEqual(PipelineStage.stt.displayName, "Transcription")
        XCTAssertEqual(PipelineStage.rewrite.displayName, "Text processing")
        XCTAssertEqual(PipelineStage.fullPipeline.displayName, "Processing")
    }

    func test_equatable() {
        XCTAssertEqual(PipelineStage.stt, PipelineStage.stt)
        XCTAssertEqual(PipelineStage.rewrite, PipelineStage.rewrite)
        XCTAssertEqual(PipelineStage.fullPipeline, PipelineStage.fullPipeline)

        XCTAssertNotEqual(PipelineStage.stt, PipelineStage.rewrite)
        XCTAssertNotEqual(PipelineStage.rewrite, PipelineStage.fullPipeline)
    }
}
