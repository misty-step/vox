import AppKit
import Foundation
import VoxCore

@MainActor
final class DebugWorkbenchStore: ObservableObject {
    struct OutputPane: Equatable {
        enum State: Equatable {
            case pending
            case ready
            case failed(String)
        }

        var state: State
        var text: String

        static let pending = OutputPane(state: .pending, text: "")
    }

    enum RequestStatus: String, Equatable {
        case recording
        case processing
        case succeeded
        case failed
        case cancelled
    }

    struct RequestRecord: Identifiable, Equatable {
        let id: String
        let createdAt: Date
        let processingLevel: ProcessingLevel
        var status: RequestStatus
        var raw: OutputPane
        var clean: OutputPane
        var polish: OutputPane
        var logs: [String]
    }

    static let shared = DebugWorkbenchStore()

    @Published private(set) var requests: [RequestRecord] = []

    private let maxRequests = 200
    private let maxLogsPerRequest = 150

    func startRequest(id: String, processingLevel: ProcessingLevel) {
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

    func updateStatus(id: String, status: RequestStatus) {
        guard let index = indexForRequest(id: id) else { return }
        requests[index].status = status
    }

    func appendLog(id: String, line: String) {
        guard let index = indexForRequest(id: id) else { return }
        requests[index].logs.append(line)
        if requests[index].logs.count > maxLogsPerRequest {
            requests[index].logs.removeFirst(requests[index].logs.count - maxLogsPerRequest)
        }
    }

    func setRawTranscript(id: String, text: String) {
        guard let index = indexForRequest(id: id) else { return }
        requests[index].raw = OutputPane(state: .ready, text: text)
    }

    func setRewrite(id: String, level: ProcessingLevel, text: String) {
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

    func setRewriteFailure(id: String, level: ProcessingLevel, reason: String) {
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

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func indexForRequest(id: String) -> Int? {
        requests.firstIndex(where: { $0.id == id })
    }
}
