import Foundation
import VoxCore
@testable import VoxProviders
import XCTest

final class DeepgramClientErrorTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    // MARK: - Error status codes

    func test_transcribe_throwsInvalidAudioOnHTTP400() async throws {
        let audioURL = makeAudioFile(ext: "wav")
        defer { try? FileManager.default.removeItem(at: audioURL) }

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(#"{"error":"bad audio"}"#.utf8))
        }

        let client = DeepgramClient(apiKey: "test-key", session: makeStubbedSession())
        do {
            _ = try await client.transcribe(audioURL: audioURL)
            XCTFail("Expected STTError.invalidAudio")
        } catch let error as STTError {
            XCTAssertEqual(error, .invalidAudio)
        }
    }

    func test_transcribe_throwsAuthOnHTTP401() async throws {
        let audioURL = makeAudioFile(ext: "wav")
        defer { try? FileManager.default.removeItem(at: audioURL) }

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil
            )!
            return (response, Data())
        }

        let client = DeepgramClient(apiKey: "bad-key", session: makeStubbedSession())
        do {
            _ = try await client.transcribe(audioURL: audioURL)
            XCTFail("Expected STTError.auth")
        } catch let error as STTError {
            XCTAssertEqual(error, .auth)
        }
    }

    func test_transcribe_throwsQuotaExceededOnHTTP402() async throws {
        let audioURL = makeAudioFile(ext: "wav")
        defer { try? FileManager.default.removeItem(at: audioURL) }

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 402, httpVersion: nil, headerFields: nil
            )!
            return (response, Data())
        }

        let client = DeepgramClient(apiKey: "test-key", session: makeStubbedSession())
        do {
            _ = try await client.transcribe(audioURL: audioURL)
            XCTFail("Expected STTError.quotaExceeded")
        } catch let error as STTError {
            XCTAssertEqual(error, .quotaExceeded)
        }
    }

    func test_transcribe_throwsQuotaExceededOnHTTP403() async throws {
        let audioURL = makeAudioFile(ext: "wav")
        defer { try? FileManager.default.removeItem(at: audioURL) }

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil
            )!
            return (response, Data())
        }

        let client = DeepgramClient(apiKey: "test-key", session: makeStubbedSession())
        do {
            _ = try await client.transcribe(audioURL: audioURL)
            XCTFail("Expected STTError.quotaExceeded")
        } catch let error as STTError {
            XCTAssertEqual(error, .quotaExceeded)
        }
    }

    func test_transcribe_throwsThrottledOnHTTP429() async throws {
        let audioURL = makeAudioFile(ext: "wav")
        defer { try? FileManager.default.removeItem(at: audioURL) }

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil
            )!
            return (response, Data())
        }

        let client = DeepgramClient(apiKey: "test-key", session: makeStubbedSession())
        do {
            _ = try await client.transcribe(audioURL: audioURL)
            XCTFail("Expected STTError.throttled")
        } catch let error as STTError {
            XCTAssertEqual(error, .throttled)
        }
    }

    func test_transcribe_throwsUnknownOnHTTP500() async throws {
        let audioURL = makeAudioFile(ext: "wav")
        defer { try? FileManager.default.removeItem(at: audioURL) }

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(#"{"error":"server"}"#.utf8))
        }

        let client = DeepgramClient(apiKey: "test-key", session: makeStubbedSession())
        do {
            _ = try await client.transcribe(audioURL: audioURL)
            XCTFail("Expected STTError.unknown")
        } catch let error as STTError {
            if case .unknown(let msg) = error {
                XCTAssertTrue(msg.contains("500"))
            } else {
                XCTFail("Expected .unknown, got \(error)")
            }
        }
    }

    // MARK: - CAF conversion failure maps to invalidAudio

    func test_transcribe_cafConversionFailureThrowsInvalidAudio() async throws {
        let cafURL = makeAudioFile(ext: "caf")
        defer { try? FileManager.default.removeItem(at: cafURL) }

        let client = DeepgramClient(
            apiKey: "test-key",
            session: makeStubbedSession(),
            convertCAFToWAV: { _ in throw NSError(domain: "test", code: 1) }
        )
        do {
            _ = try await client.transcribe(audioURL: cafURL)
            XCTFail("Expected STTError.invalidAudio")
        } catch let error as STTError {
            XCTAssertEqual(error, .invalidAudio)
        }
    }

    // MARK: - MIME type mapping

    func test_mimeType_wavReturnsAudioWav() {
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        XCTAssertEqual(DeepgramClient.mimeType(for: url), "audio/wav")
    }

    func test_mimeType_m4aReturnsAudioMp4() {
        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        XCTAssertEqual(DeepgramClient.mimeType(for: url), "audio/mp4")
    }

    func test_mimeType_mp3ReturnsAudioMpeg() {
        let url = URL(fileURLWithPath: "/tmp/test.mp3")
        XCTAssertEqual(DeepgramClient.mimeType(for: url), "audio/mpeg")
    }

    func test_mimeType_oggReturnsAudioOgg() {
        let url = URL(fileURLWithPath: "/tmp/test.ogg")
        XCTAssertEqual(DeepgramClient.mimeType(for: url), "audio/ogg")
    }

    func test_mimeType_opusReturnsAudioOgg() {
        let url = URL(fileURLWithPath: "/tmp/test.opus")
        XCTAssertEqual(DeepgramClient.mimeType(for: url), "audio/ogg")
    }

    func test_mimeType_unknownReturnsOctetStream() {
        let url = URL(fileURLWithPath: "/tmp/test.xyz")
        XCTAssertEqual(DeepgramClient.mimeType(for: url), "application/octet-stream")
    }

    // MARK: - Helpers

    private func makeAudioFile(ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        // swiftlint:disable:next force_try
        try! Data([0x00, 0x01, 0x02, 0x03]).write(to: url)
        return url
    }
}
