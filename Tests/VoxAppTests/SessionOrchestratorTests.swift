import XCTest
@testable import VoxApp

// Mock access gate
actor MockAccessGate: AccessGate {
    var decision: AccessDecision = .allowed

    func preflight() async -> AccessDecision {
        decision
    }

    func setDecision(_ decision: AccessDecision) {
        self.decision = decision
    }
}

// Mock permission coordinator
actor MockPermissionCoordinatorForSession: PermissionCoordinator {
    var micGranted = true
    var accessibilityGranted = true

    func ensureMicrophoneAccess() async -> Bool {
        micGranted
    }

    func ensureAccessibilityAccess() async -> Bool {
        accessibilityGranted
    }

    func setMicGranted(_ granted: Bool) { micGranted = granted }
    func setAccessibilityGranted(_ granted: Bool) { accessibilityGranted = granted }
}

// Mock recorder
actor MockRecorder: SessionRecorder {
    var isRecording = false
    var startCount = 0
    var stopCount = 0
    var audioData: Data?

    func start() async throws {
        startCount += 1
        isRecording = true
    }

    func stop() async throws -> Data {
        stopCount += 1
        isRecording = false
        return audioData ?? Data()
    }

    func setAudioData(_ data: Data) { audioData = data }
    func getStartCount() -> Int { startCount }
    func getStopCount() -> Int { stopCount }
}

// Mock pipeline
actor MockPipeline: SessionPipeline {
    var processResult: Result<String, Error> = .success("processed text")
    var processCount = 0

    func process(audio: Data) async throws -> String {
        processCount += 1
        return try processResult.get()
    }

    func setResult(_ result: Result<String, Error>) { processResult = result }
    func getProcessCount() -> Int { processCount }
}

// Mock paster
actor MockPaster: SessionPaster {
    var pasteCount = 0
    var lastPastedText: String?

    func paste(_ text: String) async throws {
        pasteCount += 1
        lastPastedText = text
    }

    func getPasteCount() -> Int { pasteCount }
    func getLastPastedText() -> String? { lastPastedText }
}

final class SessionOrchestratorTests: XCTestCase {

    // Test: toggle from idle enters requestingPermissions, not recording directly
    func testToggleFromIdleRequestsPermissionsFirst() async throws {
        let accessGate = MockAccessGate()
        let permissions = MockPermissionCoordinatorForSession()
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        let paster = MockPaster()

        let orchestrator = SessionOrchestratorImpl(
            accessGate: accessGate,
            permissionCoordinator: permissions,
            recorder: recorder,
            pipeline: pipeline,
            paster: paster
        )

        await accessGate.setDecision(.allowed)

        // Initial state should be idle
        let initialState = await orchestrator.state
        XCTAssertEqual(initialState, .idle)

        // Toggle - should go through permissions then to recording
        await orchestrator.toggle()

        // After toggle completes, should be recording (if permissions granted)
        let newState = await orchestrator.state
        if case .recording = newState {
            // Success
        } else {
            XCTFail("Expected .recording, got \(newState)")
        }
    }

    // Test: blocked decision does not start recorder
    func testBlockedDecisionDoesNotStartRecorder() async throws {
        let accessGate = MockAccessGate()
        let permissions = MockPermissionCoordinatorForSession()
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        let paster = MockPaster()

        let orchestrator = SessionOrchestratorImpl(
            accessGate: accessGate,
            permissionCoordinator: permissions,
            recorder: recorder,
            pipeline: pipeline,
            paster: paster
        )

        await accessGate.setDecision(.blocked(.notAuthenticated))

        await orchestrator.toggle()

        let state = await orchestrator.state
        if case .blocked(let reason) = state, case .notAuthenticated = reason {
            // Success
        } else {
            XCTFail("Expected .blocked(.notAuthenticated), got \(state)")
        }

        // Recorder should not have been started
        let startCount = await recorder.getStartCount()
        XCTAssertEqual(startCount, 0, "Recorder should not start when blocked")
    }

