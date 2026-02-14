import CoreAudio
import Foundation

public struct AudioInputDevice: Identifiable, Hashable, Sendable {
    public let id: String // UID — stable across reboots
    public let name: String
    public let deviceID: AudioDeviceID // runtime-only, not persisted
}

/// Observable object that publishes device list changes and validates selected device availability.
@MainActor
public final class AudioDeviceObserver: ObservableObject {
    public static let shared = AudioDeviceObserver()

    @Published public private(set) var devices: [AudioInputDevice] = []
    @Published public private(set) var selectedDeviceUnavailable: Bool = false

    private var propertyListener: AudioObjectPropertyListenerProc?
    private var listenerCount = 0
    private var selectedDeviceUID: String?
    private var debouncedRefreshTask: Task<Void, Never>?

    private init() {
        refreshDevices()
    }

    deinit {
        // Cannot call MainActor-isolated method from deinit.
        // Relying on explicit stopListening() calls from views.
    }

    /// Set the currently selected device UID to validate against.
    public func setSelectedDeviceUID(_ uid: String?) {
        selectedDeviceUID = uid
        validateSelectedDevice()
    }

    /// Start listening for CoreAudio device change notifications.
    /// Uses reference counting to support multiple consumers.
    public func startListening() {
        listenerCount += 1
        guard listenerCount == 1 else { return }  // Already listening for first caller

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Create a stable callback that doesn't capture self
        let callback: AudioObjectPropertyListenerProc = { _, _, _, _ in
            Task { @MainActor in
                AudioDeviceObserver.shared.handleDeviceChange()
            }
            return noErr
        }

        propertyListener = callback

        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            callback,
            nil
        )

        if status != noErr {
            print("[AudioDeviceObserver] Failed to add property listener: \(status)")
            propertyListener = nil
            listenerCount = 0
        }
    }

    /// Stop listening for device changes. Uses reference counting.
    public func stopListening() {
        guard listenerCount > 0 else { return }
        listenerCount -= 1
        guard listenerCount == 0 else { return }  // Still have other consumers

        guard let callback = propertyListener else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            callback,
            nil
        )

        propertyListener = nil
    }

    /// Refresh the device list and validate selected device availability.
    public func refreshDevices() {
        devices = AudioDeviceManager.inputDevices()
        validateSelectedDevice()
    }

    /// Check if the currently selected device is still available.
    public func validateSelectedDevice() {
        if let uid = selectedDeviceUID {
            selectedDeviceUnavailable = !devices.contains(where: { $0.id == uid })
        } else {
            selectedDeviceUnavailable = false
        }
    }

    private func handleDeviceChange() {
        // Cancel any existing debounced task to debounce rapid notifications
        debouncedRefreshTask?.cancel()
        
        debouncedRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)  // 250ms debounce
            guard !Task.isCancelled else { return }
            refreshDevices()
        }
    }
}

public enum AudioDeviceManager {

    /// All audio devices with at least one input stream.
    public static func inputDevices() -> [AudioInputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        ) == noErr, size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs
        ) == noErr else { return [] }

        return deviceIDs.compactMap { id in
            guard hasInputStreams(id),
                  let uid = uid(for: id),
                  let name = name(for: id) else { return nil }
            return AudioInputDevice(id: uid, name: name, deviceID: id)
        }
    }

    /// Resolve a persisted UID to a runtime AudioDeviceID. Returns nil if unplugged.
    public static func deviceID(forUID uid: String) -> AudioDeviceID? {
        inputDevices().first(where: { $0.id == uid })?.deviceID
    }

    /// Set the system default input device. Returns true on success.
    @discardableResult
    public static func setDefaultInputDevice(_ deviceID: AudioDeviceID) -> Bool {
        var mutableID = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        return AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &mutableID
        ) == noErr
    }

    /// UID of the current system default input device.
    public static func defaultInputDeviceUID() -> String? {
        var deviceID = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        ) == noErr, deviceID != kAudioDeviceUnknown else { return nil }
        return uid(for: deviceID)
    }

    // MARK: - Private

    private static func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr else {
            return false
        }
        return size > 0
    }

    private static func uid(for deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var result: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &result) == noErr,
              let uid = result?.takeUnretainedValue() else {
            return nil
        }
        return uid as String
    }

    private static func name(for deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var result: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &result) == noErr,
              let name = result?.takeUnretainedValue() else {
            return nil
        }
        return name as String
    }
}
