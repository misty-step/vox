import Foundation
import VoxCore

protocol ElevenLabsWebSocketTransport: Sendable {
    func connect() async throws
    func sendText(_ text: String) async throws
    func receive() async throws -> String
    func close()
}

public final class ElevenLabsStreamingClient: StreamingSTTProvider {
    private let apiKey: String
    private let sessionFinalizationTimeout: TimeInterval
    private let transportFactory: @Sendable (URLRequest) -> any ElevenLabsWebSocketTransport

    public convenience init(
        apiKey: String,
        session: URLSession = .shared
    ) {
        self.init(
            apiKey: apiKey,
            sessionFinalizationTimeout: 5.0,
            transportFactory: { request in
                URLSessionElevenLabsTransport(task: session.webSocketTask(with: request))
            }
        )
    }

    init(
        apiKey: String,
        sessionFinalizationTimeout: TimeInterval = 5.0,
        transportFactory: @escaping @Sendable (URLRequest) -> any ElevenLabsWebSocketTransport
    ) {
        self.apiKey = apiKey
        self.sessionFinalizationTimeout = sessionFinalizationTimeout
        self.transportFactory = transportFactory
    }

    public func makeSession() async throws -> any StreamingSTTSession {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StreamingSTTError.connectionFailed("ElevenLabs API key is missing")
        }
        var components = URLComponents(string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime")!
        components.queryItems = [
            URLQueryItem(name: "model_id", value: "scribe_v2_realtime"),
            URLQueryItem(name: "audio_format", value: "pcm_16000"),
            URLQueryItem(name: "commit_strategy", value: "manual"),
        ]
        guard let url = components.url else {
            throw StreamingSTTError.connectionFailed("Invalid ElevenLabs WebSocket URL")
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        let transport = transportFactory(request)
        do {
            try await transport.connect()
        } catch {
            throw StreamingSTTError.connectionFailed(error.localizedDescription)
        }
        return ElevenLabsStreamingSession(
            transport: transport,
            finalizationTimeout: sessionFinalizationTimeout
        )
    }
}

private final class URLSessionElevenLabsTransport: ElevenLabsWebSocketTransport, @unchecked Sendable {
    private let task: URLSessionWebSocketTask

    init(task: URLSessionWebSocketTask) {
        self.task = task
    }

    func connect() async throws {
        task.resume()
    }

    func sendText(_ text: String) async throws {
        try await task.send(.string(text))
    }

