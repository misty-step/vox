import Foundation
import VoxProviders
import XCTest

final class AudioConverterStaticTests: XCTestCase {

    func test_conversionExecutable_pointsToAfconvert() {
        XCTAssertEqual(AudioConverter.conversionExecutable, "/usr/bin/afconvert")
    }

    func test_conversionExecutableName_returnsBasename() {
        XCTAssertEqual(AudioConverter.conversionExecutableName, "afconvert")
    }

    func test_opusAvailability_isAvailableAndReasonAreConsistent() async {
        let availability = await AudioConverter.opusConversionAvailability()
        if availability.isAvailable {
            XCTAssertNil(availability.unavailableReason)
        } else {
            XCTAssertNotNil(availability.unavailableReason)
        }
    }

    func test_opusAvailability_matchesBooleanCheck() async {
        let availability = await AudioConverter.opusConversionAvailability()
        let boolCheck = await AudioConverter.isOpusConversionAvailable()
        XCTAssertEqual(availability.isAvailable, boolCheck)
    }

    func test_opusAvailability_initCustomValues() {
        let available = OpusAvailability(isAvailable: true, unavailableReason: nil)
        XCTAssertTrue(available.isAvailable)
        XCTAssertNil(available.unavailableReason)

        let unavailable = OpusAvailability(isAvailable: false, unavailableReason: "test reason")
        XCTAssertFalse(unavailable.isAvailable)
        XCTAssertEqual(unavailable.unavailableReason, "test reason")
    }

    func test_convertCAFToWAV_producesWavFile() async throws {
        let cafURL = try makeMinimalCAF()
        defer { try? FileManager.default.removeItem(at: cafURL) }

        let wavURL: URL
        do {
            wavURL = try await AudioConverter.convertCAFToWAV(from: cafURL)
        } catch {
            throw XCTSkip("WAV conversion unavailable: \(error.localizedDescription)")
        }
        defer { try? FileManager.default.removeItem(at: wavURL) }

        XCTAssertEqual(wavURL.pathExtension.lowercased(), "wav")
        let attrs = try FileManager.default.attributesOfItem(atPath: wavURL.path)
        let size = attrs[.size] as? Int ?? 0
        XCTAssertGreaterThan(size, 0)
    }

    // MARK: - Helpers

    private func makeMinimalCAF() throws -> URL {
        // Create a minimal silent CAF using AVAudioFile
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).caf")

        let sampleRate = 16_000.0
        let frameCount: UInt32 = 16_000 // 1 second

        guard let format = AVFoundation.AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw NSError(domain: "test", code: 1)
        }

        let file = try AVFoundation.AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )

        guard let buffer = AVFoundation.AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "test", code: 2)
        }
        buffer.frameLength = frameCount
        // Leave samples at zero (silence)
        try file.write(from: buffer)
        return url
    }
}

import AVFoundation
