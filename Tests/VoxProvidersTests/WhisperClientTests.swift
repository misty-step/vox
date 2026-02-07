import Foundation
import VoxProviders
import XCTest

final class WhisperClientTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func test_transcribe_oggUsesAudioOggMultipartPart() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("ogg")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try Data([0x4F, 0x67, 0x67, 0x53]).write(to: tempURL)

        URLProtocolStub.requestHandler = { request in
            let body = String(decoding: bodyData(from: request), as: UTF8.self)
            XCTAssertTrue(
                body.contains("Content-Type: audio/ogg"),
                "Expected multipart file part Content-Type to be audio/ogg"
            )
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"text":"ok"}"#.utf8))
        }

        let client = WhisperClient(apiKey: "sk-test", session: makeStubbedSession())
        let transcript = try await client.transcribe(audioURL: tempURL)
        XCTAssertEqual(transcript, "ok")
    }

    func test_transcribe_cafConvertsToWavForMultipartUpload() async throws {
        let cafURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        defer { try? FileManager.default.removeItem(at: cafURL) }
        try Data([0x43, 0x41, 0x46, 0x46]).write(to: cafURL)

        let wavURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: wavURL)

        URLProtocolStub.requestHandler = { request in
            let body = String(decoding: bodyData(from: request), as: UTF8.self)
            XCTAssertTrue(
                body.contains("Content-Type: audio/wav"),
                "Expected multipart file part Content-Type to be audio/wav"
            )
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"text":"ok"}"#.utf8))
        }

        let client = WhisperClient(
            apiKey: "sk-test",
            session: makeStubbedSession(),
            convertCAFToWAV: { _ in wavURL }
        )
        let transcript = try await client.transcribe(audioURL: cafURL)

        XCTAssertEqual(transcript, "ok")
        XCTAssertFalse(FileManager.default.fileExists(atPath: wavURL.path))
    }

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
