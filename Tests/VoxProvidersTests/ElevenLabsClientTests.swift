import Foundation
import VoxProviders
import XCTest

final class ElevenLabsClientTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func test_transcribe_oggUsesAudioOggMultipartPart() async throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("ogg")
        defer { try? FileManager.default.removeItem(at: audioURL) }
        try Data([0x4F, 0x67, 0x67, 0x53]).write(to: audioURL)

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

        let client = ElevenLabsClient(apiKey: "test-key", session: makeStubbedSession())
        let transcript = try await client.transcribe(audioURL: audioURL)
        XCTAssertEqual(transcript, "ok")
    }
}
