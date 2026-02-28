import AppKit
import Foundation
import VoxCore

@MainActor
public final class DebugWorkbenchStore: ObservableObject {
    public struct OutputPane: Equatable {
        public enum State: Equatable {
            case pending
            case ready
            case failed(String)
        }

        public var state: State
        public var text: String

        public static let pending = OutputPane(state: .pending, text: "")
    }

    public enum RequestStatus: String, Equatable {
        case recording
        case processing
        case succeeded
        case failed
        case cancelled
    }

    public struct RequestRecord: Identifiable, Equatable {
        public let id: String
        public let createdAt: Date
        public let processingLevel: ProcessingLevel
        public var status: RequestStatus
        public var raw: OutputPane
        public var clean: OutputPane
        public var polish: OutputPane
        public var logs: [String]
    }

    public static let shared = DebugWorkbenchStore()

    @Published public private(set) var requests: [RequestRecord] = []

    private let maxRequests = 200
    private let maxLogsPerRequest = 150

    public func startRequest(id: String, processingLevel: ProcessingLevel) {
        if requests.contains(where: { $0.id == id }) {
            updateStatus(id: id, status: .recording)
            return
        }

        let record = RequestRecord(
            id: id,
            createdAt: Date(),
            processingLevel: processingLevel,
            status: .recording,
            raw: .pending,
            clean: .pending,
            polish: .pending,
            logs: []
        )
        requests.insert(record, at: 0)
        if requests.count > maxRequests {
            requests.removeLast(requests.count - maxRequests)
        }
    }

    public func updateStatus(id: String, status: RequestStatus) {
        guard let index = indexForRequest(id: id) else { return }
        requests[index].status = status
    }

    public func appendLog(id: String, line: String) {
        guard let index = indexForRequest(id: id) else { return }
        requests[index].logs.append(line)
        if requests[index].logs.count > maxLogsPerRequest {
            requests[index].logs.removeFirst(requests[index].logs.count - maxLogsPerRequest)
        }
    }

    public func setRawTranscript(id: String, text: String) {
        guard let index = indexForRequest(id: id) else { return }
        requests[index].raw = OutputPane(state: .ready, text: text)
    }

    public func setRewrite(id: String, level: ProcessingLevel, text: String) {
        guard let index = indexForRequest(id: id) else { return }
        let pane = OutputPane(state: .ready, text: text)
        switch level {
        case .raw:
            requests[index].raw = pane
        case .clean:
            requests[index].clean = pane
        case .polish:
            requests[index].polish = pane
        }
    }

    public func setRewriteFailure(id: String, level: ProcessingLevel, reason: String) {
        guard let index = indexForRequest(id: id) else { return }
        let pane = OutputPane(state: .failed(reason), text: "")
        switch level {
        case .raw:
            requests[index].raw = pane
        case .clean:
            requests[index].clean = pane
        case .polish:
            requests[index].polish = pane
        }
    }

    public func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func indexForRequest(id: String) -> Int? {
        requests.firstIndex(where: { $0.id == id })
    }
}
