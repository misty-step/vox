import Testing
@testable import VoxAppKit

@Suite("Status bar menu snapshot")
struct StatusBarMenuSnapshotTests {
    @Test("Idle snapshot shows ready state and start action")
    func idleSnapshot() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .light),
            hasCloudSTT: true,
            hasRewrite: true
        )

        #expect(snapshot.statusTitle == "Status: Ready")
        #expect(snapshot.modeTitle == "Mode: Light")
        #expect(snapshot.cloudTitle == "Cloud services: Ready")
        #expect(snapshot.cloudNeedsAction == false)
        #expect(snapshot.toggleTitle == "Start Dictation")
        #expect(snapshot.toggleEnabled == true)
    }

    @Test("Recording snapshot keeps stop action and flags rewrite setup")
    func recordingSnapshotWithMissingRewrite() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .recording(processingLevel: .aggressive),
            hasCloudSTT: true,
            hasRewrite: false
        )

        #expect(snapshot.statusTitle == "Status: Recording")
        #expect(snapshot.modeTitle == "Mode: Aggressive")
        #expect(snapshot.cloudTitle == "Cloud STT ready; rewrite missing")
        #expect(snapshot.cloudNeedsAction == true)
        #expect(snapshot.toggleTitle == "Stop Dictation")
        #expect(snapshot.toggleEnabled == true)
    }

    @Test("Processing snapshot disables toggle and reports local-only STT")
    func processingSnapshotDisablesToggle() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .processing(processingLevel: .off),
            hasCloudSTT: false,
            hasRewrite: false
        )

        #expect(snapshot.statusTitle == "Status: Processing")
        #expect(snapshot.modeTitle == "Mode: Off")
        #expect(snapshot.cloudTitle == "Cloud services: Not configured")
        #expect(snapshot.cloudNeedsAction == true)
        #expect(snapshot.toggleTitle == "Start Dictation")
        #expect(snapshot.toggleEnabled == false)
    }

    @Test("Rewrite-only setup message is explicit")
    func rewriteOnlySnapshotMessage() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .light),
            hasCloudSTT: false,
            hasRewrite: true
        )

        #expect(snapshot.cloudTitle == "Rewrite ready; transcription local")
        #expect(snapshot.cloudNeedsAction == true)
    }

    @Test("Enhance level label is preserved")
    func enhanceModeLabel() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .enhance),
            hasCloudSTT: true,
            hasRewrite: true
        )

        #expect(snapshot.modeTitle == "Mode: Enhance")
    }
}
