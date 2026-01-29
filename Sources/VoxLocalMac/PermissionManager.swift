import AVFoundation
import Foundation
import ApplicationServices

public enum PermissionManager {
    private static var micRequestInFlight = false
    private static let lock = NSLock()

    public static func requestMicrophoneAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .authorized { return true }
        if status == .denied || status == .restricted { return false }

        lock.lock()
        if micRequestInFlight {
            lock.unlock()
            while AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                try? await Task.sleep(for: .milliseconds(100))
            }
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
        micRequestInFlight = true
        lock.unlock()

        defer {
            lock.lock()
            micRequestInFlight = false
            lock.unlock()
        }

        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public static func isMicrophoneAuthorized() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    public static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    public static func promptForAccessibilityIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
