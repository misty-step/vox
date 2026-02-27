import Foundation
import VoxCore

public struct DebugWorkbenchSink: Sendable {
    private let startRequestImpl: @Sendable (_ id: String, _ level: ProcessingLevel) -> Void
    private let updateStatusImpl: @Sendable (_ id: String, _ status: DebugWorkbenchStore.RequestStatus) -> Void
    private let logImpl: @Sendable (_ id: String, _ message: String) -> Void
    private let rawImpl: @Sendable (_ id: String, _ text: String) -> Void
    private let rewriteImpl: @Sendable (_ id: String, _ level: ProcessingLevel, _ text: String) -> Void
    private let rewriteFailureImpl: @Sendable (_ id: String, _ level: ProcessingLevel, _ reason: String) -> Void

    public static let disabled = DebugWorkbenchSink(
        startRequest: { _, _ in },
        updateStatus: { _, _ in },
        log: { _, _ in },
        raw: { _, _ in },
        rewrite: { _, _, _ in },
        rewriteFailure: { _, _, _ in }
    )

    public init(
        startRequest: @escaping @Sendable (_ id: String, _ level: ProcessingLevel) -> Void,
        updateStatus: @escaping @Sendable (_ id: String, _ status: DebugWorkbenchStore.RequestStatus) -> Void,
        log: @escaping @Sendable (_ id: String, _ message: String) -> Void,
        raw: @escaping @Sendable (_ id: String, _ text: String) -> Void,
        rewrite: @escaping @Sendable (_ id: String, _ level: ProcessingLevel, _ text: String) -> Void,
        rewriteFailure: @escaping @Sendable (_ id: String, _ level: ProcessingLevel, _ reason: String) -> Void
    ) {
        self.startRequestImpl = startRequest
        self.updateStatusImpl = updateStatus
        self.logImpl = log
        self.rawImpl = raw
        self.rewriteImpl = rewrite
        self.rewriteFailureImpl = rewriteFailure
    }

    public static func live(store: DebugWorkbenchStore) -> DebugWorkbenchSink {
        DebugWorkbenchSink(
            startRequest: { id, level in
                Task { @MainActor in
                    store.startRequest(id: id, processingLevel: level)
                }
            },
            updateStatus: { id, status in
                Task { @MainActor in
                    store.updateStatus(id: id, status: status)
                }
            },
            log: { id, message in
                Task { @MainActor in
                    let stamp = Self.timeFormatter.string(from: Date())
                    store.appendLog(id: id, line: "[\(stamp)] \(message)")
                }
            },
            raw: { id, text in
                Task { @MainActor in
                    store.setRawTranscript(id: id, text: text)
                }
            },
            rewrite: { id, level, text in
                Task { @MainActor in
                    store.setRewrite(id: id, level: level, text: text)
                }
            },
            rewriteFailure: { id, level, reason in
                Task { @MainActor in
                    store.setRewriteFailure(id: id, level: level, reason: reason)
                }
            }
        )
    }

    public func startRequest(id: String, processingLevel: ProcessingLevel) {
        startRequestImpl(id, processingLevel)
    }

    public func updateStatus(id: String, status: DebugWorkbenchStore.RequestStatus) {
        updateStatusImpl(id, status)
    }

    public func log(requestID: String, message: String) {
        logImpl(requestID, message)
    }

    public func setRawTranscript(requestID: String, text: String) {
        rawImpl(requestID, text)
    }

    public func setRewrite(requestID: String, level: ProcessingLevel, text: String) {
        rewriteImpl(requestID, level, text)
    }

    public func setRewriteFailure(requestID: String, level: ProcessingLevel, reason: String) {
        rewriteFailureImpl(requestID, level, reason)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

public enum DebugWorkbenchRuntime {
    public static func isEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        #if DEBUG
        let value = environment["VOX_DEBUG_WORKBENCH"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return ["1", "true", "yes", "on"].contains(value)
        #else
        return false
        #endif
    }
}
