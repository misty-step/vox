import AudioToolbox
@preconcurrency import AVFoundation
import Foundation
import VoxCore

public final class AudioRecorder: AudioRecording {
    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var converter: AVAudioConverter?
    private var currentURL: URL?
    private var latestAverage: Float = 0
    private var latestPeak: Float = 0

    /// Frames per tap callback; balances latency vs CPU overhead.
    private static let tapBufferSize: AVAudioFrameCount = 4096
    private static let perAppRoutingEnv = "VOX_ENABLE_PER_APP_AUDIO_ROUTING"

    public init() {}

    public func start(inputDeviceUID: String?) throws {
        if engine != nil { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Per-app routing can be flaky on some Bluetooth routes.
        // Keep it opt-in and rely on system-default routing by default.
        let usePerAppRouting = ProcessInfo.processInfo.environment[Self.perAppRoutingEnv] == "1"
        if usePerAppRouting,
           let uid = inputDeviceUID,
           let deviceID = AudioDeviceManager.deviceID(forUID: uid) {
            if let audioUnit = inputNode.audioUnit {
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
                    print("[AudioRecorder] Failed per-app input routing (status \(status)), using default input")
                }
            } else {
                print("[AudioRecorder] Input AudioUnit unavailable for per-app routing, using default input")
            }
        } else if inputDeviceUID != nil {
            print("[AudioRecorder] Per-app routing disabled; using system default input")
        }

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

        let minimumOutputFrameCapacity = AVAudioFrameCount(targetFormat.sampleRate * 0.1) // 100ms floor
        var didLogConversionUnderflow = false
        var tapConverter = converter

        inputNode.installTap(onBus: 0, bufferSize: Self.tapBufferSize, format: hwFormat) { [weak self] buffer, _ in
            // Compute metering from raw hardware buffer.
            let levels = Self.computeLevels(buffer: buffer)

            // Convert to target format and write to file.
            var convertedFrames: AVAudioFrameCount = 0
            do {
                let conversion = try Self.convertInputBufferRecoveringFormat(
                    converter: tapConverter,
                    inputBuffer: buffer,
                    outputFormat: targetFormat,
                    minimumOutputFrameCapacity: minimumOutputFrameCapacity
                ) { outputBuffer in
                    try file.write(from: outputBuffer)
                }
                convertedFrames = conversion.frames
                tapConverter = conversion.converter
                if conversion.didRebuild {
                    print(
                        "[AudioRecorder] Rebuilt converter for input format " +
                        "\(Int(buffer.format.sampleRate))Hz/\(buffer.format.channelCount)ch"
                    )
                    let rebuiltConverter = conversion.converter
                    DispatchQueue.main.async { [weak self] in
                        self?.converter = rebuiltConverter
                    }
                }
            } catch {
                print("[AudioRecorder] Conversion error: \(error.localizedDescription)")
            }

            if !didLogConversionUnderflow,
               !Self.isConversionHealthy(
                   inputFrames: buffer.frameLength,
                   outputFrames: convertedFrames,
                   inputSampleRate: buffer.format.sampleRate,
                   outputSampleRate: targetFormat.sampleRate
               ) {
                didLogConversionUnderflow = true
                let expectedFrames = Self.expectedOutputFrames(
                    inputFrames: buffer.frameLength,
                    inputSampleRate: buffer.format.sampleRate,
                    outputSampleRate: targetFormat.sampleRate
                )
                let ratio = Self.conversionHealthRatio(
                    inputFrames: buffer.frameLength,
                    outputFrames: convertedFrames,
                    inputSampleRate: buffer.format.sampleRate,
                    outputSampleRate: targetFormat.sampleRate
                )
                print(
                    "[AudioRecorder] Conversion underflow detected: " +
                    "output \(convertedFrames) < expected \(expectedFrames) " +
                    "(ratio \(String(format: "%.2f", ratio)))"
                )
            }

            // Dispatch metering to MainActor.
            DispatchQueue.main.async { [weak self] in
                self?.latestAverage = levels.average
                self?.latestPeak = levels.peak
            }
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw error
        }
        self.engine = engine
        self.audioFile = file
        self.converter = converter
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

        // Flush any samples buffered inside the converter's resampler.
        if let converter, let file = audioFile {
            flushConverter(converter, to: file)
        }

        self.engine = nil
        self.audioFile = nil
        self.converter = nil
        self.currentURL = nil
        self.latestAverage = 0
        self.latestPeak = 0
        return url
    }