    func receive() async throws -> String {
        let message = try await task.receive()
        switch message {
        case .string(let text):
            return text
        case .data(let data):
            return String(data: data, encoding: .utf8) ?? ""
        @unknown default:
            return ""
        }
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
    }
}

private actor ElevenLabsStreamingSession: StreamingSTTSession {
    nonisolated let partialTranscripts: AsyncStream<PartialTranscript>

    private let transport: any ElevenLabsWebSocketTransport
    private let continuation: AsyncStream<PartialTranscript>.Continuation
    private let finalizationTimeout: TimeInterval
    private var receiveTask: Task<Void, Never>?
    private var latestPartial: String = ""
    private var committedSegments: [String] = []
    private var receiveError: StreamingSTTError?
    private var sendError: StreamingSTTError?
    private var commitSent = false
    private var finished = false
    private var receiveLoopCompleted = false

    init(
        transport: any ElevenLabsWebSocketTransport,
        finalizationTimeout: TimeInterval = 5.0
    ) {
        self.transport = transport
        self.finalizationTimeout = finalizationTimeout
        var continuation: AsyncStream<PartialTranscript>.Continuation?
        self.partialTranscripts = AsyncStream<PartialTranscript> { streamContinuation in
            continuation = streamContinuation
        }
        self.continuation = continuation!
        Task {
            await ensureReceiveLoopStarted()
        }
    }

    func sendAudioChunk(_ chunk: AudioChunk) async throws {
        ensureReceiveLoopStarted()
        guard !finished else {
            throw StreamingSTTError.invalidState("Cannot send chunk after finish")
        }
        if let sendError {
            throw sendError
        }
        let base64 = chunk.pcm16LEData.base64EncodedString()
        let json = """
        {"message_type":"input_audio_chunk","audio_base_64":"\(base64)","commit":false,"sample_rate":\(chunk.sampleRate)}
        """
        do {
            try await transport.sendText(json)
        } catch is CancellationError {
            let error = StreamingSTTError.cancelled
            sendError = error
            throw error
        } catch {
            let error = StreamingSTTError.sendFailed(error.localizedDescription)
            sendError = error
            throw error
        }
    }

    func finish() async throws -> String {
        ensureReceiveLoopStarted()
        guard !finished else {
            throw StreamingSTTError.invalidState("finish() already called")
        }
        finished = true
        commitSent = true

        if let sendError {
            throw sendError
        }
        // Send commit message — ElevenLabs guarantees a committed_transcript response
        let commitJSON = """
        {"message_type":"input_audio_chunk","audio_base_64":"","commit":true,"sample_rate":16000}
        """
        do {
            try await transport.sendText(commitJSON)
        } catch is CancellationError {
            throw StreamingSTTError.cancelled
        } catch {
            throw StreamingSTTError.sendFailed(error.localizedDescription)
        }

        do {
            try await awaitReceiveLoop(timeout: finalizationTimeout)
        } catch {
            transport.close()
            continuation.finish()

            // Recover accumulated committed segments first, then partials
            let assembled = committedSegments.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !assembled.isEmpty {
                print("[ElevenLabs] Commit timed out, returning accumulated segments (\(assembled.count) chars)")
                return assembled
            }
            let partialFallback = latestPartial.trimmingCharacters(in: .whitespacesAndNewlines)
            if !partialFallback.isEmpty {
                print("[ElevenLabs] Commit timed out, returning latest partial (\(partialFallback.count) chars)")
                return partialFallback
            }
            throw error
        }

        transport.close()
        continuation.finish()

        if let receiveError {
            throw receiveError
        }

        let assembled = committedSegments.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if !assembled.isEmpty {
            return assembled
        }
        let fallback = latestPartial.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallback.isEmpty {
            return fallback
        }
        throw VoxError.noTranscript
    }

    func cancel() async {
        ensureReceiveLoopStarted()
        if finished { return }
        finished = true
        receiveTask?.cancel()
        transport.close()
        continuation.finish()
    }

    private func ensureReceiveLoopStarted() {
        guard receiveTask == nil else { return }
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            do {
                let text = try await transport.receive()
                if handleTextMessage(text) {
                    continuation.finish()
                    receiveLoopCompleted = true
                    return
                }
            } catch is CancellationError {
                continuation.finish()
                receiveLoopCompleted = true
                return
            } catch {
                receiveError = .receiveFailed(error.localizedDescription)
                continuation.finish()
                receiveLoopCompleted = true
                return
            }
        }
        receiveLoopCompleted = true
    }

    private func handleTextMessage(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        let messageType = object["message_type"] as? String

        // Error responses
        if messageType == "error" {
            let errorType = object["error_type"] as? String ?? "unknown"
            let detail = object["error_message"] as? String ?? errorType
            switch errorType {
            case "auth_error":
                receiveError = .connectionFailed(detail)
            case "quota_exceeded", "rate_limited":
                receiveError = .provider(detail)
            default:
                receiveError = .provider(detail)
            }
            return true
        }

        // Partial transcript
        if messageType == "partial_transcript" {
            if let transcript = object["text"] as? String {
                let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    latestPartial = trimmed
                    continuation.yield(PartialTranscript(text: trimmed, isFinal: false))
                }
            }
            return false
        }

        // Committed transcript — may arrive mid-session (auto-commit on silence/safety valve)
        // or as response to our manual commit. Only stop loop on OUR commit response.
        if messageType == "committed_transcript" {
            if let transcript = object["text"] as? String {
                let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    committedSegments.append(trimmed)
                    continuation.yield(PartialTranscript(text: trimmed, isFinal: true))
                }
            }
            return commitSent
        }

        return false
    }

    private func awaitReceiveLoop(timeout: TimeInterval) async throws {
        guard receiveTask != nil else { return }
        let timeoutNanoseconds = try validatedTimeoutNanoseconds(seconds: timeout)
        let sleepInterval: UInt64 = 10_000_000
        var waited: UInt64 = 0
        while !receiveLoopCompleted {
            if waited >= timeoutNanoseconds {
                receiveTask?.cancel()
                throw StreamingSTTError.finalizationTimeout
            }
            try? await Task.sleep(nanoseconds: sleepInterval)
            waited += sleepInterval
        }
        if !receiveLoopCompleted {
            receiveTask?.cancel()
            throw StreamingSTTError.finalizationTimeout
        }
    }
}

private func validatedTimeoutNanoseconds(seconds: TimeInterval) throws -> UInt64 {
    guard seconds > 0, seconds.isFinite else {
        throw StreamingSTTError.invalidState("Invalid timeout: \(seconds)")
    }
    let nanoseconds = seconds * 1_000_000_000
    guard nanoseconds.isFinite, nanoseconds >= 0, nanoseconds < Double(UInt64.max) else {
        throw StreamingSTTError.invalidState("Invalid timeout: \(seconds)")
    }
    return UInt64(nanoseconds)
}
