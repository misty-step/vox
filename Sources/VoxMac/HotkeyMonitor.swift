import Carbon
import Foundation

public enum HotkeyError: Error {
    case registrationFailed(OSStatus)
}

public final class HotkeyMonitor {
    private static var callbacks: [UInt32: () -> Void] = [:]
    private static var handlerRef: EventHandlerRef?
    private let hotkeyId: UInt32

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
