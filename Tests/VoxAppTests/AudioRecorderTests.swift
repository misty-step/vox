import AVFoundation
import XCTest
@testable import VoxMac

final class AudioRecorderComputeLevelsTests: XCTestCase {
    private func makeBuffer(samples: [Float]) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        )!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channel = buffer.floatChannelData![0]
        for (index, sample) in samples.enumerated() {
            channel[index] = sample
        }
        return buffer
    }

    func test_computeLevels_returnsZeroesWhenSilence() {
        let buffer = makeBuffer(samples: [0, 0, 0, 0])
        let levels = AudioRecorder.computeLevels(buffer: buffer)
        XCTAssertEqual(levels.average, 0)
        XCTAssertEqual(levels.peak, 0)
    }

    func test_computeLevels_returnsUnityWhenFullScale() {
        let buffer = makeBuffer(samples: [1.0, -1.0, 1.0, -1.0])
        let levels = AudioRecorder.computeLevels(buffer: buffer)
        XCTAssertEqual(levels.average, 1.0)
        XCTAssertEqual(levels.peak, 1.0)
    }

    func test_computeLevels_returnsZeroesWhenBufferEmpty() {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16)!
        buffer.frameLength = 0
        let levels = AudioRecorder.computeLevels(buffer: buffer)
        XCTAssertEqual(levels.average, 0)
        XCTAssertEqual(levels.peak, 0)
    }

    func test_computeLevels_clampsLevelsToUnitInterval() {
        let buffer = makeBuffer(samples: [0.01, -0.01, 0.01, -0.01])
        let levels = AudioRecorder.computeLevels(buffer: buffer)
        XCTAssertGreaterThanOrEqual(levels.average, 0)
        XCTAssertLessThanOrEqual(levels.average, 1)
        XCTAssertGreaterThanOrEqual(levels.peak, 0)
        XCTAssertLessThanOrEqual(levels.peak, 1)
    }

    func test_computeLevels_peakIsGreaterThanOrEqualToAverageForMixedAmplitude() {
        let buffer = makeBuffer(samples: [0.1, 0.9, 0.1, 0.1])
        let levels = AudioRecorder.computeLevels(buffer: buffer)
        XCTAssertGreaterThanOrEqual(levels.peak, levels.average)
    }

    func test_computeLevels_clampsQuietSignalToFloor() {
        let buffer = makeBuffer(samples: [0.001, 0.001, 0.001, 0.001])
        let levels = AudioRecorder.computeLevels(buffer: buffer)
        XCTAssertEqual(levels.average, 0)
        XCTAssertEqual(levels.peak, 0)
    }
}

