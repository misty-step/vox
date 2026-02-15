import Carbon
import Foundation

public enum HotkeyError: Error, Equatable {
    case registrationFailed(OSStatus)

    public var localizedDescription: String {
        switch self {
        case .registrationFailed(let status):
            return "Registration failed with error code \(status)"
        }
    }
}

/// Represents the result of attempting to register a hotkey.
public enum HotkeyRegistrationResult {
    case success(HotkeyMonitor)
    case failure(HotkeyError)

    /// Convenience property for creating a success result without a real monitor (for testing).
    /// Two successes are considered equal regardless of the monitor instance.
    public static var success: HotkeyRegistrationResult {
        // Create a dummy monitor that will never be used - equality ignores the monitor instance
        let monitor = HotkeyMonitor._dummyForTesting
        return .success(monitor)
    }

    /// Convenience factory method for creating a failure result (for testing).
    public static func failureResult(_ error: HotkeyError) -> HotkeyRegistrationResult {
        return .failure(error)
    }

    /// Returns true if the registration succeeded.
    public var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    /// Returns the monitor if registration succeeded, nil otherwise.
    public var monitor: HotkeyMonitor? {
        switch self {
        case .success(let monitor): return monitor
        case .failure: return nil
        }
    }

    /// Returns the error if registration failed, nil otherwise.
    public var error: HotkeyError? {
        switch self {
        case .success: return nil
        case .failure(let error): return error
        }
    }
}

// MARK: - Testing Support
extension HotkeyMonitor {
    /// Creates a dummy monitor for testing purposes only.
    /// - Warning: This monitor is not fully functional and should only be used in tests.
    fileprivate static var _dummyForTesting: HotkeyMonitor {
        // Use the private initializer directly since we're in the same file
        return HotkeyMonitor(hotkeyId: UInt32.random(in: 1...UInt32.max))
    }
}

extension HotkeyRegistrationResult: Equatable {
    public static func == (lhs: HotkeyRegistrationResult, rhs: HotkeyRegistrationResult) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success):
            // Two successes are considered equal regardless of the monitor instance
            return true
        case (.failure(let lhsError), .failure(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

public final class HotkeyMonitor {
    private static var callbacks: [UInt32: () -> Void] = [:]
    private static var handlerRef: EventHandlerRef?
    private let hotkeyId: UInt32

    /// Attempts to register a hotkey and returns a result instead of throwing.
    /// - Returns: A `HotkeyRegistrationResult` indicating success or failure.
    public static func register(
        keyCode: UInt32,
        modifiers: UInt32,
        handler: @escaping () -> Void
    ) -> HotkeyRegistrationResult {
        installHandlerIfNeeded()

        let id = UInt32.random(in: 1...UInt32.max)
        HotkeyMonitor.callbacks[id] = handler

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x564C4858), id: id) // "VLHX"
        let status = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef
        )
        guard status == noErr else {
            HotkeyMonitor.callbacks.removeValue(forKey: id)
            return .failure(.registrationFailed(status))
        }

        let monitor = HotkeyMonitor(hotkeyId: id)
        return .success(monitor)
    }

    public init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) throws {
        HotkeyMonitor.installHandlerIfNeeded()

        let id = UInt32.random(in: 1...UInt32.max)
        hotkeyId = id
        HotkeyMonitor.callbacks[id] = handler

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x564C4858), id: id) // "VLHX"
        let status = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef
        )
        guard status == noErr else { throw HotkeyError.registrationFailed(status) }
    }

    fileprivate init(hotkeyId: UInt32) {
        self.hotkeyId = hotkeyId
    }

    deinit { HotkeyMonitor.callbacks.removeValue(forKey: hotkeyId) }

    private static func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, eventRef, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr, let callback = HotkeyMonitor.callbacks[hotKeyID.id] else {
                return OSStatus(eventNotHandledErr)
            }
            callback()
            return noErr
        }

        InstallEventHandler(GetEventDispatcherTarget(), handler, 1, &eventType, nil, &handlerRef)
    }
}
