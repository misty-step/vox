import AppKit
import Foundation
import os
import VoxMac

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var hotkeyMonitor: HotkeyMonitor?
    private var sessionController: SessionController?
    private var hudController: HUDController?
    private let logger = Logger(subsystem: "vox", category: "app")

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.info("Vox starting.")
        do {
            let config = try ConfigLoader.load()
            let sttProvider = try ProviderFactory.makeSTT(config: config.stt)
            let rewriteProvider = try ProviderFactory.makeRewrite(config: config.rewrite)

            let contextURL = URL(fileURLWithPath: config.contextPath ?? AppConfig.defaultContextPath)
            let locale = config.stt.languageCode ?? Locale.current.identifier
            let pipeline = DictationPipeline(
                sttProvider: sttProvider,
                rewriteProvider: rewriteProvider,
                contextURL: contextURL,
                locale: locale,
                modelId: config.stt.modelId
            )
            let session = SessionController(
                pipeline: pipeline
            )

            let statusBar = StatusBarController(
                onToggle: { session.toggle() },
                onQuit: { NSApplication.shared.terminate(nil) }
            )
            let hud = HUDController()

            session.stateDidChange = { [weak statusBar, weak hud] state in
                statusBar?.update(state: state)
                switch state {
                case .idle:
                    hud?.show(state: .hidden)
                case .recording:
                    hud?.show(state: .recording)
                case .processing:
                    hud?.show(state: .processing)
                }
            }
            session.statusDidChange = { [weak statusBar, weak hud] message in
                statusBar?.showMessage(message)
                hud?.showMessage(message)
            }
            session.inputLevelDidChange = { [weak hud] average, peak in
                hud?.updateInputLevels(average: average, peak: peak)
            }

            let hotkey = config.hotkey ?? .default
            let modifiers = HotkeyParser.modifiers(from: hotkey.modifiers)
            hotkeyMonitor = try HotkeyMonitor(keyCode: hotkey.keyCode, modifiers: modifiers) {
                session.toggle()
            }

            statusBarController = statusBar
            sessionController = session
            hudController = hud

            PermissionManager.promptForAccessibilityIfNeeded()
            Task { _ = await PermissionManager.requestMicrophoneAccess() }
        } catch {
            logger.error("Startup failed: \(String(describing: error))")
            showStartupError(String(describing: error))
        }
    }

    private func showStartupError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Vox failed to start"
        alert.informativeText = message
        alert.addButton(withTitle: "Quit")
        alert.runModal()
        NSApplication.shared.terminate(nil)
    }
}
