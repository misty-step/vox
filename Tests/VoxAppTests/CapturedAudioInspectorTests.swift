import AVFoundation
import Foundation
import XCTest
@testable import VoxCore
@testable import VoxMac

final class CapturedAudioInspectorTests: XCTestCase {
    private func makeCAF(frameCount: AVAudioFrameCount) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("capture-\(UUID().uuidString).caf")
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1) else {
            throw VoxError.internalError("Failed to create test audio format")
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw VoxError.internalError("Failed to create test audio buffer")
        }
        buffer.frameLength = frameCount
        if let channelData = buffer.floatChannelData {
            for index in 0..<Int(frameCount) {
                channelData[0][index] = 0
            }
        }
        try file.write(from: buffer)
        return url
    }

    func test_ensureHasAudioFrames_passesForValidCAF() throws {
        let url = try makeCAF(frameCount: 1_600)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertNoThrow(try CapturedAudioInspector.ensureHasAudioFrames(at: url))
    }

    func test_ensureHasAudioFrames_throwsEmptyCaptureForHeaderOnlyCAF() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("header-only-\(UUID().uuidString).caf")
        let created = FileManager.default.createFile(atPath: url.path, contents: Data(count: 4096))
        XCTAssertTrue(created)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try CapturedAudioInspector.ensureHasAudioFrames(at: url)) { error in
            XCTAssertEqual(error as? VoxError, .emptyCapture)
        }
    }

    func test_ensureHasAudioFrames_throwsEmptyCaptureForUnreadableCAF() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupt-\(UUID().uuidString).caf")
        let created = FileManager.default.createFile(atPath: url.path, contents: Data("not-caf".utf8))
        XCTAssertTrue(created)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try CapturedAudioInspector.ensureHasAudioFrames(at: url)) { error in
            XCTAssertEqual(error as? VoxError, .emptyCapture)
        }
    }

    func test_ensureHasAudioFrames_ignoresMissingFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).caf")
        XCTAssertNoThrow(try CapturedAudioInspector.ensureHasAudioFrames(at: url))
    }

    func test_ensureHasAudioFrames_ignoresNonCAFFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sample-\(UUID().uuidString).ogg")
        let created = FileManager.default.createFile(atPath: url.path, contents: Data("ogg".utf8))
        XCTAssertTrue(created)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertNoThrow(try CapturedAudioInspector.ensureHasAudioFrames(at: url))
    }

    func test_shouldValidate_appliesOnlyToCAF() {
        XCTAssertTrue(CapturedAudioInspector.shouldValidate(url: URL(fileURLWithPath: "/tmp/a.caf")))
        XCTAssertFalse(CapturedAudioInspector.shouldValidate(url: URL(fileURLWithPath: "/tmp/a.ogg")))
        XCTAssertFalse(CapturedAudioInspector.shouldValidate(url: URL(fileURLWithPath: "/tmp/a.wav")))
    }
}
