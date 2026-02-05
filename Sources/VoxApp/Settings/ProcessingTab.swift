import SwiftUI
import VoxMac

public struct ProcessingTab: View {
    @ObservedObject private var prefs = PreferencesStore.shared
    @State private var devices: [AudioInputDevice] = []

    public init() {}

    public var body: some View {
        Form {
            Section("Input") {
                Picker("Microphone", selection: $prefs.selectedInputDeviceUID) {
                    Text("System Default").tag(nil as String?)
                    ForEach(devices) { device in
                        Text(device.name).tag(device.id as String?)
                    }
                }
            }
        }
        .padding(12)
        .onAppear { devices = AudioDeviceManager.inputDevices() }
    }
}
