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
        // Partial arrives during streaming; final arrives after Finalize (like real Deepgram)
        let transport = MockDeepgramWebSocketTransport(
            messages: [
                .text("{\"channel\":{\"alternatives\":[{\"transcript\":\"hello\"}]},\"is_final\":false}"),
            ],
            postFinalizeMessages: [
                .text("{\"channel\":{\"alternatives\":[{\"transcript\":\"hello world\"}]},\"is_final\":true}"),
                .text("{\"type\":\"Metadata\",\"request_id\":\"test\",\"duration\":1.0}"),
            ]
        )
        let client = DeepgramStreamingClient(
            apiKey: "test-key",
            finalizationTimeoutPolicy: .constant(0.5),
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
        XCTAssertEqual(transport.sentTexts, ["{\"type\":\"CloseStream\"}"])
        XCTAssertTrue(transport.didConnect)
        XCTAssertTrue(transport.didClose)
    }

    func test_finish_timeout_noTranscript_throwsFinalizationTimeout() async throws {
        let transport = MockDeepgramWebSocketTransport(messages: [], holdReceiveForever: true)
        let client = DeepgramStreamingClient(
            apiKey: "test-key",
            finalizationTimeoutPolicy: .constant(0.05),
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

    func test_finish_timeout_withAccumulatedFinals_returnsTranscript() async throws {
        // Simulate real-time streaming: deliver partial + final segments, then hold forever
        let transport = MockDeepgramWebSocketTransport(
            messages: [
                .text("{\"channel\":{\"alternatives\":[{\"transcript\":\"hello\"}]},\"is_final\":true}"),
                .text("{\"channel\":{\"alternatives\":[{\"transcript\":\"world\"}]},\"is_final\":true}"),
            ],
            holdAfterDrained: true
        )
        let client = DeepgramStreamingClient(
            apiKey: "test-key",
            finalizationTimeoutPolicy: .constant(0.2),
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        try await session.sendAudioChunk(AudioChunk(pcm16LEData: Data([0x01, 0x02])))
        // Allow receive loop to consume messages
        try await Task.sleep(nanoseconds: 50_000_000)

        let transcript = try await session.finish()
        XCTAssertEqual(transcript, "hello world")
    }

    func test_finish_stopsOnMetadataMessage() async throws {
        // CloseStream causes Deepgram to send a Metadata message as definitive stop
        let transport = MockDeepgramWebSocketTransport(
            messages: [
                .text("{\"channel\":{\"alternatives\":[{\"transcript\":\"hello\"}]},\"is_final\":true}"),
            ],
            postFinalizeMessages: [
                .text("{\"type\":\"Metadata\",\"request_id\":\"abc\",\"duration\":2.5}"),
            ]
        )
        let client = DeepgramStreamingClient(
            apiKey: "test-key",
            finalizationTimeoutPolicy: .constant(0.5),
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        try await session.sendAudioChunk(AudioChunk(pcm16LEData: Data([0x01, 0x02])))
        try await Task.sleep(nanoseconds: 50_000_000)

        let transcript = try await session.finish()
        XCTAssertEqual(transcript, "hello")
        XCTAssertEqual(transport.sentTexts, ["{\"type\":\"CloseStream\"}"])
    }

    func test_finish_timeout_withOnlyPartials_returnsLatestPartial() async throws {
        // Only non-final partials received before timeout
        let transport = MockDeepgramWebSocketTransport(
            messages: [
                .text("{\"channel\":{\"alternatives\":[{\"transcript\":\"hello wor\"}]},\"is_final\":false}"),
            ],
            holdAfterDrained: true
        )
        let client = DeepgramStreamingClient(
            apiKey: "test-key",
            finalizationTimeoutPolicy: .constant(0.2),
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        try await session.sendAudioChunk(AudioChunk(pcm16LEData: Data([0x01, 0x02])))
        try await Task.sleep(nanoseconds: 50_000_000)

        let transcript = try await session.finish()
        XCTAssertEqual(transcript, "hello wor")
    }
    func test_finish_accumulatesMultipleFinalsAfterCloseStream() async throws {
        // CloseStream triggers two is_final segments then Metadata
        let transport = MockDeepgramWebSocketTransport(
            messages: [
                .text("{\"channel\":{\"alternatives\":[{\"transcript\":\"hello\"}]},\"is_final\":true}"),
            ],
            postFinalizeMessages: [
                .text("{\"channel\":{\"alternatives\":[{\"transcript\":\"world\"}]},\"is_final\":true}"),
                .text("{\"channel\":{\"alternatives\":[{\"transcript\":\"today\"}]},\"is_final\":true}"),
                .text("{\"type\":\"Metadata\",\"request_id\":\"abc\",\"duration\":5.0}"),
            ]
        )
        let client = DeepgramStreamingClient(
            apiKey: "test-key",
            finalizationTimeoutPolicy: .constant(0.5),
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        try await session.sendAudioChunk(AudioChunk(pcm16LEData: Data([0x01, 0x02])))
        try await Task.sleep(nanoseconds: 50_000_000)

        let transcript = try await session.finish()
        // All three finals accumulated: pre-CloseStream + two post-CloseStream
        XCTAssertEqual(transcript, "hello world today")
    }
}

private final class MockDeepgramWebSocketTransport: DeepgramWebSocketTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var queuedMessages: [DeepgramWebSocketMessage]
    private var postFinalizeMessages: [DeepgramWebSocketMessage]
    private let holdReceiveForever: Bool
    private let holdAfterDrained: Bool
    private var finalizeReceived = false
    private(set) var didConnect = false
    private(set) var didClose = false
    private(set) var sentTexts: [String] = []
    private var sentDataPayloads: [Data] = []

    /// - Parameters:
    ///   - messages: Delivered during streaming (before Finalize)
    ///   - postFinalizeMessages: Enqueued after Finalize signal is sent (simulates Deepgram's final response)
    ///   - holdReceiveForever: Block all receives indefinitely
    ///   - holdAfterDrained: Block receives after all queued messages are consumed
    init(
        messages: [DeepgramWebSocketMessage],
        postFinalizeMessages: [DeepgramWebSocketMessage] = [],
        holdReceiveForever: Bool = false,
        holdAfterDrained: Bool = false
    ) {
        self.queuedMessages = messages
        self.postFinalizeMessages = postFinalizeMessages
        self.holdReceiveForever = holdReceiveForever
        self.holdAfterDrained = holdAfterDrained
    }

    var sentDataCount: Int {
        lock.withLock { sentDataPayloads.count }
    }

    func connect() async throws {
        didConnect = true
    }

    func sendData(_ data: Data) async throws {
        lock.withLock { sentDataPayloads.append(data) }
    }

    func sendText(_ text: String) async throws {
        lock.withLock {
            sentTexts.append(text)
            if text.contains("CloseStream") && !finalizeReceived {
                finalizeReceived = true
                queuedMessages.append(contentsOf: postFinalizeMessages)
                postFinalizeMessages.removeAll()
            }
        }
    }

    func receive() async throws -> DeepgramWebSocketMessage {
        if holdReceiveForever {
            while true {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }

        // Poll for messages. When queue is empty, wait if:
        // - postFinalizeMessages are pending (Finalize hasn't arrived yet), or
        // - holdAfterDrained is set
        while true {
            try Task.checkCancellation()
            let (msg, shouldWait) = lock.withLock {
                () -> (DeepgramWebSocketMessage?, Bool) in
                if !queuedMessages.isEmpty {
                    return (queuedMessages.removeFirst(), false)
                }
                let waitForFinalize = !finalizeReceived && !postFinalizeMessages.isEmpty
                return (nil, waitForFinalize || holdAfterDrained)
            }
            if let msg { return msg }
            if shouldWait {
                try await Task.sleep(nanoseconds: 10_000_000)
                continue
            }
            throw StreamingSTTError.receiveFailed("No queued messages")
        }
    }

    func close() {
        didClose = true
    }
}
