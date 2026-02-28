import AppKit
import Testing
@testable import VoxUI
@testable import VoxCore

@Suite("Debug workbench store")
@MainActor
struct DebugWorkbenchStoreTests {
    @Test("Request lifecycle stores raw/clean/polish outputs")
    func requestLifecycleStoresOutputs() throws {
        let store = DebugWorkbenchStore()

        store.startRequest(id: "req-1", processingLevel: .clean)
        store.updateStatus(id: "req-1", status: .processing)
        store.setRawTranscript(id: "req-1", text: "raw transcript")
        store.setRewrite(id: "req-1", level: .clean, text: "clean rewrite")
        store.setRewrite(id: "req-1", level: .polish, text: "polish rewrite")
        store.updateStatus(id: "req-1", status: .succeeded)

        let request = try #require(store.requests.first)
        #expect(request.id == "req-1")
        #expect(request.status == .succeeded)
        #expect(request.raw.text == "raw transcript")
        #expect(request.clean.text == "clean rewrite")
        #expect(request.polish.text == "polish rewrite")
    }

    @Test("Log tail trims oldest entries")
    func logTailTrimsOldestEntries() throws {
        let store = DebugWorkbenchStore()
        store.startRequest(id: "req-2", processingLevel: .raw)

        for index in 0..<200 {
            store.appendLog(id: "req-2", line: "line-\(index)")
        }

        let request = try #require(store.requests.first)
        #expect(request.logs.count == 150)
        #expect(request.logs.first == "line-50")
        #expect(request.logs.last == "line-199")
    }

    @Test("setRewriteFailure marks pane as failed for each level")
    func rewriteFailureMarksPane() throws {
        let store = DebugWorkbenchStore()
        store.startRequest(id: "rf-1", processingLevel: .clean)

        store.setRewriteFailure(id: "rf-1", level: .clean, reason: "timeout")
        store.setRewriteFailure(id: "rf-1", level: .polish, reason: "rate limit")
        store.setRewriteFailure(id: "rf-1", level: .raw, reason: "auth")

        let request = try #require(store.requests.first)
        #expect(request.clean.state == .failed("timeout"))
        #expect(request.polish.state == .failed("rate limit"))
        #expect(request.raw.state == .failed("auth"))
    }

    @Test("setRewrite to raw level updates raw pane")
    func rewriteToRawLevel() throws {
        let store = DebugWorkbenchStore()
        store.startRequest(id: "rw-1", processingLevel: .raw)

        store.setRewrite(id: "rw-1", level: .raw, text: "raw rewrite")

        let request = try #require(store.requests.first)
        #expect(request.raw.state == .ready)
        #expect(request.raw.text == "raw rewrite")
    }

    @Test("startRequest with duplicate ID updates status instead of adding")
    func duplicateStartRequestUpdatesStatus() {
        let store = DebugWorkbenchStore()
        store.startRequest(id: "dup-1", processingLevel: .clean)
        store.updateStatus(id: "dup-1", status: .processing)

        store.startRequest(id: "dup-1", processingLevel: .clean)

        #expect(store.requests.count == 1)
        #expect(store.requests.first?.status == .recording)
    }

    @Test("Operations on nonexistent request are no-ops")
    func operationsOnMissingRequestAreNoOps() {
        let store = DebugWorkbenchStore()
        store.updateStatus(id: "ghost", status: .failed)
        store.appendLog(id: "ghost", line: "hello")
        store.setRawTranscript(id: "ghost", text: "nope")
        store.setRewrite(id: "ghost", level: .clean, text: "nope")
        store.setRewriteFailure(id: "ghost", level: .polish, reason: "nope")
        #expect(store.requests.isEmpty)
    }

    @Test("copyToClipboard puts text on pasteboard")
    func copyToClipboard() {
        let store = DebugWorkbenchStore()
        store.copyToClipboard("test clipboard content")
        #expect(NSPasteboard.general.string(forType: .string) == "test clipboard content")
    }
}
