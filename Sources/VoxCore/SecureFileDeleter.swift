import Foundation

/// Deletes temporary audio files.
///
/// On APFS (macOS 10.13+), secure overwrite is ineffective due to copy-on-write
/// semantics; writing zeros allocates new blocks while original data persists
/// until space reclamation. Rely on FileVault full-disk encryption for data-at-rest
/// protection. See issue #148 for encrypt-at-source approach.
public enum SecureFileDeleter {
    /// Removes the file at `url`. Logs on failure instead of throwing.
    public static func delete(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileNoSuchFileError {
            // Already gone - not an error
        } catch {
            print("[Vox] Failed to delete \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
