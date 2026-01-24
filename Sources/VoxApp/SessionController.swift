import AppKit
import Foundation
import os
import VoxCore
import VoxMac

@MainActor
final class SessionController {
    enum State {
        case idle
        case recording
        case processing
    }

    private static let levelMeterInterval: TimeInterval = 0.05

    private let pipeline: DictationPipeline
    private let audioRecorder = AudioRecorder()
    private let clipboardPaster: ClipboardPaster
    private let historyStore: HistoryStore?
    private let metadataConfig: SessionMetadataConfig
    private let logger = Logger(subsystem: "vox", category: "session")
    private var targetApp: NSRunningApplication?
    private var levelTimer: DispatchSourceTimer?
    private var processingLevel: ProcessingLevel
    private var silentSamples = 0
    private var totalSamples = 0
    private var currentInputDeviceName: String?

    private(set) var state: State = .idle {
        didSet { notifyState(state) }
    }

    var stateDidChange: ((State) -> Void)?
    var statusDidChange: ((String) -> Void)?
    var inputLevelDidChange: ((Float, Float) -> Void)?
    var entitlementBlocked: ((EntitlementState) -> Void)?

    init(
        pipeline: DictationPipeline,
        processingLevel: ProcessingLevel,
        historyStore: HistoryStore?,
        metadataConfig: SessionMetadataConfig
    ) {
        self.pipeline = pipeline
        self.processingLevel = processingLevel
        self.historyStore = historyStore
        self.metadataConfig = metadataConfig
        self.clipboardPaster = ClipboardPaster(
            restoreDelay: PasteOptions.restoreDelay,
            shouldRestore: PasteOptions.shouldRestore
        )
    }

    func updateProcessingLevel(_ level: ProcessingLevel) {
        processingLevel = level
    }

    func toggle() {
        switch state {
        case .idle:
            // Check entitlement before starting recording
            let entitlementManager = EntitlementManager.shared
            guard entitlementManager.isAllowed else {
                Diagnostics.info("Recording blocked: not entitled")
                entitlementBlocked?(entitlementManager.state)
                return
            }

            // Trigger background refresh if stale
            if entitlementManager.shouldRefresh {
                Task { await entitlementManager.refresh() }
            }

            state = .recording
            Task { await startRecording() }
        case .recording:
            stopAndProcess()
        case .processing:
            break
        }
    }

    private func startRecording() async {
        let granted = await PermissionManager.requestMicrophoneAccess()
        guard granted else {
            logger.error("Microphone permission denied.")
            Diagnostics.error("Microphone permission denied.")
            state = .idle
            return
        }

        PermissionManager.promptForAccessibilityIfNeeded()
        targetApp = NSWorkspace.shared.frontmostApplication

        do {
            currentInputDeviceName = AudioRecorder.currentInputDeviceName()
            if let deviceName = currentInputDeviceName {
                Diagnostics.info("Audio input device: \(deviceName)")
            } else {
                Diagnostics.warning("Could not determine audio input device.")
            }
            try audioRecorder.start()
            Diagnostics.info("Recording started.")
            silentSamples = 0
            totalSamples = 0
            startLevelMetering()
        } catch {
            logger.error("Failed to start recording: \(String(describing: error))")
            Diagnostics.error("Failed to start recording: \(String(describing: error))")
            state = .idle
        }
    }

