import AVFoundation
import Foundation
import Testing
import VoxCore
import VoxMac

/// Creates a PCM CAF file with sine wave content at 16kHz mono.
private func makeTestCAF(durationSeconds: Double = 1.0) throws -> URL {
    let sampleRate = 16_000.0
    let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("encoder-\(UUID().uuidString).caf")

    guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
        throw VoxError.internalError("Failed to create test audio format")
    }
    let file = try AVAudioFile(forWriting: url, settings: format.settings)

    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        throw VoxError.internalError("Failed to create test buffer")
    }
    buffer.frameLength = frameCount
    if let channelData = buffer.floatChannelData {
        for i in 0..<Int(frameCount) {
            channelData[0][i] = sin(Float(i) * 0.1) * 0.5
        }
    }
    try file.write(from: buffer)
    return url
}

@Suite("AudioEncoder")
struct AudioEncoderTests {
    @Test("convertToOpus produces non-empty output")
    func convertToOpus_producesNonEmptyOutput() async throws {
        let cafURL = try makeTestCAF(durationSeconds: 1.0)
        defer { SecureFileDeleter.delete(at: cafURL) }

        let opusURL = cafURL.deletingPathExtension().appendingPathExtension("opus.caf")
        defer { SecureFileDeleter.delete(at: opusURL) }

        try await AudioEncoder.convertToOpus(inputURL: cafURL, outputURL: opusURL)

        let attrs = try FileManager.default.attributesOfItem(atPath: opusURL.path)
        let size = attrs[.size] as? Int ?? 0
        #expect(size > 0, "Opus output must not be empty")
    }

    @Test("convertToOpus output is smaller than input")
    func convertToOpus_outputIsSmallerThanInput() async throws {
        let cafURL = try makeTestCAF(durationSeconds: 2.0)
        defer { SecureFileDeleter.delete(at: cafURL) }

        let cafSize = try FileManager.default.attributesOfItem(atPath: cafURL.path)[.size] as! Int

        let opusURL = cafURL.deletingPathExtension().appendingPathExtension("opus.caf")
        defer { SecureFileDeleter.delete(at: opusURL) }

        try await AudioEncoder.convertToOpus(inputURL: cafURL, outputURL: opusURL)

        let opusSize = try FileManager.default.attributesOfItem(atPath: opusURL.path)[.size] as! Int
        #expect(opusSize < cafSize, "Opus (\(opusSize)B) should be smaller than CAF (\(cafSize)B)")
        // Expect at least 3x compression for voice-rate audio
        #expect(opusSize * 3 < cafSize, "Expected at least 3x compression, got \(cafSize)/\(opusSize) = \(cafSize/max(opusSize,1))x")
    }

    @Test("encodeForUpload returns opus format on success")
    func encodeForUpload_returnsOpusOnSuccess() async throws {
        let cafURL = try makeTestCAF(durationSeconds: 1.0)
        defer { SecureFileDeleter.delete(at: cafURL) }

        let result = await AudioEncoder.encodeForUpload(cafURL: cafURL)
        defer {
            if result.url != cafURL {
                SecureFileDeleter.delete(at: result.url)
            }
        }

        #expect(result.encoded)
        #expect(result.bytes > 0)
        #expect(result.url != cafURL, "Opus URL should differ from input CAF")
    }

    @Test("encodeForUpload returns caf fallback for invalid input")
    func encodeForUpload_returnsCafFallbackForInvalidInput() async throws {
        let bogusURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).caf")

        let result = await AudioEncoder.encodeForUpload(cafURL: bogusURL)

        #expect(!result.encoded)
        #expect(result.url == bogusURL)
    }

    @Test("convertToOpus throws for corrupted input")
    func convertToOpus_throwsForCorruptedInput() async throws {
        let corruptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupt-\(UUID().uuidString).caf")
        try Data("not audio data".utf8).write(to: corruptURL)
        defer { SecureFileDeleter.delete(at: corruptURL) }

        let opusURL = corruptURL.deletingPathExtension().appendingPathExtension("opus.caf")
        defer { SecureFileDeleter.delete(at: opusURL) }

        await #expect(throws: (any Error).self) {
            try await AudioEncoder.convertToOpus(inputURL: corruptURL, outputURL: opusURL)
        }
    }

    @Test("encodeForUpload falls back for corrupted input")
    func encodeForUpload_fallsBackForCorruptedInput() async throws {
        let corruptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupt-\(UUID().uuidString).caf")
        try Data("not audio data".utf8).write(to: corruptURL)
        defer { SecureFileDeleter.delete(at: corruptURL) }

        let result = await AudioEncoder.encodeForUpload(cafURL: corruptURL)

        #expect(!result.encoded)
        #expect(result.url == corruptURL)
    }

    @Test("Opus output is valid CAF with Opus codec")
    func opusOutput_isValidCAFWithOpusCodec() async throws {
        let cafURL = try makeTestCAF(durationSeconds: 1.0)
        defer { SecureFileDeleter.delete(at: cafURL) }

        let opusURL = cafURL.deletingPathExtension().appendingPathExtension("opus.caf")
        defer { SecureFileDeleter.delete(at: opusURL) }

        try await AudioEncoder.convertToOpus(inputURL: cafURL, outputURL: opusURL)

        // Verify the output is valid audio with Opus codec
        let file = try AVAudioFile(forReading: opusURL)
        let formatID = file.fileFormat.settings[AVFormatIDKey] as? UInt32 ?? 0
        #expect(formatID == kAudioFormatOpus, "Output should be Opus encoded, got format ID \(formatID)")
    }

    @Test("Opus output filename has .opus.caf extension")
    func encodeForUpload_outputHasOpusCafExtension() async throws {
        let cafURL = try makeTestCAF(durationSeconds: 1.0)
        defer { SecureFileDeleter.delete(at: cafURL) }

        let result = await AudioEncoder.encodeForUpload(cafURL: cafURL)
        defer {
            if result.url != cafURL {
                SecureFileDeleter.delete(at: result.url)
            }
        }

        #expect(result.url.lastPathComponent.hasSuffix(".opus.caf"),
                "Output should have .opus.caf extension, got \(result.url.lastPathComponent)")
        #expect(result.url.pathExtension == "caf",
                "pathExtension should be 'caf' for provider compatibility")
    }
}
