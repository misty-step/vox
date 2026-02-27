import Testing
@testable import VoxMac

@Suite("HUD accessibility")
struct HUDAccessibilityTests {
    @Test("HUDState exposes recording semantics for VoiceOver")
    @MainActor func stateRecordingAccessibility() {
        let state = HUDState()
        state.mode = .recording
        state.recordingDuration = 65

        #expect(state.accessibilityLabel == "Vox Dictation")
        #expect(state.accessibilityValue == "Recording, 01:05")
    }

    @Test("HUDState exposes processing semantics for VoiceOver")
    @MainActor func stateProcessingAccessibility() {
        let state = HUDState()
        state.mode = .processing

        #expect(state.accessibilityValue == "Processing")
    }

    @Test("Announcement policy emits transition announcements once per mode")
    func announcementPolicyDedupesTransitions() {
        var policy = HUDAnnouncementPolicy()

        #expect(policy.transitionAnnouncement(for: .recording) == "Recording started.")
        #expect(policy.transitionAnnouncement(for: .recording) == nil)

        #expect(policy.transitionAnnouncement(for: .processing) == "Recording stopped. Processing dictation.")
        #expect(policy.transitionAnnouncement(for: .processing) == nil)

        #expect(policy.transitionAnnouncement(for: .success) == "Dictation complete.")
        #expect(policy.transitionAnnouncement(for: .success) == nil)
    }

    @Test("Announcement policy reports failure only for active dictation modes")
    func announcementPolicyHideBehavior() {
        var policy = HUDAnnouncementPolicy()

        #expect(policy.hideAnnouncement(for: .idle) == nil)
        #expect(policy.hideAnnouncement(for: .success) == nil)
        #expect(policy.hideAnnouncement(for: .processing) == "Dictation failed.")
        #expect(policy.transitionAnnouncement(for: .processing) == "Recording stopped. Processing dictation.")
    }

    @Test("markIdle resets policy so next transition fires")
    func markIdleResetsPolicy() {
        var policy = HUDAnnouncementPolicy()

        #expect(policy.transitionAnnouncement(for: .recording) == "Recording started.")
        policy.markIdle()
        #expect(policy.transitionAnnouncement(for: .recording) == "Recording started.")
    }

    @Test("hideAnnouncement for recording says dictation failed")
    func hideAnnouncementRecording() {
        var policy = HUDAnnouncementPolicy()
        #expect(policy.hideAnnouncement(for: .recording) == "Dictation failed.")
    }

    @Test("Idle announcement is nil")
    func idleAnnouncementIsNil() {
        #expect(HUDAccessibility.stateAnnouncement(for: .idle) == nil)
    }

    @Test("Idle accessibility value is Ready")
    func idleAccessibilityValue() {
        #expect(HUDAccessibility.value(for: .idle, recordingDuration: 0, processingMessage: "") == "Ready")
    }

    @Test("Success accessibility value is Done")
    func successAccessibilityValue() {
        #expect(HUDAccessibility.value(for: .success, recordingDuration: 0, processingMessage: "") == "Done")
    }

    @Test("Duration formats correctly at boundaries")
    func durationFormatBoundaries() {
        #expect(HUDAccessibility.value(for: .recording, recordingDuration: 0, processingMessage: "") == "Recording, 00:00")
        #expect(HUDAccessibility.value(for: .recording, recordingDuration: 59.9, processingMessage: "") == "Recording, 00:59")
        #expect(HUDAccessibility.value(for: .recording, recordingDuration: 60, processingMessage: "") == "Recording, 01:00")
    }
}
