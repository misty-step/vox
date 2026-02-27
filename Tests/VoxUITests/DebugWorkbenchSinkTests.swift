import Foundation
import Testing
import VoxCore
@testable import VoxUI

/// Thread-safe box for capturing values from @Sendable closures in tests.
private final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ value: T) { _value = value }
    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); _value = newValue; lock.unlock() }
    }
}

@Suite("DebugWorkbenchSink")
struct DebugWorkbenchSinkTests {
    @Test("disabled sink does not crash when called")
    func disabledSinkIsNoop() {
        let sink = DebugWorkbenchSink.disabled
        sink.startRequest(id: "x", processingLevel: .clean)
        sink.updateStatus(id: "x", status: .processing)
        sink.log(requestID: "x", message: "hello")
        sink.setRawTranscript(requestID: "x", text: "transcript")
        sink.setRewrite(requestID: "x", level: .clean, text: "rewrite")
        sink.setRewriteFailure(requestID: "x", level: .polish, reason: "timeout")
    }

    @Test("Custom sink forwards startRequest")
    func customSinkForwardsStartRequest() {
        let receivedID = Box<String?>(nil)
        let receivedLevel = Box<ProcessingLevel?>(nil)

        let sink = DebugWorkbenchSink(
            startRequest: { id, level in receivedID.value = id; receivedLevel.value = level },
            updateStatus: { _, _ in },
            log: { _, _ in },
            raw: { _, _ in },
            rewrite: { _, _, _ in },
            rewriteFailure: { _, _, _ in }
        )

        sink.startRequest(id: "req-1", processingLevel: .polish)
        #expect(receivedID.value == "req-1")
        #expect(receivedLevel.value == .polish)
    }

    @Test("Custom sink forwards updateStatus")
    func customSinkForwardsUpdateStatus() {
        let receivedStatus = Box<DebugWorkbenchStore.RequestStatus?>(nil)

        let sink = DebugWorkbenchSink(
            startRequest: { _, _ in },
            updateStatus: { _, status in receivedStatus.value = status },
            log: { _, _ in },
            raw: { _, _ in },
            rewrite: { _, _, _ in },
            rewriteFailure: { _, _, _ in }
        )

        sink.updateStatus(id: "req-1", status: .succeeded)
        #expect(receivedStatus.value == .succeeded)
    }

    @Test("Custom sink forwards log")
    func customSinkForwardsLog() {
        let receivedMessage = Box<String?>(nil)

        let sink = DebugWorkbenchSink(
            startRequest: { _, _ in },
            updateStatus: { _, _ in },
            log: { _, msg in receivedMessage.value = msg },
            raw: { _, _ in },
            rewrite: { _, _, _ in },
            rewriteFailure: { _, _, _ in }
        )

        sink.log(requestID: "req-1", message: "test log")
        #expect(receivedMessage.value == "test log")
    }

    @Test("Custom sink forwards raw transcript")
    func customSinkForwardsRaw() {
        let receivedText = Box<String?>(nil)

        let sink = DebugWorkbenchSink(
            startRequest: { _, _ in },
            updateStatus: { _, _ in },
            log: { _, _ in },
            raw: { _, text in receivedText.value = text },
            rewrite: { _, _, _ in },
            rewriteFailure: { _, _, _ in }
        )

        sink.setRawTranscript(requestID: "req-1", text: "hello world")
        #expect(receivedText.value == "hello world")
    }

    @Test("Custom sink forwards rewrite")
    func customSinkForwardsRewrite() {
        let receivedLevel = Box<ProcessingLevel?>(nil)
        let receivedText = Box<String?>(nil)

        let sink = DebugWorkbenchSink(
            startRequest: { _, _ in },
            updateStatus: { _, _ in },
            log: { _, _ in },
            raw: { _, _ in },
            rewrite: { _, level, text in receivedLevel.value = level; receivedText.value = text },
            rewriteFailure: { _, _, _ in }
        )

        sink.setRewrite(requestID: "req-1", level: .clean, text: "rewritten")
        #expect(receivedLevel.value == .clean)
        #expect(receivedText.value == "rewritten")
    }

    @Test("Custom sink forwards rewrite failure")
    func customSinkForwardsRewriteFailure() {
        let receivedReason = Box<String?>(nil)

        let sink = DebugWorkbenchSink(
            startRequest: { _, _ in },
            updateStatus: { _, _ in },
            log: { _, _ in },
            raw: { _, _ in },
            rewrite: { _, _, _ in },
            rewriteFailure: { _, _, reason in receivedReason.value = reason }
        )

        sink.setRewriteFailure(requestID: "req-1", level: .polish, reason: "rate limited")
        #expect(receivedReason.value == "rate limited")
    }
}

@Suite("DebugWorkbenchRuntime")
struct DebugWorkbenchRuntimeTests {
    @Test("isEnabled returns true for recognized truthy values")
    func enabledForTruthyValues() {
        for value in ["1", "true", "yes", "on"] {
            #expect(DebugWorkbenchRuntime.isEnabled(environment: ["VOX_DEBUG_WORKBENCH": value]))
        }
    }

    @Test("isEnabled returns false for unset or falsy values")
    func disabledForFalsyValues() {
        #expect(!DebugWorkbenchRuntime.isEnabled(environment: [:]))
        #expect(!DebugWorkbenchRuntime.isEnabled(environment: ["VOX_DEBUG_WORKBENCH": "0"]))
        #expect(!DebugWorkbenchRuntime.isEnabled(environment: ["VOX_DEBUG_WORKBENCH": "false"]))
        #expect(!DebugWorkbenchRuntime.isEnabled(environment: ["VOX_DEBUG_WORKBENCH": ""]))
    }

    @Test("isEnabled trims and lowercases input")
    func enabledTrimsCasing() {
        #expect(DebugWorkbenchRuntime.isEnabled(environment: ["VOX_DEBUG_WORKBENCH": " TRUE "]))
        #expect(DebugWorkbenchRuntime.isEnabled(environment: ["VOX_DEBUG_WORKBENCH": "  On  "]))
    }
}
