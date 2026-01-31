import Foundation
import VoxProviders
import XCTest

final class DeepgramClientTests: XCTestCase {
    func testTranscribeCAFFile() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"], !apiKey.isEmpty else {
            throw XCTSkip("DEEPGRAM_API_KEY not set")
        }

        let tempDir = FileManager.default.temporaryDirectory
        let cafURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
        defer { try? FileManager.default.removeItem(at: cafURL) }

        // Create silent CAF using ffmpeg (more reliable than AVAudioFile).
        try createSilentCAF(at: cafURL)

        let client = DeepgramClient(apiKey: apiKey)
        let transcript = try await client.transcribe(audioURL: cafURL)

        XCTAssertTrue(transcript.count < 10, "Expected empty transcript for silence, got: \(transcript)")
    }

    private func createSilentCAF(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        process.arguments = [
            "-f", "lavfi",
            "-i", "anullsrc=r=16000:cl=mono",
            "-t", "1",
            "-c:a", "pcm_s16le",
            url.path,
            "-y",
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "TestError", code: Int(process.terminationStatus))
        }
    }
}
