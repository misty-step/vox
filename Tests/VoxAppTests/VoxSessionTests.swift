import XCTest
import VoxCore
@testable import VoxApp

private enum VoxSessionTestError: Error {
    case recorderStart
    case recorderStop
    case stt
    case rewrite
    case paste
}

@MainActor
private final class MockSessionAuth: VoxSessionAuth {
    var state: VoxAuth.State
    var nextState: VoxAuth.State

    init(initial: VoxAuth.State = .allowed) {
        self.state = initial
        self.nextState = initial
    }

    func check() async {
        state = nextState
    }
}

private actor MockSessionPermissions: PermissionCoordinator {
    var micGranted = true
    var accessibilityGranted = true

    func ensureMicrophoneAccess() async -> Bool { micGranted }
    func ensureAccessibilityAccess() async -> Bool { accessibilityGranted }
}

private actor MockSessionRecorder: SessionRecorder {
    var startCount = 0
    var stopCount = 0
    var audioData = Data([1, 2, 3])
    var startError: Error?
    var stopError: Error?

    func start() async throws {
        if let startError { throw startError }
        startCount += 1
    }

    func stop() async throws -> Data {
        if let stopError { throw stopError }
        stopCount += 1
        return audioData
    }
}

private actor MockSessionProcessor: VoxSessionProcessing {
    var processingLevelValue: ProcessingLevel = .light
    var transcribeResult: Result<String, Error> = .success("raw transcript")
    var rewriteResult: Result<String, Error> = .success("rewritten transcript")
    var transcribeDelayNanos: UInt64 = 0

    func transcribe(audio: Data) async throws -> String {
        if transcribeDelayNanos > 0 {
            try? await Task.sleep(nanoseconds: transcribeDelayNanos)
        }
        return try transcribeResult.get()
    }

    func rewrite(_ transcript: String) async throws -> String {
        return try rewriteResult.get()
    }

    var processingLevel: ProcessingLevel {
        get async { processingLevelValue }
    }

    func setProcessingLevel(_ level: ProcessingLevel) {
        processingLevelValue = level
    }

    func setTranscribeResult(_ result: Result<String, Error>) {
        transcribeResult = result
    }

    func setRewriteResult(_ result: Result<String, Error>) {
        rewriteResult = result
    }

    func setTranscribeDelay(nanoseconds: UInt64) {
        transcribeDelayNanos = nanoseconds
    }
}

private actor MockSessionPaster: SessionPaster {
    var pasteCount = 0
    var lastText: String?
    var pasteError: Error?

    func paste(_ text: String) async throws {
        if let pasteError { throw pasteError }
        pasteCount += 1
        lastText = text
    }
}

@MainActor
final class VoxSessionTests: XCTestCase {
    // State machine
    func testInitialStateIsIdle() async {
        let session = await makeSession()
        XCTAssertEqual(session.state, .idle)
    }

    func testToggleFromIdleStartsRecording() async {
        let recorder = MockSessionRecorder()
        let session = await makeSession(recorder: recorder)

        session.toggle()
        await wait(for: session, toMatch: .recording)

        let startCount = await recorder.startCount
        XCTAssertEqual(startCount, 1)
    }

    func testToggleFromRecordingStartsProcessing() async {
        let processor = MockSessionProcessor()
        await processor.setTranscribeDelay(nanoseconds: 300_000_000)
        let recorder = MockSessionRecorder()
        let session = await makeSession(recorder: recorder, processor: processor)

        session.toggle()
        await wait(for: session, toMatch: .recording)

        session.toggle()
        await wait(for: session, toMatch: .processing)

        await wait(forStopCount: recorder, equals: 1)
    }

