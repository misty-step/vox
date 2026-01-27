import Foundation
import VoxCore

/// Owns recording lifecycle. Uses VoxAuth for gating, VoxGateway/providers for API.
@MainActor
final class VoxSession: ObservableObject {
    enum State: Equatable {
        case idle
        case blocked(reason: String)
        case recording
        case processing
    }

    @Published private(set) var state: State = .idle

    private let auth: VoxSessionAuth
    private let permissionCoordinator: PermissionCoordinator
    private let recorder: SessionRecorder
    private let processor: VoxSessionProcessing
    private let paster: SessionPaster

    private var processingTask: Task<Void, Never>?
    private var processingToken: UUID?
    private var isStarting = false

    init(
        auth: VoxSessionAuth,
        permissionCoordinator: PermissionCoordinator,
        recorder: SessionRecorder,
        processor: VoxSessionProcessing,
        paster: SessionPaster
    ) {
        self.auth = auth
        self.permissionCoordinator = permissionCoordinator
        self.recorder = recorder
        self.processor = processor
        self.paster = paster
    }

    /// Start/stop recording.
    func toggle() {
        switch state {
        case .idle:
            guard !isStarting else {
                Diagnostics.info("Toggle ignored: already starting.")
                return
            }
            isStarting = true
            Task { await startRecordingFlow() }
        case .blocked:
            state = .idle
            guard !isStarting else {
                Diagnostics.info("Toggle ignored: already starting.")
                return
            }
            isStarting = true
            Task { await startRecordingFlow() }
        case .recording:
            stopRecordingAndProcess()
        case .processing:
            Diagnostics.info("Toggle ignored: already processing.")
        }
    }

    // MARK: - Flow

    private func startRecordingFlow() async {
        defer { isStarting = false }

        let authResult = await gateAuth()
        guard authResult else { return }

        let micGranted = await permissionCoordinator.ensureMicrophoneAccess()
        guard micGranted else {
            Diagnostics.error("Microphone permission denied.")
            transition(to: .blocked(reason: "Microphone permission denied."))
            return
        }

        let accessibilityGranted = await permissionCoordinator.ensureAccessibilityAccess()
        guard accessibilityGranted else {
            Diagnostics.error("Accessibility permission denied.")
            transition(to: .blocked(reason: "Accessibility permission denied."))
            return
        }

        do {
            try await recorder.start()
            Diagnostics.info("Recording started.")
            transition(to: .recording)
        } catch {
            Diagnostics.error("Failed to start recording: \(String(describing: error))")
            transition(to: .blocked(reason: "Failed to start recording."))
        }
    }

    private func stopRecordingAndProcess() {
        let token = UUID()
        processingToken = token
        transition(to: .processing)

        let task = Task(priority: .userInitiated) { [recorder, processor, paster] in
            defer {
                finishProcessing(token: token)
            }

            do {
                let audioData = try await recorder.stop()
                let transcript = try await processor.transcribe(audio: audioData)
                let finalText = await finalText(from: transcript)
                guard !finalText.isEmpty else {
                    Diagnostics.error("Final text empty. Skipping paste.")
                    return
                }
                try await paster.paste(finalText)
            } catch {
                Diagnostics.error("Processing failed: \(String(describing: error))")
            }
        }

        processingTask = task
    }

    private func gateAuth() async -> Bool {
        await auth.check()
        guard auth.state == .allowed else {
            let reason = blockReason(from: auth.state)
            Diagnostics.info("Recording blocked: \(reason)")
            transition(to: .blocked(reason: reason))
            return false
        }
        return true
    }

    private func finalText(from transcript: String) async -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Diagnostics.error("Transcript empty. Skipping paste.")
            return ""
        }

        let level = await processor.processingLevel
        guard level != .off else {
            Diagnostics.info("Processing level off. Using raw transcript.")
            return transcript
        }

        do {
            return try await processor.rewrite(transcript)
        } catch {
            Diagnostics.error("Rewrite failed: \(String(describing: error)). Using raw transcript.")
            return transcript
        }
    }

    private func finishProcessing(token: UUID) {
        guard processingToken == token else { return }
        processingTask = nil
        processingToken = nil
        transition(to: .idle)
    }

    private func transition(to newState: State) {
        state = newState
    }

    private func blockReason(from state: VoxAuth.State) -> String {
        switch state {
        case .allowed:
            return "Allowed"
        case .needsAuth:
            return "Sign in required."
        case .needsSubscription:
            return "Subscription required."
        case .error(let message):
            return message.isEmpty ? "Authentication error." : message
        case .unknown, .checking:
            return "Authentication unavailable."
        }
    }
}

// MARK: - Test Seams

@MainActor
protocol VoxSessionAuth: AnyObject {
    var state: VoxAuth.State { get }
    func check() async
}

extension VoxAuth: VoxSessionAuth {}

protocol VoxSessionProcessing: Sendable {
    var processingLevel: ProcessingLevel { get async }
    func transcribe(audio: Data) async throws -> String
    func rewrite(_ transcript: String) async throws -> String
}

/// Protocol for audio recording.
protocol SessionRecorder: Sendable {
    func start() async throws
    func stop() async throws -> Data
}

/// Protocol for pasting result.
protocol SessionPaster: Sendable {
    func paste(_ text: String) async throws
}