    /// Drain remaining samples from the converter by signaling end-of-stream.
    private func flushConverter(_ converter: AVAudioConverter, to file: AVAudioFile) {
        do {
            _ = try Self.flushConverterOutput(
                converter: converter,
                minimumOutputFrameCapacity: AVAudioFrameCount(converter.outputFormat.sampleRate * 0.1)
            ) { outputBuffer in
                try file.write(from: outputBuffer)
            }
        } catch {
            print("[AudioRecorder] Flush conversion error: \(error.localizedDescription)")
        }
    }

    // MARK: - Internal (visible for testing)

    /// Compute RMS average and peak from a PCM buffer, normalized to 0-1 range.
    nonisolated static func computeLevels(buffer: AVAudioPCMBuffer) -> (average: Float, peak: Float) {
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

    nonisolated static func outputFrameCapacity(
        for inputBuffer: AVAudioPCMBuffer,
        outputFormat: AVAudioFormat,
        minimumOutputFrameCapacity: AVAudioFrameCount
    ) -> AVAudioFrameCount {
        guard inputBuffer.frameLength > 0 else {
            return minimumOutputFrameCapacity
        }
        let estimated = expectedOutputFrames(
            inputFrames: inputBuffer.frameLength,
            inputSampleRate: inputBuffer.format.sampleRate,
            outputSampleRate: outputFormat.sampleRate
        ) + 64
        return max(minimumOutputFrameCapacity, estimated)
    }

    nonisolated static func expectedOutputFrames(
        inputFrames: AVAudioFrameCount,
        inputSampleRate: Double,
        outputSampleRate: Double
    ) -> AVAudioFrameCount {
        guard inputFrames > 0, inputSampleRate > 0, outputSampleRate > 0 else {
            return 0
        }
        let ratio = outputSampleRate / inputSampleRate
        return AVAudioFrameCount(ceil(Double(inputFrames) * ratio))
    }

    nonisolated static func conversionHealthRatio(
        inputFrames: AVAudioFrameCount,
        outputFrames: AVAudioFrameCount,
        inputSampleRate: Double,
        outputSampleRate: Double
    ) -> Double {
        let expected = expectedOutputFrames(
            inputFrames: inputFrames,
            inputSampleRate: inputSampleRate,
            outputSampleRate: outputSampleRate
        )
        guard expected > 0 else { return 1 }
        return Double(outputFrames) / Double(expected)
    }

    nonisolated static func isConversionHealthy(
        inputFrames: AVAudioFrameCount,
        outputFrames: AVAudioFrameCount,
        inputSampleRate: Double,
        outputSampleRate: Double,
        minimumRatio: Double = 0.85
    ) -> Bool {
        conversionHealthRatio(
            inputFrames: inputFrames,
            outputFrames: outputFrames,
            inputSampleRate: inputSampleRate,
            outputSampleRate: outputSampleRate
        ) >= minimumRatio
    }

    nonisolated static func convertInputBuffer(
        converter: AVAudioConverter,
        inputBuffer: AVAudioPCMBuffer,
        outputFormat: AVAudioFormat,
        minimumOutputFrameCapacity: AVAudioFrameCount,
        write: (AVAudioPCMBuffer) throws -> Void
    ) throws -> AVAudioFrameCount {
        var didProvideInput = false
        var iterations = 0
        var totalOutputFrames: AVAudioFrameCount = 0

        while true {
            iterations += 1
            if iterations > 32 {
                throw VoxError.internalError("Audio converter did not drain output.")
            }

            let frameCapacity = outputFrameCapacity(
                for: inputBuffer,
                outputFormat: outputFormat,
                minimumOutputFrameCapacity: minimumOutputFrameCapacity
            )
            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: frameCapacity
            ) else {
                throw VoxError.internalError("Failed to allocate output audio buffer.")
            }

            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                if didProvideInput {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                didProvideInput = true
                outStatus.pointee = .haveData
                return inputBuffer
            }

            if let error {
                throw error
            }
            if status == .error {
                throw VoxError.internalError("Audio converter returned error status.")
            }
            if outputBuffer.frameLength > 0 {
                totalOutputFrames += outputBuffer.frameLength
                try write(outputBuffer)
            }
            if status != .haveData {
                return totalOutputFrames
            }
        }
    }

