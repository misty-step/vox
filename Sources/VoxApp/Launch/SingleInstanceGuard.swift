import Foundation
import AppKit

/// Ensures only one instance of VoxApp runs at a time.
/// Call `acquireOrExit()` at the very start of main.swift before any other initialization.
enum SingleInstanceGuard {
    /// Exits immediately if another Vox instance is already running.
    static func acquireOrExit() {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.vox.VoxApp"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)

        let currentPid = ProcessInfo.processInfo.processIdentifier
        let otherInstances = runningApps.filter { $0.processIdentifier != currentPid }

        guard let existingApp = otherInstances.first else { return }
        Diagnostics.info("Duplicate instance detected; activating existing instance and exiting.")
        existingApp.activate(options: [.activateIgnoringOtherApps])
        exit(0)
    }
}

