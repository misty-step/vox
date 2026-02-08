import AudioToolbox
import AVFoundation
import Foundation
import VoxCore

public final class AudioRecorder: AudioRecording {
    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var currentURL: URL?
    private var latestAverage: Float = 0
    private var latestPeak: Float = 0

    public init() {}

    public func start(inputDeviceUID: String? = nil) throws {
        if engine != nil { return }

        let engine = AVAudioEngine()

        // Per-app device routing via CoreAudio property on the engine's input AudioUnit.
        if let uid = inputDeviceUID,
           let deviceID = AudioDeviceManager.deviceID(forUID: uid) {
            let inputNode = engine.inputNode
            let audioUnit = inputNode.audioUnit!
            var id = deviceID
            let status = AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &id,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            if status != noErr {
                print("[AudioRecorder] Failed to set input device (status \(status)), using default")
            }
        }

        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        // Target: 16kHz, 16-bit, mono PCM in a CAF container.
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        ) else {
            throw VoxError.internalError("Failed to create target audio format.")
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vox-\(UUID().uuidString).caf")
        let file = try AVAudioFile(forWriting: url, settings: targetFormat.settings)

        // Converter from hardware format → target format.
        guard let converter = AVAudioConverter(from: hwFormat, to: targetFormat) else {
            throw VoxError.internalError("Cannot convert from hardware format to 16kHz/16-bit mono.")
        }

        let bufferCapacity = AVAudioFrameCount(targetFormat.sampleRate * 0.1) // 100ms buffers

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { [weak self] buffer, _ in
            // Compute metering from raw hardware buffer.
            let levels = Self.computeLevels(buffer: buffer)

            // Convert to target format and write to file.
            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: bufferCapacity
            ) else { return }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

            if let error {
                print("[AudioRecorder] Conversion error: \(error.localizedDescription)")
                return
            }

            if outputBuffer.frameLength > 0 {
                do {
                    try file.write(from: outputBuffer)
                } catch {
                    print("[AudioRecorder] Write error: \(error.localizedDescription)")
                }
            }

            // Dispatch metering to MainActor.
            DispatchQueue.main.async { [weak self] in
                self?.latestAverage = levels.average
                self?.latestPeak = levels.peak
            }
        }

        try engine.start()
        self.engine = engine
        self.audioFile = file
        self.currentURL = url
    }

    public func currentLevel() -> (average: Float, peak: Float) {
        (latestAverage, latestPeak)
    }

    public func stop() throws -> URL {
        guard let engine, let url = currentURL else {
            throw VoxError.internalError("No active recording.")
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        self.audioFile = nil
        self.currentURL = nil
        self.latestAverage = 0
        self.latestPeak = 0
        return url
    }

    // MARK: - Private

    /// Compute RMS average and peak from a PCM buffer, normalized to 0-1 range.
    private static func computeLevels(buffer: AVAudioPCMBuffer) -> (average: Float, peak: Float) {
        guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else {
            return (0, 0)
        }
        let samples = channelData[0]
        let count = Int(buffer.frameLength)
        var sumSquares: Float = 0
        var maxSample: Float = 0
        for i in 0..<count {
            let s = abs(samples[i])
            sumSquares += s * s
            if s > maxSample { maxSample = s }
        }
        let rms = sqrt(sumSquares / Float(count))

        // Convert to dB then normalize to 0-1 (matching existing -50dB floor).
        let minDb: Float = -50
        let rmsDb = rms > 0 ? 20 * log10(rms) : minDb
        let peakDb = maxSample > 0 ? 20 * log10(maxSample) : minDb
        let avgClamped = max(min(rmsDb, 0), minDb)
        let peakClamped = max(min(peakDb, 0), minDb)
        return ((avgClamped - minDb) / -minDb, (peakClamped - minDb) / -minDb)
    }
}
