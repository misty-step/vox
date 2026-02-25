import Testing
@testable import VoxAppKit
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
}