    nonisolated static func convertInputBufferRecoveringFormat(
        converter: AVAudioConverter,
        inputBuffer: AVAudioPCMBuffer,
        outputFormat: AVAudioFormat,
        minimumOutputFrameCapacity: AVAudioFrameCount,
        write: (AVAudioPCMBuffer) throws -> Void
    ) throws -> (frames: AVAudioFrameCount, converter: AVAudioConverter, didRebuild: Bool) {
        do {
            let frames = try convertInputBuffer(
                converter: converter,
                inputBuffer: inputBuffer,
                outputFormat: outputFormat,
                minimumOutputFrameCapacity: minimumOutputFrameCapacity,
                write: write
            )
            return (frames, converter, false)
        } catch {
            guard !isInputFormatCompatible(converter: converter, inputBuffer: inputBuffer) else {
                throw error
            }
            guard let rebuilt = AVAudioConverter(from: inputBuffer.format, to: outputFormat) else {
                throw VoxError.internalError("Cannot rebuild audio converter for input format.")
            }
            let frames = try convertInputBuffer(
                converter: rebuilt,
                inputBuffer: inputBuffer,
                outputFormat: outputFormat,
                minimumOutputFrameCapacity: minimumOutputFrameCapacity,
                write: write
            )
            return (frames, rebuilt, true)
        }
    }

    nonisolated static func isInputFormatCompatible(
        converter: AVAudioConverter,
        inputBuffer: AVAudioPCMBuffer
    ) -> Bool {
        let converterFormat = converter.inputFormat
        let inputFormat = inputBuffer.format
        return converterFormat.sampleRate == inputFormat.sampleRate &&
            converterFormat.channelCount == inputFormat.channelCount &&
            converterFormat.commonFormat == inputFormat.commonFormat &&
            converterFormat.isInterleaved == inputFormat.isInterleaved
    }

    nonisolated static func flushConverterOutput(
        converter: AVAudioConverter,
        minimumOutputFrameCapacity: AVAudioFrameCount,
        write: (AVAudioPCMBuffer) throws -> Void
    ) throws -> AVAudioFrameCount {
        var iterations = 0
        var totalOutputFrames: AVAudioFrameCount = 0

        while true {
            iterations += 1
            if iterations > 32 {
                throw VoxError.internalError("Audio converter flush did not complete.")
            }

            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: converter.outputFormat,
                frameCapacity: minimumOutputFrameCapacity
            ) else {
                throw VoxError.internalError("Failed to allocate flush output buffer.")
            }

            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .endOfStream
                return nil
            }

            if let error {
                throw error
            }
            if status == .error {
                throw VoxError.internalError("Audio converter returned error status during flush.")
            }
            if outputBuffer.frameLength > 0 {
                totalOutputFrames += outputBuffer.frameLength
                try write(outputBuffer)
            }
            if status != .haveData {
                return totalOutputFrames
            }
        }
    }
}
