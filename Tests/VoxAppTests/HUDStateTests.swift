import Testing
@testable import VoxMac

@Suite("HUDState mode transitions")
struct HUDStateTests {
    @Test("Initial state is idle and not visible")
    @MainActor func initialState() {
        let state = HUDState()
        #expect(state.mode == .idle)
        #expect(!state.isVisible)
        #expect(state.recordingDuration == 0)
        #expect(state.processingMessage == "Processing")
    }

    @Test("show makes state visible")
    @MainActor func showMakesVisible() {
        let state = HUDState()
        state.show()
        #expect(state.isVisible)
    }

    @Test("startRecording sets mode and resets duration")
    @MainActor func startRecordingSetsMode() {
        let state = HUDState()
        state.recordingDuration = 42
        state.startRecording()
        #expect(state.mode == .recording)
        #expect(state.recordingDuration == 0)
    }

    @Test("startProcessing sets mode and custom message")
    @MainActor func startProcessingSetsMode() {
        let state = HUDState()
        state.startProcessing(message: "Transcribing")
        #expect(state.mode == .processing)
        #expect(state.processingMessage == "Transcribing")
    }

    @Test("startProcessing uses default message when none provided")
    @MainActor func startProcessingDefaultMessage() {
        let state = HUDState()
        state.startProcessing()
        #expect(state.processingMessage == "Processing")
    }

    @Test("startSuccess sets mode")
    @MainActor func startSuccessSetsMode() {
        let state = HUDState()
        state.startSuccess()
        #expect(state.mode == .success)
    }

    @Test("stop resets all state")
    @MainActor func stopResetsAll() {
        let state = HUDState()
        state.show()
        state.startRecording()
        state.average = 0.5
        state.peak = 0.8
        state.recordingDuration = 10

        state.stop()

        #expect(state.mode == .idle)
        #expect(!state.isVisible)
        #expect(state.recordingDuration == 0)
        #expect(state.average == 0)
        #expect(state.peak == 0)
        #expect(state.processingMessage == "Processing")
    }

    @Test("dismiss with reduced motion resets immediately")
    @MainActor func dismissReducedMotion() {
        let state = HUDState()
        state.show()
        state.startRecording()

        var completed = false
        state.dismiss(reducedMotion: true) { completed = true }

        #expect(!state.isVisible)
        #expect(state.mode == .idle)
        #expect(completed)
    }

    @Test("Accessibility value for idle state")
    @MainActor func accessibilityIdle() {
        let state = HUDState()
        state.mode = .idle
        #expect(state.accessibilityValue == "Ready")
    }

    @Test("Accessibility value for success state")
    @MainActor func accessibilitySuccess() {
        let state = HUDState()
        state.mode = .success
        #expect(state.accessibilityValue == "Done")
    }
}
