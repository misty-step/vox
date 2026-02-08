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
