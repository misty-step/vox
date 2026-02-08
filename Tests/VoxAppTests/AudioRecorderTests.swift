import AVFoundation
import Testing
@testable import VoxMac

@Suite("AudioRecorder.computeLevels")
struct AudioRecorderComputeLevelsTests {

    private func makeBuffer(samples: [Float]) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channel = buffer.floatChannelData![0]
        for (i, s) in samples.enumerated() {
            channel[i] = s
        }
        return buffer
    }

    @Test("Silence returns (0, 0)")
    func silence() {
        let buffer = makeBuffer(samples: [0, 0, 0, 0])
        let levels = AudioRecorder.computeLevels(buffer: buffer)
        #expect(levels.average == 0)
        #expect(levels.peak == 0)
    }

    @Test("Full-scale signal returns (1, 1)")
    func fullScale() {
        let buffer = makeBuffer(samples: [1.0, -1.0, 1.0, -1.0])
        let levels = AudioRecorder.computeLevels(buffer: buffer)
        #expect(levels.average == 1.0)
        #expect(levels.peak == 1.0)
    }

    @Test("Empty buffer returns (0, 0)")
    func emptyBuffer() {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16)!
        buffer.frameLength = 0
        let levels = AudioRecorder.computeLevels(buffer: buffer)
        #expect(levels.average == 0)
        #expect(levels.peak == 0)
    }

    @Test("Levels are clamped to 0-1 range")
    func clampedRange() {
        // -40dB signal: 0.01 amplitude → should be in range (0, 1)
        let buffer = makeBuffer(samples: [0.01, -0.01, 0.01, -0.01])
        let levels = AudioRecorder.computeLevels(buffer: buffer)
        #expect(levels.average >= 0 && levels.average <= 1)
        #expect(levels.peak >= 0 && levels.peak <= 1)
    }

    @Test("Peak >= average for mixed-amplitude signal")
    func peakGreaterThanAverage() {
        let buffer = makeBuffer(samples: [0.1, 0.9, 0.1, 0.1])
        let levels = AudioRecorder.computeLevels(buffer: buffer)
        #expect(levels.peak >= levels.average)
    }

    @Test("Very quiet signal (-60dB) clamps to floor")
    func quietSignalClampsToFloor() {
        // 0.001 amplitude ≈ -60dB, below the -50dB floor
        let buffer = makeBuffer(samples: [0.001, 0.001, 0.001, 0.001])
        let levels = AudioRecorder.computeLevels(buffer: buffer)
        #expect(levels.average == 0)
        #expect(levels.peak == 0)
    }
}

@Suite("AudioRecorder conversion")
struct AudioRecorderConversionTests {
    private let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
    )!

    private func makeInputBuffer(sampleRate: Double, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer {
        let inputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let channel = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            channel[i] = sin(Float(i) * 0.01)
        }
        return buffer
    }

    @Test("Output frame capacity scales for Bluetooth-rate input")
    func outputCapacityScalesForLowSampleRateInput() {
        let input = makeInputBuffer(sampleRate: 24_000, frameCount: 4_096)
        let capacity = AudioRecorder.outputFrameCapacity(
            for: input,
            outputFormat: outputFormat,
            minimumOutputFrameCapacity: 1_600
        )

        #expect(capacity > 1_600)
        #expect(capacity >= 2_700)
    }

    @Test("Conversion drains full 24k chunk instead of truncating to 100ms")
    func conversionDrainsFullChunk() throws {
        let input = makeInputBuffer(sampleRate: 24_000, frameCount: 4_096)
        guard let converter = AVAudioConverter(from: input.format, to: outputFormat) else {
            Issue.record("Failed to create AVAudioConverter for test")
            return
        }

        var writtenFrames: AVAudioFrameCount = 0
        try AudioRecorder.convertInputBuffer(
            converter: converter,
            inputBuffer: input,
            outputFormat: outputFormat,
            minimumOutputFrameCapacity: 1_600
        ) { output in
            writtenFrames += output.frameLength
        }
        try AudioRecorder.flushConverterOutput(
            converter: converter,
            minimumOutputFrameCapacity: 1_600
        ) { output in
            writtenFrames += output.frameLength
        }

        let expected = Int((Double(input.frameLength) * outputFormat.sampleRate / input.format.sampleRate).rounded())
        #expect(abs(Int(writtenFrames) - expected) <= 4)
        #expect(writtenFrames > 1_600)
    }

    @Test("Repeated 24k chunks preserve duration across many taps")
    func repeatedChunksPreserveDuration() throws {
        let chunkCount = 20
        let frameCount: AVAudioFrameCount = 4_096
        let inputTemplate = makeInputBuffer(sampleRate: 24_000, frameCount: frameCount)

        guard let converter = AVAudioConverter(from: inputTemplate.format, to: outputFormat) else {
            Issue.record("Failed to create AVAudioConverter for test")
            return
        }

        var writtenFrames: AVAudioFrameCount = 0
        for _ in 0..<chunkCount {
            let chunk = makeInputBuffer(sampleRate: 24_000, frameCount: frameCount)
            try AudioRecorder.convertInputBuffer(
                converter: converter,
                inputBuffer: chunk,
                outputFormat: outputFormat,
                minimumOutputFrameCapacity: 1_600
            ) { output in
                writtenFrames += output.frameLength
            }
        }
        try AudioRecorder.flushConverterOutput(
            converter: converter,
            minimumOutputFrameCapacity: 1_600
        ) { output in
            writtenFrames += output.frameLength
        }

        let expected = Int(Double(chunkCount) * Double(frameCount) * outputFormat.sampleRate / inputTemplate.format.sampleRate)
        #expect(abs(Int(writtenFrames) - expected) <= 8)
    }
}
