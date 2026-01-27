import AppKit
import Foundation
import VoxCore
import VoxMac

/// Adapter wrapping `AudioRecorder` for `SessionRecorder`.
final class AudioRecorderAdapter: SessionRecorder, @unchecked Sendable {
    private let recorder: AudioRecorder

    init(recorder: AudioRecorder) {
        self.recorder = recorder
    }

    func start() async throws {
        try recorder.start()
    }

    func stop() async throws -> Data {
        let url = try recorder.stop()
        defer {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                Diagnostics.warning("Failed to remove temp audio: \(String(describing: error))")
            }
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            Diagnostics.error("Failed to read recorded audio: \(String(describing: error))")
            throw error
        }
    }
}

/// Adapter wrapping `DictationPipeline` for `SessionPipeline`.
actor DictationPipelineAdapter: SessionPipeline {
    private let pipeline: DictationPipeline
    private let historyStore: HistoryStore?
    private let metadataConfig: SessionMetadataConfig
    private var processingLevel: ProcessingLevel
    private var targetAppBundleId: String?

    init(
        pipeline: DictationPipeline,
        historyStore: HistoryStore?,
        metadataConfig: SessionMetadataConfig,
        processingLevel: ProcessingLevel
    ) {
        self.pipeline = pipeline
        self.historyStore = historyStore
        self.metadataConfig = metadataConfig
        self.processingLevel = processingLevel
    }

    func updateProcessingLevel(_ level: ProcessingLevel) {
        processingLevel = level
    }

    func captureTargetApplication(bundleId: String?) {
        targetAppBundleId = bundleId
    }

    func process(audio: Data) async throws -> String {
        let sessionId = UUID()
        let level = processingLevel
        let audioURL = try writeTemporaryAudio(audio, sessionId: sessionId)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let targetBundleId: String?
        if let captured = targetAppBundleId {
            targetBundleId = captured
        } else {
            targetBundleId = await MainActor.run {
                NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            }
        }
        targetAppBundleId = nil

        let history = historyStore?.startSession(
            metadata: HistoryMetadata(
                sessionId: sessionId,
                startedAt: Date(),
                updatedAt: Date(),
                processingLevel: level.rawValue,
                locale: metadataConfig.locale,
                sttModelId: metadataConfig.sttModelId,
                rewriteModelId: metadataConfig.rewriteModelId,
                maxOutputTokens: metadataConfig.maxOutputTokens,
                temperature: metadataConfig.temperature,
                thinkingLevel: metadataConfig.thinkingLevel,
                targetAppBundleId: targetBundleId,
                audioFileName: audioURL.lastPathComponent,
                audioFileSizeBytes: audio.count,
                transcriptLength: nil,
                rewriteLength: nil,
                finalLength: nil,
                rewriteRatio: nil,
                pasteSucceeded: nil,
                errors: []
            )
        )

        if let history {
            await history.recordAudioInfo(fileName: audioURL.lastPathComponent, sizeBytes: audio.count)
        }

        do {
            return try await pipeline.run(
                sessionId: sessionId,
                audioURL: audioURL,
                processingLevel: level,
                history: history
            )
        } catch {
            if let history {
                await history.recordError("Processing failed: \(String(describing: error))")
            }
            throw error
        }
    }

    private func writeTemporaryAudio(_ audio: Data, sessionId: UUID) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vox-\(sessionId.uuidString).caf")
        do {
            try audio.write(to: url, options: .atomic)
            return url
        } catch {
            Diagnostics.error("Failed to write temp audio: \(String(describing: error))")
            throw error
        }
    }
}

/// Adapter wrapping `ClipboardPaster` for `SessionPaster`.
final class ClipboardPasterAdapter: SessionPaster, @unchecked Sendable {
    private let paster: ClipboardPaster

    init(paster: ClipboardPaster) {
        self.paster = paster
    }

    func paste(_ text: String) async throws {
        try paster.paste(text: text)
    }
}
