import SwiftUI
import VoxMac

public struct ProcessingTab: View {
    @ObservedObject private var prefs = PreferencesStore.shared
    @State private var devices: [AudioInputDevice] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dictation Routing")
                .font(.headline)
            Text("Select the preferred input device. Vox falls back to the system default route if a selected device is unavailable.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Form {
                Section("Input Device") {
                    Picker("Microphone", selection: $prefs.selectedInputDeviceUID) {
                        Text("System Default").tag(nil as String?)
                        ForEach(devices) { device in
                            Text(device.name).tag(device.id as String?)
                        }
                    }

                    Text("Processing level remains available from the menu bar so recording can stay uninterrupted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .onAppear { devices = AudioDeviceManager.inputDevices() }
    }
}
