import Testing
@testable import VoxUI
import VoxDiagnostics

@Suite("Settings view content snapshot")
struct SettingsViewContentTests {
    @Test("Header uses Vox title and Option+Space subtitle when hotkey is available")
    func headerWithAvailableHotkey() {
        let content = SettingsViewContent.make(
            productInfo: ProductInfo(version: "1.2.3", build: "456"),
            hotkeyAvailable: true
        )

        #expect(content.headerTitle == "Vox")
        #expect(content.headerSubtitle.contains("Option+Space"))
    }

    @Test("Header subtitle references menu bar icon when hotkey is unavailable")
    func headerWithUnavailableHotkey() {
        let content = SettingsViewContent.make(
            productInfo: ProductInfo(version: "1.2.3", build: "456"),
            hotkeyAvailable: false
        )

        #expect(content.headerSubtitle.contains("menu bar icon"))
    }

    @Test("Version text format is stable")
    func versionTextFormat() {
        let content = SettingsViewContent.make(
            productInfo: ProductInfo(version: "1.2.3", build: "456"),
            hotkeyAvailable: true
        )

        #expect(content.versionText == "Version 1.2.3 (456)")
    }

    @Test("Transcription summary falls back to on-device when no cloud keys configured")
    @MainActor
    func cloudSummaryTranscriptionWithoutKeys() {
        let summary = CloudProviderCatalog.transcriptionSummary(configuredProviderTitles: [])
        #expect(summary == "Apple Speech (on-device)")
    }

    @Test("Transcription summary includes ElevenLabs when configured")
    @MainActor
    func cloudSummaryTranscriptionWithElevenLabs() {
        let summary = CloudProviderCatalog.transcriptionSummary(configuredProviderTitles: ["ElevenLabs"])
        #expect(summary.contains("ElevenLabs"))
    }

    @Test("Rewrite summary preserves provider chain order")
    @MainActor
    func cloudSummaryRewriteWithAllProviders() {
        let summary = CloudProviderCatalog.rewriteSummary(
            configuredProviderTitles: ["Gemini", "Inception"]
        )
        #expect(summary.contains("Model-routed"))
        #expect(summary.contains("Inception"))
        #expect(summary.contains("Gemini"))
    }

    @Test("Rewrite summary falls back to raw transcript when no providers configured")
    @MainActor
    func cloudSummaryRewriteWithoutKeys() {
        let summary = CloudProviderCatalog.rewriteSummary(configuredProviderTitles: [])
        #expect(summary == "Raw transcript")
    }

    @Test("Rewrite summary shows single provider name")
    @MainActor
    func cloudSummaryRewriteSingleProvider() {
        #expect(CloudProviderCatalog.rewriteSummary(configuredProviderTitles: ["OpenRouter"]) == "OpenRouter")
        #expect(CloudProviderCatalog.rewriteSummary(configuredProviderTitles: ["Gemini"]) == "Gemini")
        #expect(CloudProviderCatalog.rewriteSummary(configuredProviderTitles: ["Inception"]) == "Inception")
    }

    @Test("Transcription summary preserves full chain order with multiple providers")
    @MainActor
    func cloudSummaryTranscriptionChainOrder() {
        let summary = CloudProviderCatalog.transcriptionSummary(
            configuredProviderTitles: ["ElevenLabs", "Deepgram"]
        )
        #expect(summary == "ElevenLabs → Deepgram → Apple Speech")
    }

    @Test("Version text handles empty version and build gracefully")
    func versionTextEmptyFields() {
        let content = SettingsViewContent.make(
            productInfo: ProductInfo(version: "", build: ""),
            hotkeyAvailable: true
        )
        #expect(content.versionText == "Version  ()")
    }
}
