import Testing
import VoxCore

@MainActor
private final class DefaultSessionExtension: SessionExtension {}

@Suite("SessionExtension")
struct SessionExtensionTests {
    @Test("Usage event clamps negative output count")
    func usageEventClampsNegativeOutput() {
        let event = DictationUsageEvent(
            recordingDuration: 1.25,
            outputCharacterCount: -12,
            processingLevel: .light
        )

        #expect(event.recordingDuration == 1.25)
        #expect(event.outputCharacterCount == 0)
        #expect(event.processingLevel == .light)
    }

    @Test("Default protocol methods are no-op")
    @MainActor
    func defaultMethodsAreNoop() async throws {
        let sessionExtension = DefaultSessionExtension()
        try await sessionExtension.authorizeRecordingStart()
        await sessionExtension.didCompleteDictation(
            event: DictationUsageEvent(
                recordingDuration: 0,
                outputCharacterCount: 0,
                processingLevel: .off
            )
        )
        await sessionExtension.didFailDictation(reason: "ignored")
    }
}
