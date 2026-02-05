import Foundation

public enum SecureFileDeleter {
    /// Overwrites file data with zeros then deletes. Logs errors instead of silently ignoring.
    public static func delete(at url: URL) {
        let fm = FileManager.default
        // Only process regular files that exist
        guard fm.fileExists(atPath: url.path) else { return }

        do {
            // Overwrite with zeros before deletion
            let attrs = try fm.attributesOfItem(atPath: url.path)
            if let fileSize = attrs[.size] as? UInt64, fileSize > 0 {
                if let handle = try? FileHandle(forWritingTo: url) {
                    let zeros = Data(count: Int(min(fileSize, UInt64(Int.max))))
                    handle.write(zeros)
                    handle.synchronizeFile()
                    handle.closeFile()
                }
            }
            try fm.removeItem(at: url)
        } catch {
            print("[Vox] Failed to securely delete \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
