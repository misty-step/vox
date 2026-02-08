import AVFoundation
import Foundation
import Testing
@testable import VoxCore
@testable import VoxMac

@Suite("CapturedAudioInspector")
struct CapturedAudioInspectorTests {
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

    @Test("Valid CAF passes capture validation")
    func validCAFPasses() throws {
        let url = try makeCAF(frameCount: 1_600)
        defer { try? FileManager.default.removeItem(at: url) }

        try CapturedAudioInspector.ensureHasAudioFrames(at: url)
    }

    @Test("Header-only CAF throws emptyCapture")
    func headerOnlyCAFThrows() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("header-only-\(UUID().uuidString).caf")
        let created = FileManager.default.createFile(atPath: url.path, contents: Data(count: 4096))
        #expect(created)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            try CapturedAudioInspector.ensureHasAudioFrames(at: url)
            Issue.record("Expected VoxError.emptyCapture")
        } catch let error as VoxError {
            #expect(error == .emptyCapture)
        } catch {
            Issue.record("Expected VoxError.emptyCapture, got \(error)")
        }
    }

    @Test("Unreadable CAF throws emptyCapture")
    func unreadableCAFThrows() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupt-\(UUID().uuidString).caf")
        let created = FileManager.default.createFile(atPath: url.path, contents: Data("not-caf".utf8))
        #expect(created)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            try CapturedAudioInspector.ensureHasAudioFrames(at: url)
            Issue.record("Expected VoxError.emptyCapture")
        } catch let error as VoxError {
            #expect(error == .emptyCapture)
        } catch {
            Issue.record("Expected VoxError.emptyCapture, got \(error)")
        }
    }

    @Test("Missing file is ignored")
    func missingFileIgnored() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).caf")
        try CapturedAudioInspector.ensureHasAudioFrames(at: url)
    }

    @Test("Non-CAF file is ignored")
    func nonCafFileIgnored() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sample-\(UUID().uuidString).ogg")
        let created = FileManager.default.createFile(atPath: url.path, contents: Data("ogg".utf8))
        #expect(created)
        defer { try? FileManager.default.removeItem(at: url) }

        try CapturedAudioInspector.ensureHasAudioFrames(at: url)
    }

    @Test("Validation applies only to CAF")
    func shouldValidateCAFOnly() {
        #expect(CapturedAudioInspector.shouldValidate(url: URL(fileURLWithPath: "/tmp/a.caf")))
        #expect(!CapturedAudioInspector.shouldValidate(url: URL(fileURLWithPath: "/tmp/a.ogg")))
        #expect(!CapturedAudioInspector.shouldValidate(url: URL(fileURLWithPath: "/tmp/a.wav")))
    }
}
