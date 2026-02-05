import Foundation
import VoxProviders
import XCTest

final class WhisperClientTests: XCTestCase {
    func test_transcribe_rejectsFilesOver25MB() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Create a 26MB file (over the 25MB Whisper limit)
        let handle = try FileHandle(forWritingTo: { () -> URL in
            FileManager.default.createFile(atPath: tempURL.path, contents: nil)
            return tempURL
        }())
        try handle.truncate(atOffset: 26_000_001)
        try handle.close()

        // Use a dummy API key — the size check should fire before any network call
        let client = WhisperClient(apiKey: "sk-test-dummy")

        do {
            _ = try await client.transcribe(audioURL: tempURL)
            XCTFail("Expected error for oversized file")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(
                message.contains("25MB"),
                "Expected 25MB limit error, got: \(message)"
            )
        }
    }
}
