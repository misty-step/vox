import AVFoundation
import Foundation
import VoxCore

public final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

    public init() {}

    public func start() throws {
        if recorder != nil {
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vox-\(UUID().uuidString).caf")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw VoxError.internalError("Failed to start recording.")
        }

        self.recorder = recorder
        self.currentURL = url
    }

    public func currentLevel() -> (average: Float, peak: Float) {
        guard let recorder else { return (average: 0, peak: 0) }
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        let minDb: Float = -50
        let averageClamped = max(min(averagePower, 0), minDb)
        let peakClamped = max(min(peakPower, 0), minDb)
        let averageLevel = (averageClamped - minDb) / (0 - minDb)
        let peakLevel = (peakClamped - minDb) / (0 - minDb)
        return (average: averageLevel, peak: peakLevel)
    }

    public func stop() throws -> URL {
        guard let recorder, let url = currentURL else {
            throw VoxError.internalError("No active recording.")
        }

        recorder.stop()
        self.recorder = nil
        self.currentURL = nil
        return url
    }
}
