import Foundation
@testable import VoxCore
@testable import VoxProviders
import XCTest

final class DeepgramStreamingClientTests: XCTestCase {
    func test_makeSession_missingAPIKey_throwsConnectionFailed() async {
        let client = DeepgramStreamingClient(apiKey: "")

        do {
            _ = try await client.makeSession()
            XCTFail("Expected missing API key error")
        } catch let error as StreamingSTTError {
            XCTAssertEqual(error, .connectionFailed("Deepgram API key is missing"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_finish_returnsFinalTranscriptAndSendsFinalizeSignal() async throws {
        let transport = MockDeepgramWebSocketTransport(messages: [
            .text("{\"channel\":{\"alternatives\":[{\"transcript\":\"hello\"}]},\"is_final\":false}"),
            .text("{\"channel\":{\"alternatives\":[{\"transcript\":\"hello world\"}]},\"is_final\":true}"),
        ])
        let client = DeepgramStreamingClient(
            apiKey: "test-key",
            sessionFinalizationTimeout: 0.2,
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        let partialTask = Task { () -> [PartialTranscript] in
            var partials: [PartialTranscript] = []
            for await partial in session.partialTranscripts {
                partials.append(partial)
                if partials.count == 2 {
                    break
                }
            }
            return partials
        }

        try await session.sendAudioChunk(
            AudioChunk(
                pcm16LEData: Data([0x01, 0x02, 0x03, 0x04]),
                sampleRate: 16_000,
                channels: 1
            )
        )
        let transcript = try await session.finish()
        let partials = await partialTask.value

        XCTAssertEqual(transcript, "hello world")
        XCTAssertEqual(partials.map(\.text), ["hello", "hello world"])
        XCTAssertEqual(partials.map(\.isFinal), [false, true])
        XCTAssertEqual(transport.sentDataCount, 1)
        XCTAssertEqual(transport.sentTexts, ["{\"type\":\"Finalize\"}"])
        XCTAssertTrue(transport.didConnect)
        XCTAssertTrue(transport.didClose)
    }

    func test_finish_timeout_throwsFinalizationTimeout() async throws {
        let transport = MockDeepgramWebSocketTransport(messages: [], holdReceiveForever: true)
        let client = DeepgramStreamingClient(
            apiKey: "test-key",
            sessionFinalizationTimeout: 0.05,
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        try await session.sendAudioChunk(AudioChunk(pcm16LEData: Data([0xAA, 0xBB])))

        do {
            _ = try await session.finish()
            XCTFail("Expected finalization timeout")
        } catch let error as StreamingSTTError {
            XCTAssertEqual(error, .finalizationTimeout)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class MockDeepgramWebSocketTransport: DeepgramWebSocketTransport, @unchecked Sendable {
    private var queuedMessages: [DeepgramWebSocketMessage]
    private let holdReceiveForever: Bool
    private(set) var didConnect = false
    private(set) var didClose = false
    private(set) var sentTexts: [String] = []
    private var sentDataPayloads: [Data] = []

    init(messages: [DeepgramWebSocketMessage], holdReceiveForever: Bool = false) {
        self.queuedMessages = messages
        self.holdReceiveForever = holdReceiveForever
    }

    var sentDataCount: Int {
        return sentDataPayloads.count
    }

    func connect() async throws {
        didConnect = true
    }

    func sendData(_ data: Data) async throws {
        sentDataPayloads.append(data)
    }

    func sendText(_ text: String) async throws {
        sentTexts.append(text)
    }

    func receive() async throws -> DeepgramWebSocketMessage {
        if holdReceiveForever {
            while true {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }

        if queuedMessages.isEmpty {
            throw StreamingSTTError.receiveFailed("No queued messages")
        }
        return queuedMessages.removeFirst()
    }

    func close() {
        didClose = true
    }
}