    private func stopAndProcess() {
        let sessionId = UUID()
        let audioURL: URL
        var audioSizeBytes: Int?
        do {
            audioURL = try audioRecorder.stop()
            stopLevelMetering()
        } catch {
            logger.error("Failed to stop recording: \(String(describing: error))")
            Diagnostics.error("Failed to stop recording: \(String(describing: error))")
            state = .idle
            return
        }

        Diagnostics.info("Recording stopped. Processing audio at \(audioURL.lastPathComponent)")

        // Check for silent audio
        if totalSamples > 0 {
            let silenceRatio = Float(silentSamples) / Float(totalSamples)
            if silenceRatio > 0.9 {
                let deviceInfo = currentInputDeviceName.map { " (recording from '\($0)')" } ?? ""
                Diagnostics.warning("Audio appears to be mostly silent (\(Int(silenceRatio * 100))%)\(deviceInfo). Check your microphone.")
            }
        }

        if let size = try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? NSNumber {
            Diagnostics.info("Audio file size: \(size.intValue) bytes.")
            audioSizeBytes = size.intValue
            if size.intValue < 1024 {
                let deviceInfo = currentInputDeviceName.map { " Current device: '\($0)'." } ?? ""
                Diagnostics.error("Audio file is very small.\(deviceInfo) Check microphone permission or input device.")
            }
        }
        let currentProcessingLevel = processingLevel
        let history = historyStore?.startSession(
            metadata: HistoryMetadata(
                sessionId: sessionId,
                startedAt: Date(),
                updatedAt: Date(),
                processingLevel: currentProcessingLevel.rawValue,
                locale: metadataConfig.locale,
                sttModelId: metadataConfig.sttModelId,
                rewriteModelId: metadataConfig.rewriteModelId,
                maxOutputTokens: metadataConfig.maxOutputTokens,
                temperature: metadataConfig.temperature,
                thinkingLevel: metadataConfig.thinkingLevel,
                targetAppBundleId: targetApp?.bundleIdentifier,
                audioFileName: audioURL.lastPathComponent,
                audioFileSizeBytes: audioSizeBytes,
                transcriptLength: nil,
                rewriteLength: nil,
                finalLength: nil,
                rewriteRatio: nil,
                pasteSucceeded: nil,
                errors: []
            )
        )
        state = .processing
        Task.detached(priority: .userInitiated) { [pipeline] in
            let result: Result<String, Error>
            do {
                let finalText = try await pipeline.run(
                    sessionId: sessionId,
                    audioURL: audioURL,
                    processingLevel: currentProcessingLevel,
                    history: history
                )
                result = .success(finalText)
            } catch {
                result = .failure(error)
            }

            try? FileManager.default.removeItem(at: audioURL)

            if case .failure(let error) = result {
                if let history {
                    await history.recordError("Processing failed: \(String(describing: error))")
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                defer { self.state = .idle }

                switch result {
                case .success(let finalText):
                    do {
                        try self.paste(finalText: finalText)
                        Task { await history?.recordPaste(success: true) }
                    } catch {
                        self.logger.error("Paste failed: \(String(describing: error))")
                        Diagnostics.error("Paste failed: \(String(describing: error))")
                        Task { await history?.recordPaste(success: false, error: String(describing: error)) }
                    }
                case .failure(let error):
                    if case VoxError.noTranscript = error {
                        let deviceInfo = self.currentInputDeviceName ?? "unknown"
                        Diagnostics.error("No speech detected (input: '\(deviceInfo)'). To use a different mic, change your default in System Settings > Sound > Input.")
                    } else {
                        self.logger.error("Processing failed: \(String(describing: error))")
                        Diagnostics.error("Processing failed: \(String(describing: error))")
                    }
                }
            }
        }
    }

    private func paste(finalText: String) throws {
        if let targetApp {
            Diagnostics.info("Activating target app: \(targetApp.bundleIdentifier ?? "unknown")")
            _ = targetApp.activate(options: [.activateIgnoringOtherApps])
        }
        Diagnostics.info("Pasting result to active app.")
        let restoreAfter = PasteOptions.shouldRestore
            ? (PasteOptions.clipboardHold > 0 ? PasteOptions.clipboardHold : PasteOptions.restoreDelay)
            : nil

        if SecureInput.isEnabled {
            Diagnostics.info("Secure input detected. Attempting paste and keeping clipboard.")
        }

        try clipboardPaster.paste(text: finalText, restoreAfter: restoreAfter)
        Diagnostics.info("Paste completed. Clipboard restore: \(PasteOptions.shouldRestore ? "on" : "off"), delay: \(restoreAfter ?? 0)s")
        notifyStatus("Copied to clipboard")
    }

    private func startLevelMetering() {
        stopLevelMetering()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: Self.levelMeterInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let levels = self.audioRecorder.currentLevel()
            self.totalSamples += 1
            if levels.average < 0.05 && levels.peak < 0.1 {
                self.silentSamples += 1
            }
            self.inputLevelDidChange?(levels.average, levels.peak)
        }
        levelTimer = timer
        timer.resume()
    }

    private func stopLevelMetering() {
        levelTimer?.cancel()
        levelTimer = nil
        inputLevelDidChange?(0, 0)
    }

    private func notifyState(_ state: State) {
        stateDidChange?(state)
    }

    private func notifyStatus(_ message: String) {
        statusDidChange?(message)
    }
}