    func testToggleWhileProcessingIsIgnored() async {
        let processor = MockSessionProcessor()
        await processor.setTranscribeDelay(nanoseconds: 300_000_000)
        let recorder = MockSessionRecorder()
        let session = await makeSession(recorder: recorder, processor: processor)

        session.toggle()
        await wait(for: session, toMatch: .recording)

        session.toggle()
        await wait(for: session, toMatch: .processing)

        session.toggle()
        try? await Task.sleep(nanoseconds: 50_000_000)

        let startCount = await recorder.startCount
        XCTAssertEqual(startCount, 1)
    }

    func testProcessingCompletionReturnsToIdle() async {
        let session = await makeSession()

        session.toggle()
        await wait(for: session, toMatch: .recording)

        session.toggle()
        await wait(for: session, toMatch: .idle)
    }

    // Auth gating
    func testToggleWhenNotAllowedSetsBlocked() async {
        let auth = MockSessionAuth(initial: .needsAuth)
        auth.nextState = .needsAuth
        let session = await makeSession(auth: auth)

        session.toggle()
        await waitUntilBlocked(session)
    }

    // Full flow
    func testSuccessfulRecordingPastesToClipboard() async {
        let paster = MockSessionPaster()
        let processor = MockSessionProcessor()
        await processor.setTranscribeResult(.success("raw"))
        await processor.setRewriteResult(.success("final"))
        let session = await makeSession(processor: processor, paster: paster)

        session.toggle()
        await wait(for: session, toMatch: .recording)
        session.toggle()
        await wait(for: session, toMatch: .idle)

        let lastText = await paster.lastText
        XCTAssertEqual(lastText, "final")
    }

    func testSTTFailureReturnsToIdle() async {
        let paster = MockSessionPaster()
        let processor = MockSessionProcessor()
        await processor.setTranscribeResult(.failure(VoxSessionTestError.stt))
        let session = await makeSession(processor: processor, paster: paster)

        session.toggle()
        await wait(for: session, toMatch: .recording)
        session.toggle()
        await wait(for: session, toMatch: .idle)

        let pasteCount = await paster.pasteCount
        XCTAssertEqual(pasteCount, 0)
    }

    func testRewriteFailureUsesRawTranscript() async {
        let paster = MockSessionPaster()
        let processor = MockSessionProcessor()
        await processor.setTranscribeResult(.success("raw transcript"))
        await processor.setRewriteResult(.failure(VoxSessionTestError.rewrite))
        let session = await makeSession(processor: processor, paster: paster)

        session.toggle()
        await wait(for: session, toMatch: .recording)
        session.toggle()
        await wait(for: session, toMatch: .idle)

        let lastText = await paster.lastText
        XCTAssertEqual(lastText, "raw transcript")
    }

    // MARK: - Helpers

    private func makeSession(
        auth: MockSessionAuth? = nil,
        permissions: MockSessionPermissions? = nil,
        recorder: MockSessionRecorder? = nil,
        processor: MockSessionProcessor? = nil,
        paster: MockSessionPaster? = nil
    ) async -> VoxSession {
        let auth = auth ?? MockSessionAuth()
        let permissions = permissions ?? MockSessionPermissions()
        let recorder = recorder ?? MockSessionRecorder()
        let processor = processor ?? MockSessionProcessor()
        let paster = paster ?? MockSessionPaster()
        return VoxSession(
            auth: auth,
            permissionCoordinator: permissions,
            recorder: recorder,
            processor: processor,
            paster: paster
        )
    }

    private func wait(
        for session: VoxSession,
        toMatch expected: VoxSession.State,
        timeout: TimeInterval = 1.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if session.state == expected { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for state \(expected). Last: \(session.state)")
    }

    private func waitUntilBlocked(_ session: VoxSession, timeout: TimeInterval = 1.0) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if case .blocked = session.state { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for blocked state. Last: \(session.state)")
    }

    private func wait(
        forStopCount recorder: MockSessionRecorder,
        equals expected: Int,
        timeout: TimeInterval = 1.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let current = await recorder.stopCount
            if current == expected { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        let last = await recorder.stopCount
        XCTFail("Timed out waiting for stopCount \(expected). Last: \(last)")
    }
}
