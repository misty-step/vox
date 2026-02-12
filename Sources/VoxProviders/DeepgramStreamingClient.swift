import Foundation
import VoxCore

protocol DeepgramWebSocketTransport: Sendable {
    func connect() async throws
    func sendData(_ data: Data) async throws
    func sendText(_ text: String) async throws
    func receive() async throws -> DeepgramWebSocketMessage
    func close()
}

enum DeepgramWebSocketMessage: Sendable {
    case text(String)
    case data(Data)
}

public final class DeepgramStreamingClient: StreamingSTTProvider {
    private let apiKey: String
    private let model: String
    private let sessionFinalizationTimeout: TimeInterval
    private let transportFactory: @Sendable (URLRequest) -> any DeepgramWebSocketTransport

    public convenience init(
        apiKey: String,
        model: String = "nova-3",
        session: URLSession = .shared
    ) {
        self.init(
            apiKey: apiKey,
            model: model,
            sessionFinalizationTimeout: 5.0,
            transportFactory: { request in
                URLSessionWebSocketTransport(task: session.webSocketTask(with: request))
            }
        )
    }

    init(
        apiKey: String,
        model: String = "nova-3",
        sessionFinalizationTimeout: TimeInterval = 5.0,
        transportFactory: @escaping @Sendable (URLRequest) -> any DeepgramWebSocketTransport
    ) {
        self.apiKey = apiKey
        self.model = model
        self.sessionFinalizationTimeout = sessionFinalizationTimeout
        self.transportFactory = transportFactory
    }

    public func makeSession() async throws -> any StreamingSTTSession {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StreamingSTTError.connectionFailed("Deepgram API key is missing")
        }
        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        components.queryItems = [
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "punctuate", value: "true"),
        ]
        guard let url = components.url else {
            throw StreamingSTTError.connectionFailed("Invalid Deepgram WebSocket URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        let transport = transportFactory(request)
        do {
            try await transport.connect()
        } catch {
            throw StreamingSTTError.connectionFailed(error.localizedDescription)
        }
        return DeepgramStreamingSession(
            transport: transport,
            finalizationTimeout: sessionFinalizationTimeout
        )
    }
}

private final class URLSessionWebSocketTransport: DeepgramWebSocketTransport, @unchecked Sendable {
    private let task: URLSessionWebSocketTask

    init(task: URLSessionWebSocketTask) {
        self.task = task
    }

    func connect() async throws {
        task.resume()
    }

    func sendData(_ data: Data) async throws {
        try await task.send(.data(data))
    }

    func sendText(_ text: String) async throws {
        try await task.send(.string(text))
    }

    func receive() async throws -> DeepgramWebSocketMessage {
        let message = try await task.receive()
        switch message {
        case .string(let text):
            return .text(text)
        case .data(let data):
            return .data(data)
        @unknown default:
            return .text("")
        }
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
    }
}

private actor DeepgramStreamingSession: StreamingSTTSession {
    nonisolated let partialTranscripts: AsyncStream<PartialTranscript>

    private let transport: any DeepgramWebSocketTransport
    private let continuation: AsyncStream<PartialTranscript>.Continuation
    private let finalizationTimeout: TimeInterval
    private var receiveTask: Task<Void, Never>?
    private var finalSegments: [String] = []
    private var latestPartial: String = ""
    private var receiveError: StreamingSTTError?
    private var sendError: StreamingSTTError?
    private var finishRequested = false
    private var finished = false
    private var receiveLoopCompleted = false

    init(
        transport: any DeepgramWebSocketTransport,
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
        do {
            try await transport.sendData(chunk.pcm16LEData)
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
        finishRequested = true

        if let sendError {
            throw sendError
        }
        do {
            try await transport.sendText("{\"type\":\"Finalize\"}")
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

            // Recover accumulated transcript instead of falling back to batch.
            // During real-time streaming, finalSegments/latestPartial already
            // contain most or all of the transcript — only the trailing words
            // after the Finalize signal may be missing.
            let assembledFinal = finalSegments.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !assembledFinal.isEmpty {
                print("[Deepgram] Finalize timed out, returning accumulated transcript (\(assembledFinal.count) chars)")
                return assembledFinal
            }
            let partialFallback = latestPartial.trimmingCharacters(in: .whitespacesAndNewlines)
            if !partialFallback.isEmpty {
                print("[Deepgram] Finalize timed out, returning latest partial (\(partialFallback.count) chars)")
                return partialFallback
            }
            throw error
        }

        transport.close()
        continuation.finish()

        if let receiveError {
            throw receiveError
        }

        let assembledFinal = finalSegments.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if !assembledFinal.isEmpty {
            return assembledFinal
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
        guard receiveTask == nil else {
            return
        }
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            do {
                let message = try await transport.receive()
                if try await shouldStopReceiving(after: message) {
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

    private func shouldStopReceiving(after message: DeepgramWebSocketMessage) async throws -> Bool {
        switch message {
        case .data:
            return false
        case .text(let text):
            return handleTextMessage(text)
        }
    }

    private func handleTextMessage(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        if let message = object["error"] as? String {
            receiveError = .provider(message)
            return true
        }

        if let transcript = transcript(from: object) {
            let isFinal = (object["is_final"] as? Bool) ?? false
            latestPartial = transcript
            continuation.yield(PartialTranscript(text: transcript, isFinal: isFinal))
            if isFinal {
                finalSegments.append(transcript)
            }
            if finishRequested && isFinal {
                return true
            }
        }

        let type = (object["type"] as? String)?.lowercased()
        if finishRequested && type == "utteranceend" {
            return true
        }
        return false
    }

    private func transcript(from object: [String: Any]) -> String? {
        guard let channel = object["channel"] as? [String: Any],
              let alternatives = channel["alternatives"] as? [[String: Any]],
              let transcript = alternatives.first?["transcript"] as? String else {
            return nil
        }
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func awaitReceiveLoop(timeout: TimeInterval) async throws {
        guard receiveTask != nil else {
            return
        }
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
