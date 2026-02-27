import Foundation
import VoxCore
import VoxProviders
import XCTest

final class ElevenLabsClientErrorTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    // MARK: - Error status codes

    func test_transcribe_throwsAuthOnHTTP401() async throws {
        let audioURL = makeAudioFile(ext: "caf")
        defer { try? FileManager.default.removeItem(at: audioURL) }

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil
            )!
            return (response, Data())
        }

        let client = ElevenLabsClient(apiKey: "bad-key", session: makeStubbedSession())
        do {
            _ = try await client.transcribe(audioURL: audioURL)
            XCTFail("Expected STTError.auth")
        } catch let error as STTError {
            XCTAssertEqual(error, .auth)
        }
    }

    func test_transcribe_throwsThrottledOnHTTP429() async throws {
        let audioURL = makeAudioFile(ext: "caf")
        defer { try? FileManager.default.removeItem(at: audioURL) }

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil
            )!
            return (response, Data())
        }

        let client = ElevenLabsClient(apiKey: "test-key", session: makeStubbedSession())
        do {
            _ = try await client.transcribe(audioURL: audioURL)
            XCTFail("Expected STTError.throttled")
        } catch let error as STTError {
            XCTAssertEqual(error, .throttled)
        }
    }

    func test_transcribe_throwsUnknownOnHTTP500() async throws {
        let audioURL = makeAudioFile(ext: "caf")
        defer { try? FileManager.default.removeItem(at: audioURL) }

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(#"{"error":"server error"}"#.utf8))
        }

        let client = ElevenLabsClient(apiKey: "test-key", session: makeStubbedSession())
        do {
            _ = try await client.transcribe(audioURL: audioURL)
            XCTFail("Expected STTError.unknown")
        } catch let error as STTError {
            if case .unknown(let msg) = error {
                XCTAssertTrue(msg.contains("500"), "Error message should contain status code")
            } else {
                XCTFail("Expected .unknown, got \(error)")
            }
        }
    }

    // MARK: - MIME type mapping (assert inside handler, avoiding Sendable capture)

    func test_transcribe_cafUsesAudioXCafContentType() async throws {
        try await assertMimeType(forExtension: "caf", expected: "audio/x-caf")
    }

    func test_transcribe_wavUsesAudioWavContentType() async throws {
        try await assertMimeType(forExtension: "wav", expected: "audio/wav")
    }

    func test_transcribe_mp3UsesAudioMpegContentType() async throws {
        try await assertMimeType(forExtension: "mp3", expected: "audio/mpeg")
    }

    func test_transcribe_m4aUsesAudioMp4ContentType() async throws {
        try await assertMimeType(forExtension: "m4a", expected: "audio/mp4")
    }

    func test_transcribe_opusUsesAudioOggContentType() async throws {
        try await assertMimeType(forExtension: "opus", expected: "audio/ogg")
    }

    // MARK: - Helpers

    private func assertMimeType(forExtension ext: String, expected: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        let audioURL = makeAudioFile(ext: ext)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let expectedMime = expected
        URLProtocolStub.requestHandler = { request in
            let body = String(decoding: bodyData(from: request), as: UTF8.self)
            XCTAssertTrue(
                body.contains("Content-Type: \(expectedMime)"),
                "Expected multipart file part Content-Type to be \(expectedMime), body was: \(body.prefix(500))",
                file: file, line: line
            )
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(#"{"text":"ok"}"#.utf8))
        }

        let client = ElevenLabsClient(apiKey: "test-key", session: makeStubbedSession())
        _ = try await client.transcribe(audioURL: audioURL)
    }

    private func makeAudioFile(ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        // swiftlint:disable:next force_try
        try! Data([0x00, 0x01, 0x02, 0x03]).write(to: url)
        return url
    }
}
