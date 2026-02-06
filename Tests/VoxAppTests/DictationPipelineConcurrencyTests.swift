import Foundation
import Testing
import VoxAppKit
import VoxCore

private final class StubSTTProvider: STTProvider {
    let result: String

    init(result: String) {
        self.result = result
    }

    func transcribe(audioURL: URL) async throws -> String {
        result
    }
}

private final class StubRewriteProvider: RewriteProvider {
    let result: String

    init(result: String) {
        self.result = result
    }

    func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        result
    }
}

private final class NoopPaster: TextPaster {
    @MainActor
    func paste(text: String) async throws {}
}

@MainActor
private final class AccessTrackingPreferences: PreferencesReading {
    private let level: ProcessingLevel
    private let context: String
    private var offMainAccesses = 0

    init(level: ProcessingLevel, context: String) {
        self.level = level
        self.context = context
    }

    var processingLevel: ProcessingLevel {
        recordAccess()
        return level
    }

    var customContext: String {
        recordAccess()
        return context
    }

    var selectedInputDeviceUID: String? { nil }
    var elevenLabsAPIKey: String { "" }
    var openRouterAPIKey: String { "" }
    var deepgramAPIKey: String { "" }
    var openAIAPIKey: String { "" }

    var offMainAccessCount: Int { offMainAccesses }

    private func recordAccess() {
        guard !Thread.isMainThread else { return }
        offMainAccesses += 1
    }
}

@Suite("DictationPipeline Concurrency")
struct DictationPipelineConcurrencyTests {
    @Test("process reads preferences on main thread")
    func process_readsPreferencesOnMainThread() async throws {
        let prefs = await MainActor.run {
            AccessTrackingPreferences(level: .light, context: "project context")
        }
        let pipeline = await MainActor.run {
            DictationPipeline(
                stt: StubSTTProvider(result: "hello world"),
                rewriter: StubRewriteProvider(result: "hello world"),
                paster: NoopPaster(),
                prefs: prefs
            )
        }
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pipeline-\(UUID().uuidString).caf")

        _ = try await Task.detached {
            try await pipeline.process(audioURL: audioURL)
        }.value

        let offMainAccessCount = await MainActor.run { prefs.offMainAccessCount }
        #expect(offMainAccessCount == 0)
    }
}
