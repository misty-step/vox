import XCTest
@testable import VoxApp

@MainActor
final class VoxSessionTests: XCTestCase {
    func test_toggleRecording_usesInjectedDependencies() async {
        let recorder = RecordingMock()
        let pipeline = PipelineMock()
        let hud = HUDMock()
        var removedURL: URL?

        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: hud,
            prefs: .shared,
            permissionRequest: { true },
            removeFile: { url in removedURL = url }
        )

        await session.toggleRecording()
        await session.toggleRecording()

        XCTAssertEqual(recorder.startCount, 1)
        XCTAssertEqual(recorder.stopCount, 1)
        XCTAssertEqual(pipeline.processedURLs.count, 1)
        XCTAssertEqual(pipeline.processedURLs.first, recorder.recordingURL)
        XCTAssertEqual(hud.recordingCount, 1)
        XCTAssertEqual(hud.processingCount, 1)
        XCTAssertEqual(hud.hideCount, 1)
        XCTAssertEqual(removedURL, recorder.recordingURL)
        XCTAssertEqual(session.state, .idle)
    }
}

private final class RecordingMock: AudioRecording {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    let recordingURL = URL(fileURLWithPath: "/tmp/vox-recording.caf")

    func start() throws {
        startCount += 1
    }

    func currentLevel() -> (average: Float, peak: Float) {
        (0.1, 0.2)
    }

    func stop() throws -> URL {
        stopCount += 1
        return recordingURL
    }
}

private final class PipelineMock: DictationProcessing {
    private(set) var processedURLs: [URL] = []

    func process(audioURL: URL) async throws -> String {
        processedURLs.append(audioURL)
        return "ok"
    }
}

@MainActor
private final class HUDMock: HUDDisplaying {
    private(set) var recordingCount = 0
    private(set) var processingCount = 0
    private(set) var hideCount = 0

    func showRecording(average: Float, peak: Float) {
        recordingCount += 1
    }

    func updateLevels(average: Float, peak: Float) {}

    func showProcessing(message: String) {
        processingCount += 1
    }

    func hide() {
        hideCount += 1
    }
}
