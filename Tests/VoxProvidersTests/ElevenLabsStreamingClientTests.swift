import Foundation
@testable import VoxCore
@testable import VoxProviders
import XCTest

final class ElevenLabsStreamingClientTests: XCTestCase {
    func test_makeSession_missingAPIKey_throwsConnectionFailed() async {
        let client = ElevenLabsStreamingClient(apiKey: "")

        do {
            _ = try await client.makeSession()
            XCTFail("Expected missing API key error")
        } catch let error as StreamingSTTError {
            XCTAssertEqual(error, .connectionFailed("ElevenLabs API key is missing"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_finish_sendsCommitAndReturnsCommittedTranscript() async throws {
        let transport = MockElevenLabsWebSocketTransport(
            messages: [
                "{\"message_type\":\"partial_transcript\",\"text\":\"hello\"}",
            ],
            postCommitMessages: [
                "{\"message_type\":\"committed_transcript\",\"text\":\"hello world\"}",
            ]
        )
        let client = ElevenLabsStreamingClient(
            apiKey: "test-key",
            sessionFinalizationTimeout: 0.5,
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
        // Verify commit message was sent
        XCTAssertEqual(transport.sentTextCount, 2) // 1 audio chunk + 1 commit
        XCTAssertTrue(transport.lastSentText.contains("\"commit\":true"))
        XCTAssertTrue(transport.didConnect)
        XCTAssertTrue(transport.didClose)
    }

    func test_partialTranscripts_yieldedCorrectly() async throws {
        let transport = MockElevenLabsWebSocketTransport(
            messages: [
                "{\"message_type\":\"partial_transcript\",\"text\":\"he\"}",
                "{\"message_type\":\"partial_transcript\",\"text\":\"hello\"}",
                "{\"message_type\":\"partial_transcript\",\"text\":\"hello wor\"}",
            ],
            postCommitMessages: [
                "{\"message_type\":\"committed_transcript\",\"text\":\"hello world\"}",
            ]
        )
        let client = ElevenLabsStreamingClient(
            apiKey: "test-key",
            sessionFinalizationTimeout: 0.5,
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        let partialTask = Task { () -> [PartialTranscript] in
            var partials: [PartialTranscript] = []
            for await partial in session.partialTranscripts {
                partials.append(partial)
                if partial.isFinal { break }
            }
            return partials
        }

        try await session.sendAudioChunk(AudioChunk(pcm16LEData: Data([0x01, 0x02])))
        let transcript = try await session.finish()
        let partials = await partialTask.value

        XCTAssertEqual(transcript, "hello world")
        XCTAssertEqual(partials.map(\.text), ["he", "hello", "hello wor", "hello world"])
        XCTAssertEqual(partials.last?.isFinal, true)
    }

    func test_errorMessages_mappedToStreamingSTTError() async throws {
        let transport = MockElevenLabsWebSocketTransport(
            messages: [
                "{\"message_type\":\"error\",\"error_type\":\"auth_error\",\"error_message\":\"Invalid API key\"}",
            ]
        )
        let client = ElevenLabsStreamingClient(
            apiKey: "test-key",
            sessionFinalizationTimeout: 0.5,
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        try await session.sendAudioChunk(AudioChunk(pcm16LEData: Data([0x01, 0x02])))
        // Allow receive loop to process the error
        try await Task.sleep(nanoseconds: 50_000_000)

        do {
            _ = try await session.finish()
            XCTFail("Expected auth error")
        } catch let error as StreamingSTTError {
            XCTAssertEqual(error, .connectionFailed("Invalid API key"))
        }
    }

    func test_quotaExceeded_mappedToProviderError() async throws {
        let transport = MockElevenLabsWebSocketTransport(
            messages: [
                "{\"message_type\":\"error\",\"error_type\":\"quota_exceeded\",\"error_message\":\"Monthly quota exceeded\"}",
            ]
        )
        let client = ElevenLabsStreamingClient(
            apiKey: "test-key",
            sessionFinalizationTimeout: 0.5,
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        try await Task.sleep(nanoseconds: 50_000_000)

        do {
            _ = try await session.finish()
            XCTFail("Expected provider error")
        } catch let error as StreamingSTTError {
            XCTAssertEqual(error, .provider("Monthly quota exceeded"))
        }
    }

    func test_cancel_closesTransport() async throws {
        let transport = MockElevenLabsWebSocketTransport(
            messages: [],
            holdReceiveForever: true
        )
        let client = ElevenLabsStreamingClient(
            apiKey: "test-key",
            sessionFinalizationTimeout: 0.5,
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        try await session.sendAudioChunk(AudioChunk(pcm16LEData: Data([0x01, 0x02])))
        await session.cancel()

        XCTAssertTrue(transport.didClose)
    }

    func test_finish_timeout_withPartials_returnsLatestPartial() async throws {
        let transport = MockElevenLabsWebSocketTransport(
            messages: [
                "{\"message_type\":\"partial_transcript\",\"text\":\"hello wor\"}",
            ],
            holdAfterDrained: true
        )
        let client = ElevenLabsStreamingClient(
            apiKey: "test-key",
            sessionFinalizationTimeout: 0.2,
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        try await session.sendAudioChunk(AudioChunk(pcm16LEData: Data([0x01, 0x02])))
        try await Task.sleep(nanoseconds: 50_000_000)

        let transcript = try await session.finish()
        XCTAssertEqual(transcript, "hello wor")
    }

    func test_finish_timeout_noTranscript_throwsFinalizationTimeout() async throws {
        let transport = MockElevenLabsWebSocketTransport(
            messages: [],
            holdReceiveForever: true
        )
        let client = ElevenLabsStreamingClient(
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
    func test_midSessionAutoCommit_accumulatesSegments() async throws {
        // Server auto-commits first segment (silence boundary), then our commit gets the rest
        let transport = MockElevenLabsWebSocketTransport(
            messages: [
                "{\"message_type\":\"partial_transcript\",\"text\":\"hello world\"}",
                "{\"message_type\":\"committed_transcript\",\"text\":\"hello world\"}",
                "{\"message_type\":\"partial_transcript\",\"text\":\"how are you\"}",
            ],
            postCommitMessages: [
                "{\"message_type\":\"committed_transcript\",\"text\":\"how are you today\"}",
            ]
        )
        let client = ElevenLabsStreamingClient(
            apiKey: "test-key",
            sessionFinalizationTimeout: 0.5,
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        try await session.sendAudioChunk(AudioChunk(pcm16LEData: Data([0x01, 0x02])))
        // Allow receive loop to process pre-commit messages
        try await Task.sleep(nanoseconds: 100_000_000)

        let transcript = try await session.finish()
        XCTAssertEqual(transcript, "hello world how are you today")
    }

    func test_multipleAutoCommits_allAccumulated() async throws {
        // Three server-initiated auto-commits before our finalization commit
        let transport = MockElevenLabsWebSocketTransport(
            messages: [
                "{\"message_type\":\"committed_transcript\",\"text\":\"segment one\"}",
                "{\"message_type\":\"committed_transcript\",\"text\":\"segment two\"}",
                "{\"message_type\":\"committed_transcript\",\"text\":\"segment three\"}",
            ],
            postCommitMessages: [
                "{\"message_type\":\"committed_transcript\",\"text\":\"segment four\"}",
            ]
        )
        let client = ElevenLabsStreamingClient(
            apiKey: "test-key",
            sessionFinalizationTimeout: 0.5,
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        try await session.sendAudioChunk(AudioChunk(pcm16LEData: Data([0x01, 0x02])))
        // Allow receive loop to process auto-commits
        try await Task.sleep(nanoseconds: 100_000_000)

        let transcript = try await session.finish()
        XCTAssertEqual(transcript, "segment one segment two segment three segment four")
    }

    func test_timeout_withAccumulatedCommits_returnsSegments() async throws {
        // Auto-commits accumulated, but our finalization commit times out
        let transport = MockElevenLabsWebSocketTransport(
            messages: [
                "{\"message_type\":\"committed_transcript\",\"text\":\"first part\"}",
                "{\"message_type\":\"committed_transcript\",\"text\":\"second part\"}",
            ],
            holdAfterDrained: true
        )
        let client = ElevenLabsStreamingClient(
            apiKey: "test-key",
            sessionFinalizationTimeout: 0.2,
            transportFactory: { _ in transport }
        )

        let session = try await client.makeSession()
        try await session.sendAudioChunk(AudioChunk(pcm16LEData: Data([0x01, 0x02])))
        try await Task.sleep(nanoseconds: 100_000_000)

        let transcript = try await session.finish()
        XCTAssertEqual(transcript, "first part second part")
    }
}

private final class MockElevenLabsWebSocketTransport: ElevenLabsWebSocketTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var queuedMessages: [String]
    private var postCommitMessages: [String]
    private let holdReceiveForever: Bool
    private let holdAfterDrained: Bool
    private var commitReceived = false
    private(set) var didConnect = false
    private(set) var didClose = false
    private var sentTextList: [String] = []

    init(
        messages: [String],
        postCommitMessages: [String] = [],
        holdReceiveForever: Bool = false,
        holdAfterDrained: Bool = false
    ) {
        self.queuedMessages = messages
        self.postCommitMessages = postCommitMessages
        self.holdReceiveForever = holdReceiveForever
        self.holdAfterDrained = holdAfterDrained
    }

    var sentTextCount: Int {
        lock.withLock { sentTextList.count }
    }

    var lastSentText: String {
        lock.withLock { sentTextList.last ?? "" }
    }

    func connect() async throws {
        didConnect = true
    }

    func sendText(_ text: String) async throws {
        lock.withLock {
            sentTextList.append(text)
            if text.contains("\"commit\":true") && !commitReceived {
                commitReceived = true
                queuedMessages.append(contentsOf: postCommitMessages)
                postCommitMessages.removeAll()
            }
        }
    }

    func receive() async throws -> String {
        if holdReceiveForever {
            while true {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }

        while true {
            try Task.checkCancellation()
            let (msg, shouldWait) = lock.withLock {
                () -> (String?, Bool) in
                if !queuedMessages.isEmpty {
                    return (queuedMessages.removeFirst(), false)
                }
                let waitForCommit = !commitReceived && !postCommitMessages.isEmpty
                return (nil, waitForCommit || holdAfterDrained)
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
