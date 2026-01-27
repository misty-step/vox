import AppKit
import Darwin
import Foundation

/// Prevents duplicate instances using lock file.
enum SingleInstanceGuard {
    struct Dependencies {
        var lockFileURL: () -> URL
        var ensureDirectory: (URL) -> Void
        var open: (URL) -> Int32
        var tryLock: (Int32) -> Bool
        var writePID: (Int32, pid_t) -> Void
        var readPID: (URL) -> pid_t?
        var processExists: (pid_t) -> Bool
        var removeItem: (URL) -> Void
        var activateExistingInstance: (String, pid_t) -> Bool
        var currentPID: () -> pid_t
        var close: (Int32) -> Void
        var exit: (Int32) -> Void
    }

    private static var dependencies: Dependencies = .live
    private static var lockFileDescriptor: Int32?

    /// Uses ~/Library/Application Support/Vox/.lock
    static func acquireOrExit() {
        if lockFileDescriptor != nil { return }

        let lockURL = dependencies.lockFileURL()
        dependencies.ensureDirectory(lockURL.deletingLastPathComponent())

        // Try twice: first normal, second after stale cleanup.
        for _ in 0..<2 {
            let fd = dependencies.open(lockURL)
            guard fd >= 0 else { return }

            if dependencies.tryLock(fd) {
                dependencies.writePID(fd, dependencies.currentPID())
                lockFileDescriptor = fd
                return
            }

            let existingPID = dependencies.readPID(lockURL)
            let isStale = existingPID.map { !dependencies.processExists($0) } ?? false
            if isStale {
                Diagnostics.warning("Stale single-instance lock detected. Cleaning up.")
                dependencies.close(fd)
                dependencies.removeItem(lockURL)
                continue
            }

            let bundleID = Bundle.main.bundleIdentifier ?? "com.vox.VoxApp"
            Diagnostics.info("Duplicate instance detected; activating existing instance and exiting.")
            _ = dependencies.activateExistingInstance(bundleID, dependencies.currentPID())
            dependencies.close(fd)
            dependencies.exit(0)
            return
        }
    }
}

private extension SingleInstanceGuard.Dependencies {
    static var live: Self {
        Self(
            lockFileURL: {
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support/Vox/.lock")
            },
            ensureDirectory: { url in
                do {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                } catch {
                    Diagnostics.error("Failed to create Vox app support dir: \(String(describing: error))")
                }
            },
            open: { url in
                let fd = Darwin.open(url.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
                if fd < 0 {
                    Diagnostics.error("Failed to open single-instance lock file at \(url.path)")
                }
                return fd
            },
            tryLock: { fd in
                flock(fd, LOCK_EX | LOCK_NB) == 0
            },
            writePID: { fd, pid in
                let pidString = "\(pid)\n"
                guard let data = pidString.data(using: .utf8) else { return }

                if ftruncate(fd, 0) != 0 {
                    Diagnostics.error("Failed to truncate single-instance lock file.")
                    return
                }

                _ = data.withUnsafeBytes { rawBuffer in
                    guard let baseAddress = rawBuffer.baseAddress else { return -1 }
                    return Darwin.write(fd, baseAddress, rawBuffer.count)
                }
            },
            readPID: { url in
                do {
                    let raw = try String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !raw.isEmpty, let pidValue = Int32(raw) else { return nil }
                    return pidValue
                } catch {
                    // Best-effort read; absence is fine.
                    return nil
                }
            },
            processExists: { pid in
                if pid <= 0 { return false }
                if kill(pid, 0) == 0 { return true }
                return errno == EPERM
            },
            removeItem: { url in
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    Diagnostics.warning("Failed to remove stale single-instance lock: \(String(describing: error))")
                }
            },
            activateExistingInstance: { bundleID, currentPID in
                let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                let otherInstances = runningApps.filter { $0.processIdentifier != currentPID }
                guard let existingApp = otherInstances.first else { return false }
                return existingApp.activate(options: [.activateIgnoringOtherApps])
            },
            currentPID: {
                ProcessInfo.processInfo.processIdentifier
            },
            close: { fd in
                guard fd >= 0 else { return }
                _ = Darwin.close(fd)
            },
            exit: { status in
                Darwin.exit(status)
            }
        )
    }
}

#if DEBUG
extension SingleInstanceGuard {
    static func _withDependenciesForTesting(_ deps: Dependencies, _ body: () -> Void) {
        let previousDeps = dependencies
        let previousFD = lockFileDescriptor
        dependencies = deps
        lockFileDescriptor = nil
        defer {
            if let fd = lockFileDescriptor {
                dependencies.close(fd)
            }
            dependencies = previousDeps
            lockFileDescriptor = previousFD
        }
        body()
    }

    static func _resetForTesting() {
        if let fd = lockFileDescriptor {
            dependencies.close(fd)
        }
        dependencies = .live
        lockFileDescriptor = nil
    }
}
#endif
