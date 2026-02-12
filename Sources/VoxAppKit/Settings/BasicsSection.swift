import SwiftUI
import VoxMac

struct BasicsSection: View {
    @ObservedObject private var prefs = PreferencesStore.shared
    @State private var devices: [AudioInputDevice] = []

    var body: some View {
        Section("Basics") {
            HStack(spacing: 12) {
                Text("Hotkey")
                Spacer(minLength: 0)
                Text("Option + Space")
                    .font(.system(.body, design: .monospaced))
            }

            Picker("Microphone", selection: $prefs.selectedInputDeviceUID) {
                Text("System Default").tag(nil as String?)
                ForEach(devices) { device in
                    Text(device.name).tag(device.id as String?)
                }
            }

            Text("Vox falls back to the system default route if a selected device is unavailable.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { devices = AudioDeviceManager.inputDevices() }
    }
}
