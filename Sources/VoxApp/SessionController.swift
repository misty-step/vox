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
    private let logger = Logger(subsystem: "vox", category: "session")
    private var targetApp: NSRunningApplication?
    private var levelTimer: DispatchSourceTimer?
    private var processingLevel: ProcessingLevel

    private(set) var state: State = .idle {
        didSet { notifyState(state) }
    }

    var stateDidChange: ((State) -> Void)?
    var statusDidChange: ((String) -> Void)?
    var inputLevelDidChange: ((Float, Float) -> Void)?

    init(
        pipeline: DictationPipeline,
        processingLevel: ProcessingLevel
    ) {
        self.pipeline = pipeline
        self.processingLevel = processingLevel
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
            try audioRecorder.start()
            Diagnostics.info("Recording started.")
            startLevelMetering()
        } catch {
            logger.error("Failed to start recording: \(String(describing: error))")
            Diagnostics.error("Failed to start recording: \(String(describing: error))")
            state = .idle
        }
    }

    private func stopAndProcess() {
        let audioURL: URL
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
        if let size = try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? NSNumber {
            Diagnostics.info("Audio file size: \(size.intValue) bytes.")
            if size.intValue < 1024 {
                Diagnostics.error("Audio file is very small. Check microphone permission or input device.")
            }
        }
        let currentProcessingLevel = processingLevel
        state = .processing
        Task.detached(priority: .userInitiated) { [pipeline] in
            let result: Result<String, Error>
            do {
                let finalText = try await pipeline.run(audioURL: audioURL, processingLevel: currentProcessingLevel)
                result = .success(finalText)
            } catch {
                result = .failure(error)
            }

            try? FileManager.default.removeItem(at: audioURL)

            await MainActor.run { [weak self] in
                guard let self else { return }
                defer { self.state = .idle }

                switch result {
                case .success(let finalText):
                    do {
                        try self.paste(finalText: finalText)
                    } catch {
                        self.logger.error("Paste failed: \(String(describing: error))")
                        Diagnostics.error("Paste failed: \(String(describing: error))")
                    }
                case .failure(let error):
                    if case VoxError.noTranscript = error {
                        Diagnostics.error("Transcript is empty. Check microphone input or STT configuration.")
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