    // Test: mic permission denied → blocked
    func testMicPermissionDeniedBlocks() async throws {
        let accessGate = MockAccessGate()
        let permissions = MockPermissionCoordinatorForSession()
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        let paster = MockPaster()

        let orchestrator = SessionOrchestratorImpl(
            accessGate: accessGate,
            permissionCoordinator: permissions,
            recorder: recorder,
            pipeline: pipeline,
            paster: paster
        )

        await accessGate.setDecision(.allowed)
        await permissions.setMicGranted(false)

        await orchestrator.toggle()

        let state = await orchestrator.state
        if case .blocked(let reason) = state, case .permissionDenied = reason {
            // Success
        } else {
            XCTFail("Expected .blocked(.permissionDenied), got \(state)")
        }
    }

    // Test: toggle from recording → processing
    func testToggleFromRecordingStartsProcessing() async throws {
        let accessGate = MockAccessGate()
        let permissions = MockPermissionCoordinatorForSession()
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        let paster = MockPaster()

        let orchestrator = SessionOrchestratorImpl(
            accessGate: accessGate,
            permissionCoordinator: permissions,
            recorder: recorder,
            pipeline: pipeline,
            paster: paster
        )

        await accessGate.setDecision(.allowed)
        await recorder.setAudioData(Data([1, 2, 3]))

        // First toggle → recording
        await orchestrator.toggle()

        var state = await orchestrator.state
        if case .recording = state {
            // Good
        } else {
            XCTFail("Expected recording, got \(state)")
            return
        }

        // Second toggle → processing
        await orchestrator.toggle()

        // Wait a moment for processing to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // After processing completes, should be back to idle
        state = await orchestrator.state
        XCTAssertEqual(state, .idle)

        // Pipeline should have been called
        let processCount = await pipeline.getProcessCount()
        XCTAssertEqual(processCount, 1)
    }

    // Test: toggle while processing is ignored
    func testToggleWhileProcessingIsIgnored() async throws {
        let accessGate = MockAccessGate()
        let permissions = MockPermissionCoordinatorForSession()
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        let paster = MockPaster()

        let orchestrator = SessionOrchestratorImpl(
            accessGate: accessGate,
            permissionCoordinator: permissions,
            recorder: recorder,
            pipeline: pipeline,
            paster: paster
        )

        await accessGate.setDecision(.allowed)

        // Start recording
        await orchestrator.toggle()

        // Stop recording → processing
        await orchestrator.toggle()

        // Immediately try to toggle again while processing
        // This should be ignored
        _ = await orchestrator.state
        await orchestrator.toggle()
        _ = await orchestrator.state

        // The key is that we don't start a NEW recording
        let startCount = await recorder.getStartCount()
        XCTAssertEqual(startCount, 1, "Should only have started recording once")
    }

    // Test: processing completion returns to idle
    func testProcessingCompletionReturnsToIdle() async throws {
        let accessGate = MockAccessGate()
        let permissions = MockPermissionCoordinatorForSession()
        let recorder = MockRecorder()
        let pipeline = MockPipeline()
        let paster = MockPaster()

        let orchestrator = SessionOrchestratorImpl(
            accessGate: accessGate,
            permissionCoordinator: permissions,
            recorder: recorder,
            pipeline: pipeline,
            paster: paster
        )

        await accessGate.setDecision(.allowed)
        await recorder.setAudioData(Data([1, 2, 3]))

        // Full flow: idle → recording → processing → idle
        await orchestrator.toggle() // Start recording
        await orchestrator.toggle() // Stop → process

        // Wait for processing
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        let finalState = await orchestrator.state
        XCTAssertEqual(finalState, .idle)

        // Should have pasted result
        let pasteCount = await paster.getPasteCount()
        XCTAssertEqual(pasteCount, 1)

        let pastedText = await paster.getLastPastedText()
        XCTAssertEqual(pastedText, "processed text")
    }
}
