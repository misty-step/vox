#if canImport(FoundationModels)
import Foundation
import Testing
@testable import VoxCore
@testable import VoxProviders

// SpeechTranscriber requires macOS 26+ and hardware - unit tests focus on
// availability gating and build-time API contract verification.
@Suite("SpeechTranscriberClient")
struct SpeechTranscriberClientTests {
    @Test("conforms to STTProvider")
    func test_conformsToSTTProvider() {
        guard #available(macOS 26.0, *) else { return }
        let client = SpeechTranscriberClient()
        let _: any STTProvider = client // compile-time check
    }

    @Test("init does not throw")
    func test_initSucceeds() {
        guard #available(macOS 26.0, *) else { return }
        _ = SpeechTranscriberClient()
    }

    @Test("transcribe nonexistent file throws invalidAudio")
    func test_transcribe_nonexistentFile_throwsInvalidAudio() async {
        guard #available(macOS 26.0, *) else { return }
        let client = SpeechTranscriberClient()
        let bogus = URL(fileURLWithPath: "/tmp/vox-nonexistent-\(UUID().uuidString).caf")
        do {
            _ = try await client.transcribe(audioURL: bogus)
            Issue.record("Expected STTError.invalidAudio but no error thrown")
        } catch STTError.invalidAudio {
            // expected
        } catch {
            Issue.record("Expected STTError.invalidAudio, got: \(error)")
        }
    }

    @Test("transcribe non-audio file throws invalidAudio")
    func test_transcribe_nonAudioFile_throwsInvalidAudio() async throws {
        guard #available(macOS 26.0, *) else { return }
        let client = SpeechTranscriberClient()
        let tmpFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vox-test-\(UUID().uuidString).txt")
        try Data("not audio data".utf8).write(to: tmpFile)
        defer { try? FileManager.default.removeItem(at: tmpFile) }
        do {
            _ = try await client.transcribe(audioURL: tmpFile)
            Issue.record("Expected STTError.invalidAudio but no error thrown")
        } catch STTError.invalidAudio {
            // expected: AVAudioFile rejects non-audio files
        } catch {
            Issue.record("Expected STTError.invalidAudio, got: \(error)")
        }
    }

    @Test("transcribe empty file throws invalidAudio")
    func test_transcribe_emptyFile_throwsInvalidAudio() async throws {
        guard #available(macOS 26.0, *) else { return }
        let client = SpeechTranscriberClient()
        let tmpFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vox-test-\(UUID().uuidString).caf")
        try Data().write(to: tmpFile)
        defer { try? FileManager.default.removeItem(at: tmpFile) }
        do {
            _ = try await client.transcribe(audioURL: tmpFile)
            Issue.record("Expected STTError.invalidAudio but no error thrown")
        } catch STTError.invalidAudio {
            // expected: AVAudioFile rejects zero-byte files
        } catch {
            Issue.record("Expected STTError.invalidAudio, got: \(error)")
        }
    }
}
#endif
