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
        #expect(snapshot.cloudTitle == "Cloud STT ready; rewrite not configured")
        #expect(snapshot.cloudNeedsAction == true)
        #expect(snapshot.toggleTitle == "Stop Dictation")
        #expect(snapshot.toggleEnabled == true)
    }

    @Test("Processing snapshot in Off mode with no cloud shows on-device status")
    func processingSnapshotOffModeNoCloud() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .processing(processingLevel: .off),
            hasCloudSTT: false,
            hasRewrite: false
        )

        #expect(snapshot.statusTitle == "Status: Processing")
        #expect(snapshot.modeTitle == "Mode: Off")
        #expect(snapshot.cloudTitle == "On-device transcription")
        #expect(snapshot.cloudNeedsAction == false)
        #expect(snapshot.toggleTitle == "Start Dictation")
        #expect(snapshot.toggleEnabled == false)
    }

    @Test("Off mode with cloud STT shows cloud transcription ready")
    func offModeWithCloudSTT() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .off),
            hasCloudSTT: true,
            hasRewrite: false
        )

        #expect(snapshot.cloudTitle == "Cloud transcription ready")
        #expect(snapshot.cloudNeedsAction == false)
    }

    @Test("Rewrite-only setup message is explicit")
    func rewriteOnlySnapshotMessage() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .light),
            hasCloudSTT: false,
            hasRewrite: true
        )

        #expect(snapshot.cloudTitle == "Rewrite ready; transcription on-device")
        #expect(snapshot.cloudNeedsAction == false)
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

    @Test("Light mode with no cloud services shows limited mode message")
    func lightModeNoCloudShowsLimited() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .light),
            hasCloudSTT: false,
            hasRewrite: false
        )

        #expect(snapshot.cloudTitle == "Cloud services not configured; limited to Off mode")
        #expect(snapshot.cloudNeedsAction == true)
    }

    @Test("Aggressive mode with cloud STT but no rewrite shows missing rewrite")
    func aggressiveModeMissingRewrite() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .aggressive),
            hasCloudSTT: true,
            hasRewrite: false
        )

        #expect(snapshot.cloudTitle == "Cloud STT ready; rewrite not configured")
        #expect(snapshot.cloudNeedsAction == true)
    }
}
