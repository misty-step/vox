import AVFoundation
import CoreAudio
import Foundation
import VoxCore

public final class AudioRecorder: AudioRecording {
    public static func currentInputDeviceName() -> String? {
        var deviceID = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != kAudioDeviceUnknown else { return nil }

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        var nameRef: Unmanaged<CFString>?

        let nameStatus = withUnsafeMutablePointer(to: &nameRef) { ptr in
            AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, ptr)
        }
        guard nameStatus == noErr, let unmanagedName = nameRef else { return nil }
        return unmanagedName.takeUnretainedValue() as String
    }

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

    public init() {}

    public func start() throws {
        if recorder != nil { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vox-\(UUID().uuidString).caf")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw VoxError.internalError("Failed to start recording.")
        }
        self.recorder = recorder
        self.currentURL = url
    }

    public func currentLevel() -> (average: Float, peak: Float) {
        guard let recorder else { return (0, 0) }
        recorder.updateMeters()
        let avg = recorder.averagePower(forChannel: 0)
        let peak = recorder.peakPower(forChannel: 0)
        let minDb: Float = -50
        let avgClamped = max(min(avg, 0), minDb)
        let peakClamped = max(min(peak, 0), minDb)
        return ((avgClamped - minDb) / -minDb, (peakClamped - minDb) / -minDb)
    }

    public func stop() throws -> URL {
        guard let recorder, let url = currentURL else {
            throw VoxError.internalError("No active recording.")
        }
        recorder.stop()
        self.recorder = nil
        self.currentURL = nil
        return url
    }
}
