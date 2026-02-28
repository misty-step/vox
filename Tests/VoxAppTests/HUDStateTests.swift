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
        #expect(state.processingElapsed == 0)
        #expect(state.processingStartDate == nil)
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

    @Test("startProcessing sets mode and starts elapsed clock")
    @MainActor func startProcessingSetsMode() {
        let state = HUDState()
        state.startProcessing()
        #expect(state.mode == .processing)
        #expect(state.processingStartDate != nil)
        #expect(state.processingElapsed == 0)
    }

    @Test("startSuccess sets mode and captures elapsed")
    @MainActor func startSuccessSetsMode() {
        let state = HUDState()
        state.startProcessing()
        state.startSuccess()
        #expect(state.mode == .success)
        #expect(state.processingStartDate == nil)
        #expect(state.processingElapsed >= 0)
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
        #expect(state.processingElapsed == 0)
        #expect(state.processingStartDate == nil)
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
        state.startProcessing()
        state.startSuccess()
        #expect(state.accessibilityValue == "Done")
    }
}
