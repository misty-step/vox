import XCTest
@testable import VoxMac
import Foundation

@MainActor
final class AudioDeviceObserverTests: XCTestCase {
    var observer: AudioDeviceObserver!

    override func setUp() {
        super.setUp()
        observer = AudioDeviceObserver.shared
        observer.stopListening()
    }

    override func tearDown() {
        observer.stopListening()
        super.tearDown()
    }

    func testInitialDevicesLoaded() throws {
        // Skip in CI environments or machines without audio input devices
        guard !observer.devices.isEmpty else {
            throw XCTSkip("No audio input devices available")
        }
        // Device list should be populated on init
        XCTAssertFalse(observer.devices.isEmpty, "Devices should be loaded on initialization")
    }

    func testSetSelectedDeviceUID() {
        // When no device is selected, unavailable should be false
        observer.setSelectedDeviceUID(nil)
        XCTAssertFalse(observer.selectedDeviceUnavailable)

        // Set a non-existent device UID
        observer.setSelectedDeviceUID("non-existent-device-uid")
        XCTAssertTrue(observer.selectedDeviceUnavailable, "Non-existent device should be marked as unavailable")
    }

    func testValidateSelectedDeviceWithAvailableDevice() throws {
        // Get the first available device
        let availableDevices = AudioDeviceManager.inputDevices()
        guard let firstDevice = availableDevices.first else {
            throw XCTSkip("No audio input devices available for testing")
        }

        observer.setSelectedDeviceUID(firstDevice.id)
        XCTAssertFalse(observer.selectedDeviceUnavailable, "Available device should not be marked as unavailable")
    }

    func testStartListeningDoesNotCrash() {
        // Starting listening should not throw or crash
        observer.startListening()
        XCTAssertTrue(true, "Start listening completed without crash")
    }

    func testStopListeningDoesNotCrash() {
        // Stop listening should not throw or crash even if not started
        observer.stopListening()
        XCTAssertTrue(true, "Stop listening completed without crash")

        // Should also work after starting
        observer.startListening()
        observer.stopListening()
        XCTAssertTrue(true, "Stop listening after start completed without crash")
    }

    func testRefreshDevicesUpdatesDeviceList() {
        let initialDevices = observer.devices
        observer.refreshDevices()
        XCTAssertEqual(observer.devices.count, initialDevices.count, "Device count should remain consistent")
    }
}

final class AudioDeviceManagerTests: XCTestCase {

    func testInputDevicesReturnsNonNil() {
        let devices = AudioDeviceManager.inputDevices()
        // May be empty if no input devices, but should not crash
        XCTAssertNotNil(devices)
    }

    func testDefaultInputDeviceUID() {
        _ = AudioDeviceManager.defaultInputDeviceUID()
        // May be nil if no default device, but should not crash
        XCTAssertTrue(true, "defaultInputDeviceUID completed without crash")
    }

    func testDeviceIDForUID() {
        // Test with non-existent UID
        let deviceID = AudioDeviceManager.deviceID(forUID: "non-existent-uid")
        XCTAssertNil(deviceID, "Non-existent UID should return nil deviceID")

        // Test with actual device if available
        let devices = AudioDeviceManager.inputDevices()
        if let firstDevice = devices.first {
            let resolvedID = AudioDeviceManager.deviceID(forUID: firstDevice.id)
            XCTAssertNotNil(resolvedID, "Valid device UID should resolve to a deviceID")
        }
    }
}
