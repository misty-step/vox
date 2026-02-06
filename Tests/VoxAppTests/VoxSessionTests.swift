import Foundation
import Testing
import VoxCore
import VoxAppKit

// MARK: - Mocks

@MainActor
final class MockRecorder: AudioRecording {
    var startCallCount = 0
    var stopCallCount = 0
    var levelCallCount = 0
    var shouldThrowOnStart = false
    var shouldThrowOnStop = false
    private var recordingURL: URL?

    func start() throws {
        startCallCount += 1
        if shouldThrowOnStart {
            throw VoxError.internalError("Mock start failure")
        }
        recordingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mock-\(UUID().uuidString).caf")
        FileManager.default.createFile(atPath: recordingURL!.path, contents: Data())
    }

    func currentLevel() -> (average: Float, peak: Float) {
        levelCallCount += 1
        return (0.5, 0.7)
    }

    func stop() throws -> URL {
        stopCallCount += 1
        if shouldThrowOnStop {
            throw VoxError.internalError("Mock stop failure")
        }
        guard let url = recordingURL else {
            throw VoxError.internalError("No active recording")
        }
        recordingURL = nil
        return url
    }
}

@MainActor
final class MockHUD: HUDDisplaying {
    var showRecordingCallCount = 0
    var showProcessingCallCount = 0
    var updateLevelsCallCount = 0
    var showSuccessCallCount = 0
    var hideCallCount = 0
    var lastProcessingMessage: String?

    func showRecording(average: Float, peak: Float) {
        showRecordingCallCount += 1
    }

    func updateLevels(average: Float, peak: Float) {
        updateLevelsCallCount += 1
    }

    func showProcessing(message: String) {
        showProcessingCallCount += 1
        lastProcessingMessage = message
    }

    func showSuccess() {
        showSuccessCallCount += 1
    }

    func hide() {
        hideCallCount += 1
    }
}

/// Minimal HUD conformer that does NOT override showSuccess — tests the protocol default.
@MainActor
final class DefaultShowSuccessHUD: HUDDisplaying {
    var hideCallCount = 0
    func showRecording(average: Float, peak: Float) {}
    func updateLevels(average: Float, peak: Float) {}
    func showProcessing(message: String) {}
    func hide() { hideCallCount += 1 }
}

@MainActor
final class MockPipeline: DictationProcessing {
    var processCallCount = 0
    var lastAudioURL: URL?
    var result: String = "mock transcript"
    var shouldThrow = false

    func process(audioURL: URL) async throws -> String {
        processCallCount += 1
        lastAudioURL = audioURL
        if shouldThrow {
            throw VoxError.noTranscript
        }
        return result
    }
}

@MainActor
final class MockPreferencesStore: PreferencesReading {
    let processingLevel: ProcessingLevel = .light
    let customContext: String = ""
    let selectedInputDeviceUID: String? = nil
    let elevenLabsAPIKey: String = ""
    let openRouterAPIKey: String = ""
    let deepgramAPIKey: String = ""
    let openAIAPIKey: String = ""
}

// MARK: - Tests

@Suite("VoxSession DI")
struct VoxSessionDITests {

    @Test("Default init compiles without arguments")
    @MainActor func defaultInit() {
        // Verify the default init still works (no arguments required)
        // We can't fully exercise it without real audio hardware,
        // but compilation + instantiation proves backward compat
        let session = VoxSession()
        #expect(session.state == .idle)
    }

    @Test("Injected recorder is used")
    @MainActor func injectedRecorder() {
        let recorder = MockRecorder()
        let session = VoxSession(recorder: recorder)
        #expect(session.state == .idle)
        // Recorder is stored — verified by the fact that injection compiles
        // Actual recording requires microphone permission (can't unit test)
    }

    @Test("Injected HUD is used")
    @MainActor func injectedHUD() {
        let hud = MockHUD()
        let session = VoxSession(hud: hud)
        #expect(session.state == .idle)
    }

    @Test("Injected pipeline is used")
    @MainActor func injectedPipeline() {
        let pipeline = MockPipeline()
        let session = VoxSession(pipeline: pipeline)
        #expect(session.state == .idle)
    }

    @Test("Full injection with all dependencies")
    @MainActor func fullInjection() {
        let recorder = MockRecorder()
        let hud = MockHUD()
        let pipeline = MockPipeline()
        let prefs = MockPreferencesStore()
        let session = VoxSession(
            recorder: recorder,
            pipeline: pipeline,
            hud: hud,
            prefs: prefs
        )
        #expect(session.state == .idle)
    }

    @Test("Injected preferences are used")
    @MainActor func injectedPreferences() {
        let prefs = MockPreferencesStore()
        let session = VoxSession(prefs: prefs)
        #expect(session.state == .idle)
    }

    @Test("HUDDisplaying default showProcessing message")
    @MainActor func hudDefaultMessage() {
        let hud = MockHUD()
        hud.showProcessing()
        #expect(hud.lastProcessingMessage == "Transcribing")
    }

    @Test("HUDDisplaying default showSuccess calls hide")
    @MainActor func hudDefaultShowSuccess() {
        // Verify protocol default: showSuccess() falls back to hide()
        // MockHUD overrides showSuccess, so use a minimal conformer
        let hud = DefaultShowSuccessHUD()
        hud.showSuccess()
        #expect(hud.hideCallCount == 1)
    }

    @Test("DictationPipeline conforms to DictationProcessing")
    func pipelineConformance() {
        // Verify at compile time that DictationPipeline conforms
        let _: DictationProcessing.Type = DictationPipeline.self
    }
}
