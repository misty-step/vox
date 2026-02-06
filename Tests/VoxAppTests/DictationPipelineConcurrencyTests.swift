import AVFoundation
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

private func makeTestCAF() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("pipeline-\(UUID().uuidString).caf")
    let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    let frameCount = AVAudioFrameCount(16_000 / 5) // 200ms
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    buffer.frameLength = frameCount
    if let channelData = buffer.floatChannelData {
        for index in 0..<Int(frameCount) {
            channelData[0][index] = 0
        }
    }
    try file.write(from: buffer)
    return url
}

@MainActor
private final class AccessTrackingPreferences: PreferencesReading {
    private let level: ProcessingLevel
    private var offMainAccesses = 0

    init(level: ProcessingLevel) {
        self.level = level
    }

    var processingLevel: ProcessingLevel {
        recordAccess()
        return level
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
            AccessTrackingPreferences(level: .light)
        }
        let pipeline = await MainActor.run {
            DictationPipeline(
                stt: StubSTTProvider(result: "hello world"),
                rewriter: StubRewriteProvider(result: "hello world"),
                paster: NoopPaster(),
                prefs: prefs
            )
        }
        let audioURL = try makeTestCAF()
        defer { SecureFileDeleter.delete(at: audioURL) }

        _ = try await Task.detached {
            try await pipeline.process(audioURL: audioURL)
        }.value

        let offMainAccessCount = await MainActor.run { prefs.offMainAccessCount }
        #expect(offMainAccessCount == 0)
    }
}