final class AudioRecorderConversionTests: XCTestCase {
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
        for index in 0..<Int(frameCount) {
            channel[index] = sin(Float(index) * 0.01)
        }
        return buffer
    }

    func test_outputFrameCapacity_scalesForLowSampleRateInput() {
        let input = makeInputBuffer(sampleRate: 24_000, frameCount: 4_096)
        let capacity = AudioRecorder.outputFrameCapacity(
            for: input,
            outputFormat: outputFormat,
            minimumOutputFrameCapacity: 1_600
        )

        XCTAssertGreaterThan(capacity, 1_600)
        XCTAssertGreaterThanOrEqual(capacity, 2_700)
    }

    func test_convertInputBuffer_drainsFullChunk() throws {
        let input = makeInputBuffer(sampleRate: 24_000, frameCount: 4_096)
        guard let converter = AVAudioConverter(from: input.format, to: outputFormat) else {
            XCTFail("Failed to create AVAudioConverter for test")
            return
        }

        let convertedFrames = try AudioRecorder.convertInputBuffer(
            converter: converter,
            inputBuffer: input,
            outputFormat: outputFormat,
            minimumOutputFrameCapacity: 1_600
        ) { _ in }
        let flushedFrames = try AudioRecorder.flushConverterOutput(
            converter: converter,
            minimumOutputFrameCapacity: 1_600
        ) { _ in }

        let writtenFrames = convertedFrames + flushedFrames
        let expected = Int((Double(input.frameLength) * outputFormat.sampleRate / input.format.sampleRate).rounded())
        XCTAssertLessThanOrEqual(abs(Int(writtenFrames) - expected), 4)
        XCTAssertGreaterThan(writtenFrames, 1_600)
    }

    func test_convertInputBufferRecoveringFormat_rebuildsConverterForStaleInputFormat() throws {
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            return
        }

        let staleInputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        )!
        guard let staleConverter = AVAudioConverter(from: staleInputFormat, to: outputFormat) else {
            XCTFail("Failed to create stale AVAudioConverter for test")
            return
        }

        let actualInput = makeInputBuffer(sampleRate: 24_000, frameCount: 4_096)
        let conversion = try AudioRecorder.convertInputBufferRecoveringFormat(
            converter: staleConverter,
            inputBuffer: actualInput,
            outputFormat: outputFormat,
            minimumOutputFrameCapacity: 1_600
        ) { _ in }
        let flushed = try AudioRecorder.flushConverterOutput(
            converter: conversion.converter,
            minimumOutputFrameCapacity: 1_600
        ) { _ in }

        XCTAssertTrue(conversion.didRebuild)
        XCTAssertEqual(conversion.converter.inputFormat.sampleRate, actualInput.format.sampleRate)
        XCTAssertEqual(conversion.converter.inputFormat.channelCount, actualInput.format.channelCount)

        let expected = Int((Double(actualInput.frameLength) * outputFormat.sampleRate / actualInput.format.sampleRate).rounded())
        XCTAssertLessThanOrEqual(abs(Int(conversion.frames + flushed) - expected), 4)
    }

    func test_conversionAcrossRates_preservesDurationForCommonHardwareRates() throws {
        let sampleRates: [Double] = [16_000, 24_000, 44_100, 48_000]
        let chunkCount = 20
        let frameCount: AVAudioFrameCount = 4_096

        for sampleRate in sampleRates {
            let inputTemplate = makeInputBuffer(sampleRate: sampleRate, frameCount: frameCount)
            guard let converter = AVAudioConverter(from: inputTemplate.format, to: outputFormat) else {
                XCTFail("Failed to create AVAudioConverter for test")
                return
            }

            var writtenFrames: AVAudioFrameCount = 0
            for _ in 0..<chunkCount {
                let chunk = makeInputBuffer(sampleRate: sampleRate, frameCount: frameCount)
                writtenFrames += try AudioRecorder.convertInputBuffer(
                    converter: converter,
                    inputBuffer: chunk,
                    outputFormat: outputFormat,
                    minimumOutputFrameCapacity: 1_600
                ) { _ in }
            }
            writtenFrames += try AudioRecorder.flushConverterOutput(
                converter: converter,
                minimumOutputFrameCapacity: 1_600
            ) { _ in }

            let inputFrameTotal = AVAudioFrameCount(chunkCount) * frameCount
            let expected = Int(
                AudioRecorder.expectedOutputFrames(
                    inputFrames: inputFrameTotal,
                    inputSampleRate: sampleRate,
                    outputSampleRate: outputFormat.sampleRate
                )
            )
            XCTAssertLessThanOrEqual(abs(Int(writtenFrames) - expected), 12)
        }
    }

    func test_isConversionHealthy_flagsUnderflowRegression() {
        let underflow = AudioRecorder.isConversionHealthy(
            inputFrames: 4_096,
            outputFrames: 1_600,
            inputSampleRate: 24_000,
            outputSampleRate: 16_000
        )
        XCTAssertFalse(underflow)

        let healthy = AudioRecorder.isConversionHealthy(
            inputFrames: 4_096,
            outputFrames: 2_731,
            inputSampleRate: 24_000,
            outputSampleRate: 16_000
        )
        XCTAssertTrue(healthy)
    }

    func test_isInputFormatCompatible_detectsMismatchAndMatch() {
        let input24 = makeInputBuffer(sampleRate: 24_000, frameCount: 128)
        let input48 = makeInputBuffer(sampleRate: 48_000, frameCount: 128)
        guard let converter24 = AVAudioConverter(from: input24.format, to: outputFormat) else {
            XCTFail("Failed to create AVAudioConverter for compatibility test")
            return
        }

        XCTAssertTrue(AudioRecorder.isInputFormatCompatible(converter: converter24, inputBuffer: input24))
        XCTAssertFalse(AudioRecorder.isInputFormatCompatible(converter: converter24, inputBuffer: input48))
    }
}

final class AudioRecorderBackendSelectionTests: XCTestCase {
    func test_selectedBackend_defaultsToAVAudioEngine() {
        let backend = AudioRecorder.selectedBackend(environment: [:])
        XCTAssertEqual(backend, .avAudioEngine)
    }

    func test_selectedBackend_usesRecorderWhenEnvSet() {
        let backend = AudioRecorder.selectedBackend(environment: ["VOX_AUDIO_BACKEND": "recorder"])
        XCTAssertEqual(backend, .avAudioRecorder)
    }

    func test_selectedBackend_usesEngineWhenExplicitlySet() {
        let backend = AudioRecorder.selectedBackend(environment: ["VOX_AUDIO_BACKEND": "engine"])
        XCTAssertEqual(backend, .avAudioEngine)
    }

    func test_selectedBackend_usesEngineForUnknownValues() {
        let backend = AudioRecorder.selectedBackend(environment: ["VOX_AUDIO_BACKEND": "something-else"])
        XCTAssertEqual(backend, .avAudioEngine)
    }
}
