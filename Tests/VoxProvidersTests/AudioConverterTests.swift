import AVFoundation
import Foundation
import XCTest
@testable import VoxProviders

final class AudioConverterTests: XCTestCase {
    func test_isOpusConversionAvailable_isStableAcrossCalls() async {
        let firstResult = await AudioConverter.isOpusConversionAvailable()
        let secondResult = await AudioConverter.isOpusConversionAvailable()

        XCTAssertEqual(firstResult, secondResult)
    }

    func test_opusConversionAvailability_returnsAvailabilityAndReason() async {
        let status = await AudioConverter.opusConversionAvailability()
        let cachedAvailable = await AudioConverter.isOpusConversionAvailable()

        if status.isAvailable {
            XCTAssertNil(status.unavailableReason)
        } else {
            XCTAssertNotNil(status.unavailableReason)
            XCTAssertFalse(status.unavailableReason!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        XCTAssertEqual(status.isAvailable, cachedAvailable)
    }

    func test_convertCAFToOpus_outputIsSmallerThanInput() async throws {
        let cafURL = try makeTestCAF(durationSeconds: 60.0)
        defer { try? FileManager.default.removeItem(at: cafURL) }

        let opusURL: URL
        do {
            opusURL = try await AudioConverter.convertCAFToOpus(from: cafURL)
        } catch let error as AudioConversionError {
            throw XCTSkip("Opus conversion is unavailable in this runtime: \(error.localizedDescription)")
        }
        defer { try? FileManager.default.removeItem(at: opusURL) }

        let cafSize = try fileSize(at: cafURL)
        let opusSize = try fileSize(at: opusURL)

        XCTAssertEqual(opusURL.pathExtension.lowercased(), "ogg")
        XCTAssertGreaterThan(opusSize, 0)
        XCTAssertLessThan(opusSize, cafSize, "Expected Opus OGG (\(opusSize)B) to be smaller than CAF (\(cafSize)B)")
    }

    private func makeTestCAF(durationSeconds: Double) throws -> URL {
        let sampleRate = 16_000.0
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("converter-\(UUID().uuidString).caf")

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw NSError(domain: "AudioConverterTests", code: 1)
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioConverterTests", code: 2)
        }
        buffer.frameLength = frameCount
        if let channelData = buffer.floatChannelData {
            for index in 0..<Int(frameCount) {
                channelData[0][index] = sin(Float(index) * 0.1) * 0.5
            }
        }
        try file.write(from: buffer)
        return url
    }

    private func fileSize(at url: URL) throws -> Int {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return attrs[.size] as? Int ?? 0
    }
}
