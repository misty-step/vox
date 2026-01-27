import AVFoundation
import ApplicationServices
import Foundation
import VoxMac

/// Permission status used by the coordinator.
enum PermissionStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// Protocol for checking permissions (test seam).
protocol PermissionChecker: Sendable {
    func getMicrophoneStatus() async -> PermissionStatus
    func getAccessibilityStatus() async -> PermissionStatus
    func requestMicrophoneAccess() async -> Bool
    func requestAccessibilityAccess() async -> Bool
}

/// Coordinator that deduplicates permission prompts.
protocol PermissionCoordinator: Sendable {
    func ensureMicrophoneAccess() async -> Bool
    func ensureAccessibilityAccess() async -> Bool
}

/// Concrete implementation.
actor PermissionCoordinatorImpl: PermissionCoordinator {
    private let checker: PermissionChecker

    // Cached results.
    private var microphoneGranted: Bool?
    private var accessibilityGranted: Bool?

    // Deduplication for concurrent requests.
    private var activeMicrophoneRequest: Task<Bool, Never>?
    private var activeAccessibilityRequest: Task<Bool, Never>?

    // Accessibility should only prompt once per session.
    private var hasPromptedAccessibility = false

    init(checker: PermissionChecker) {
        self.checker = checker
    }

    func ensureMicrophoneAccess() async -> Bool {
        if let cached = microphoneGranted {
            return cached
        }

        let status = await checker.getMicrophoneStatus()
        switch status {
        case .authorized:
            microphoneGranted = true
            return true
        case .denied, .restricted:
            microphoneGranted = false
            return false
        case .notDetermined:
            break
        }

        if let active = activeMicrophoneRequest {
            return await active.value
        }

        let task = Task<Bool, Never> { [checker] in
            let granted = await checker.requestMicrophoneAccess()
            microphoneGranted = granted
            return granted
        }

        activeMicrophoneRequest = task
        let result = await task.value
        activeMicrophoneRequest = nil
        return result
    }

    func ensureAccessibilityAccess() async -> Bool {
        if let cached = accessibilityGranted {
            return cached
        }

        let status = await checker.getAccessibilityStatus()
        switch status {
        case .authorized:
            accessibilityGranted = true
            return true
        case .denied, .restricted:
            accessibilityGranted = false
            return false
        case .notDetermined:
            break
        }

        if hasPromptedAccessibility {
            let refreshed = await checker.getAccessibilityStatus()
            let granted = refreshed == .authorized
            accessibilityGranted = granted
            return granted
        }

        if let active = activeAccessibilityRequest {
            return await active.value
        }

        let task = Task<Bool, Never> { [checker] in
            hasPromptedAccessibility = true
            let granted = await checker.requestAccessibilityAccess()
            accessibilityGranted = granted
            return granted
        }

        activeAccessibilityRequest = task
        let result = await task.value
        activeAccessibilityRequest = nil
        return result
    }
}

/// Production permission checker that wraps VoxMac permission APIs.
struct SystemPermissionChecker: PermissionChecker {
    func getMicrophoneStatus() async -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func getAccessibilityStatus() async -> PermissionStatus {
        AXIsProcessTrusted() ? .authorized : .notDetermined
    }

    func requestMicrophoneAccess() async -> Bool {
        await PermissionManager.requestMicrophoneAccess()
    }

    func requestAccessibilityAccess() async -> Bool {
        PermissionManager.promptForAccessibilityIfNeeded()
        return PermissionManager.isAccessibilityTrusted()
    }
}
