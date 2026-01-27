import Foundation

/// Session state machine states.
enum SessionState: Equatable {
    case idle
    case requestingPermissions
    case blocked(reason: BlockReason)
    case recording(sessionId: UUID)
    case processing(sessionId: UUID)
}

/// Protocol for audio recording.
protocol SessionRecorder: Sendable {
    func start() async throws
    func stop() async throws -> Data
}

/// Protocol for processing pipeline.
protocol SessionPipeline: Sendable {
    func process(audio: Data) async throws -> String
}

/// Protocol for pasting result.
protocol SessionPaster: Sendable {
    func paste(_ text: String) async throws
}

/// The proper state machine orchestrator.
protocol SessionOrchestrator: Sendable {
    var state: SessionState { get async }
    func toggle() async
    func setStateObserver(_ observer: @escaping (SessionState) -> Void) async
}

/// Concrete implementation.
actor SessionOrchestratorImpl: SessionOrchestrator {
    private let accessGate: AccessGate
    private let permissionCoordinator: PermissionCoordinator
    private let recorder: SessionRecorder
    private let pipeline: SessionPipeline
    private let paster: SessionPaster

    private var processingTask: Task<Void, Never>?
    private var stateObserver: ((SessionState) -> Void)?

    private(set) var state: SessionState = .idle {
        didSet { stateObserver?(state) }
    }

    init(
        accessGate: AccessGate,
        permissionCoordinator: PermissionCoordinator,
        recorder: SessionRecorder,
        pipeline: SessionPipeline,
        paster: SessionPaster
    ) {
        self.accessGate = accessGate
        self.permissionCoordinator = permissionCoordinator
        self.recorder = recorder
        self.pipeline = pipeline
        self.paster = paster
    }

    func toggle() async {
        switch state {
        case .idle:
            await startSession()
        case .requestingPermissions:
            // Already starting. Ignore.
            return
        case .blocked:
            // Reset then try again.
            state = .idle
            await startSession()
        case .recording(let sessionId):
            await stopRecordingAndProcess(sessionId: sessionId)
        case .processing:
            // Can't cancel processing. Ignore.
            return
        }
    }

    func setStateObserver(_ observer: @escaping (SessionState) -> Void) async {
        stateObserver = observer
        observer(state)
    }

    private func startSession() async {
        transition(to: .requestingPermissions)

        // Step 1: Check access (auth + entitlement).
        let decision = await accessGate.preflight()
        guard case .allowed = decision else {
            if case .blocked(let reason) = decision {
                transition(to: .blocked(reason: reason))
            }
            return
        }

        // Step 2: Check permissions.
        let micGranted = await permissionCoordinator.ensureMicrophoneAccess()
        guard micGranted else {
            transition(to: .blocked(reason: .permissionDenied))
            return
        }

        let accessibilityGranted = await permissionCoordinator.ensureAccessibilityAccess()
        guard accessibilityGranted else {
            transition(to: .blocked(reason: .permissionDenied))
            return
        }

        // Step 3: Start recording.
        let sessionId = UUID()
        do {
            try await recorder.start()
            transition(to: .recording(sessionId: sessionId))
        } catch {
            transition(to: .blocked(reason: .networkError(String(describing: error))))
        }
    }

    private func stopRecordingAndProcess(sessionId: UUID) async {
        transition(to: .processing(sessionId: sessionId))

        let task = Task.detached(priority: .userInitiated) { [recorder, pipeline, paster] in
            do {
                let audioData = try await recorder.stop()
                let result = try await pipeline.process(audio: audioData)
                try await paster.paste(result)
            } catch {
                Diagnostics.error("Processing failed: \(String(describing: error))")
            }

            await self.finishProcessing(sessionId: sessionId)
        }

        processingTask = task
    }

    private func finishProcessing(sessionId: UUID) {
        guard case .processing(let activeId) = state, activeId == sessionId else {
            return
        }
        processingTask = nil
        transition(to: .idle)
    }

    private func transition(to newState: SessionState) {
        state = newState
    }
}
