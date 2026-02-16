import Testing
@testable import VoxAppKit

@Suite("Status bar menu snapshot")
struct StatusBarMenuSnapshotTests {
    @Test("Idle snapshot shows ready state and start action")
    func idleSnapshot() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .clean),
            hasCloudSTT: true,
            hasRewrite: true
        )

        #expect(snapshot.statusTitle == "Status: Ready")
        #expect(snapshot.modeTitle == "Mode: Clean")
        #expect(snapshot.cloudTitle == "Cloud services: Ready")
        #expect(snapshot.cloudNeedsAction == false)
        #expect(snapshot.toggleTitle == "Start Dictation")
        #expect(snapshot.toggleEnabled == true)
    }

    @Test("Recording snapshot keeps stop action and flags rewrite setup")
    func recordingSnapshotWithMissingRewrite() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .recording(processingLevel: .polish),
            hasCloudSTT: true,
            hasRewrite: false
        )

        #expect(snapshot.statusTitle == "Status: Recording")
        #expect(snapshot.modeTitle == "Mode: Polish")
        #expect(snapshot.cloudTitle == "Cloud STT ready; rewrite not configured")
        #expect(snapshot.cloudNeedsAction == true)
        #expect(snapshot.toggleTitle == "Stop Dictation")
        #expect(snapshot.toggleEnabled == true)
    }

    @Test("Processing snapshot in Raw mode with no cloud shows on-device status")
    func processingSnapshotRawModeNoCloud() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .processing(processingLevel: .raw),
            hasCloudSTT: false,
            hasRewrite: false
        )

        #expect(snapshot.statusTitle == "Status: Processing")
        #expect(snapshot.modeTitle == "Mode: Raw")
        #expect(snapshot.cloudTitle == "On-device transcription")
        #expect(snapshot.cloudNeedsAction == false)
        #expect(snapshot.toggleTitle == "Start Dictation")
        #expect(snapshot.toggleEnabled == false)
    }

    @Test("Raw mode with cloud STT shows cloud transcription ready")
    func rawModeWithCloudSTT() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .raw),
            hasCloudSTT: true,
            hasRewrite: false
        )

        #expect(snapshot.cloudTitle == "Cloud transcription ready")
        #expect(snapshot.cloudNeedsAction == false)
    }

    @Test("Rewrite-only setup message is explicit")
    func rewriteOnlySnapshotMessage() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .clean),
            hasCloudSTT: false,
            hasRewrite: true
        )

        #expect(snapshot.cloudTitle == "Rewrite ready; transcription on-device")
        #expect(snapshot.cloudNeedsAction == false)
    }

    @Test("Polish level label is preserved")
    func polishModeLabel() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .polish),
            hasCloudSTT: true,
            hasRewrite: true
        )

        #expect(snapshot.modeTitle == "Mode: Polish")
    }

    @Test("Clean mode with no cloud services shows limited mode message")
    func cleanModeNoCloudShowsLimited() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .clean),
            hasCloudSTT: false,
            hasRewrite: false
        )

        #expect(snapshot.cloudTitle == "Cloud services not configured; limited to Raw mode")
        #expect(snapshot.cloudNeedsAction == true)
    }

    @Test("Polish mode with cloud STT but no rewrite shows missing rewrite")
    func polishModeMissingRewrite() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .polish),
            hasCloudSTT: true,
            hasRewrite: false
        )

        #expect(snapshot.cloudTitle == "Cloud STT ready; rewrite not configured")
        #expect(snapshot.cloudNeedsAction == true)
    }
}
