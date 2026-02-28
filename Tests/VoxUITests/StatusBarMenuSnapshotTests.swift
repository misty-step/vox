import Testing
@testable import VoxUI

@Suite("Status bar menu snapshot")
struct StatusBarMenuSnapshotTests {
    @Test("Idle snapshot shows ready state and start action")
    func idleSnapshot() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .clean),
            hasCloudSTT: true,
            hasRewrite: true,
            hotkeyAvailable: true
        )

        #expect(snapshot.statusTitle == "Status: Ready")
        #expect(snapshot.modeTitle == "Mode: Clean")
        #expect(snapshot.cloudTitle == "Cloud services: Ready")
        #expect(snapshot.cloudNeedsAction == false)
        #expect(snapshot.toggleTitle == "Start Dictation")
        #expect(snapshot.toggleEnabled == true)
        #expect(snapshot.hotkeyTitle == "Hotkey: ⌥Space ready")
        #expect(snapshot.hotkeyNeedsAction == false)
    }

    @Test("Recording snapshot keeps stop action and flags rewrite setup")
    func recordingSnapshotWithMissingRewrite() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .recording(processingLevel: .polish),
            hasCloudSTT: true,
            hasRewrite: false,
            hotkeyAvailable: true
        )

        #expect(snapshot.statusTitle == "Status: Recording")
        #expect(snapshot.modeTitle == "Mode: Polish")
        #expect(snapshot.cloudTitle == "Cloud STT ready; rewrite not configured")
        #expect(snapshot.cloudNeedsAction == true)
        #expect(snapshot.toggleTitle == "Stop Dictation")
        #expect(snapshot.toggleEnabled == true)
        #expect(snapshot.hotkeyTitle == "Hotkey: ⌥Space ready")
        #expect(snapshot.hotkeyNeedsAction == false)
    }

    @Test("Processing snapshot in Raw mode with no cloud shows on-device status")
    func processingSnapshotRawModeNoCloud() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .processing(processingLevel: .raw),
            hasCloudSTT: false,
            hasRewrite: false,
            hotkeyAvailable: true
        )

        #expect(snapshot.statusTitle == "Status: Processing")
        #expect(snapshot.modeTitle == "Mode: Raw")
        #expect(snapshot.cloudTitle == "On-device transcription")
        #expect(snapshot.cloudNeedsAction == false)
        #expect(snapshot.toggleTitle == "Start Dictation")
        #expect(snapshot.toggleEnabled == false)
        #expect(snapshot.hotkeyTitle == "Hotkey: ⌥Space ready")
        #expect(snapshot.hotkeyNeedsAction == false)
    }

    @Test("Raw mode with cloud STT shows cloud transcription ready")
    func rawModeWithCloudSTT() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .raw),
            hasCloudSTT: true,
            hasRewrite: false,
            hotkeyAvailable: true
        )

        #expect(snapshot.cloudTitle == "Cloud transcription ready")
        #expect(snapshot.cloudNeedsAction == false)
        #expect(snapshot.hotkeyTitle == "Hotkey: ⌥Space ready")
        #expect(snapshot.hotkeyNeedsAction == false)
    }

    @Test("Rewrite-only setup message is explicit")
    func rewriteOnlySnapshotMessage() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .clean),
            hasCloudSTT: false,
            hasRewrite: true,
            hotkeyAvailable: true
        )

        #expect(snapshot.cloudTitle == "Rewrite ready; transcription on-device")
        #expect(snapshot.cloudNeedsAction == false)
        #expect(snapshot.hotkeyTitle == "Hotkey: ⌥Space ready")
        #expect(snapshot.hotkeyNeedsAction == false)
    }

    @Test("Polish level label is preserved")
    func polishModeLabel() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .polish),
            hasCloudSTT: true,
            hasRewrite: true,
            hotkeyAvailable: true
        )

        #expect(snapshot.modeTitle == "Mode: Polish")
        #expect(snapshot.hotkeyTitle == "Hotkey: ⌥Space ready")
        #expect(snapshot.hotkeyNeedsAction == false)
    }

    @Test("Clean mode with no cloud services shows limited mode message")
    func cleanModeNoCloudShowsLimited() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .clean),
            hasCloudSTT: false,
            hasRewrite: false,
            hotkeyAvailable: true
        )

        #expect(snapshot.cloudTitle == "Cloud services not configured; limited to Raw mode")
        #expect(snapshot.cloudNeedsAction == true)
        #expect(snapshot.hotkeyTitle == "Hotkey: ⌥Space ready")
        #expect(snapshot.hotkeyNeedsAction == false)
    }

    @Test("Polish mode with cloud STT but no rewrite shows missing rewrite")
    func polishModeMissingRewrite() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .polish),
            hasCloudSTT: true,
            hasRewrite: false,
            hotkeyAvailable: true
        )

        #expect(snapshot.cloudTitle == "Cloud STT ready; rewrite not configured")
        #expect(snapshot.cloudNeedsAction == true)
        #expect(snapshot.hotkeyTitle == "Hotkey: ⌥Space ready")
        #expect(snapshot.hotkeyNeedsAction == false)
    }

    @Test("Unavailable hotkey shows fallback message")
    func unavailableHotkeyShowsFallback() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .clean),
            hasCloudSTT: true,
            hasRewrite: true,
            hotkeyAvailable: false
        )

        #expect(snapshot.hotkeyTitle == "Hotkey: unavailable (use menu)")
        #expect(snapshot.hotkeyNeedsAction == true)
    }

    @Test("Recovery items enabled when snapshot available in idle state")
    func recoveryEnabledWithSnapshot() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .clean),
            hasCloudSTT: true,
            hasRewrite: true,
            hotkeyAvailable: true,
            hasRecoverySnapshot: true
        )

        #expect(snapshot.copyRawEnabled == true)
        #expect(snapshot.retryEnabled == true)
    }

    @Test("Recovery items disabled when no snapshot")
    func recoveryDisabledWithoutSnapshot() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .idle(processingLevel: .clean),
            hasCloudSTT: true,
            hasRewrite: true,
            hotkeyAvailable: true,
            hasRecoverySnapshot: false
        )

        #expect(snapshot.copyRawEnabled == false)
        #expect(snapshot.retryEnabled == false)
    }

    @Test("Recovery items disabled during processing even if snapshot available")
    func recoveryDisabledDuringProcessing() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .processing(processingLevel: .clean),
            hasCloudSTT: true,
            hasRewrite: true,
            hotkeyAvailable: true,
            hasRecoverySnapshot: true
        )

        #expect(snapshot.copyRawEnabled == true)
        #expect(snapshot.retryEnabled == false)
    }

    @Test("Recovery items disabled when processing and no snapshot")
    func recoveryDisabledDuringProcessingNoSnapshot() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .processing(processingLevel: .clean),
            hasCloudSTT: true,
            hasRewrite: true,
            hotkeyAvailable: true,
            hasRecoverySnapshot: false
        )

        #expect(snapshot.copyRawEnabled == false)
        #expect(snapshot.retryEnabled == false)
    }

    @Test("Recording state: copy raw enabled with snapshot, retry disabled")
    func recoveryDuringRecordingWithSnapshot() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .recording(processingLevel: .clean),
            hasCloudSTT: true,
            hasRewrite: true,
            hotkeyAvailable: true,
            hasRecoverySnapshot: true
        )

        #expect(snapshot.copyRawEnabled == true)
        #expect(snapshot.retryEnabled == false)
    }

    @Test("Recording state: both recovery items disabled without snapshot")
    func recoveryDuringRecordingNoSnapshot() {
        let snapshot = StatusBarMenuSnapshot.make(
            state: .recording(processingLevel: .clean),
            hasCloudSTT: true,
            hasRewrite: true,
            hotkeyAvailable: true,
            hasRecoverySnapshot: false
        )

        #expect(snapshot.copyRawEnabled == false)
        #expect(snapshot.retryEnabled == false)
    }
}
