import AVFoundation
import Foundation
import ApplicationServices

public enum PermissionManager {
    private static var micRequestInFlight = false
    private static let lock = NSLock()

    private static func claimMicRequest() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if micRequestInFlight { return false }
        micRequestInFlight = true
        return true
    }

    private static func releaseMicRequest() {
        lock.lock()
        micRequestInFlight = false
        lock.unlock()
    }

    public static func requestMicrophoneAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .authorized { return true }
        if status == .denied || status == .restricted { return false }

        if !claimMicRequest() {
            while AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                try? await Task.sleep(for: .milliseconds(100))
            }
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }

        defer { releaseMicRequest() }

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
