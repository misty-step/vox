import SwiftUI
import VoxMac

struct BasicsSection: View {
    @ObservedObject private var prefs = PreferencesStore.shared
    @State private var devices: [AudioInputDevice] = []

    var body: some View {
        GroupBox("Basics") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Hotkey") {
                    Text("Option + Space")
                        .font(.system(.body, design: .monospaced))
                }

                LabeledContent("Microphone") {
                    Picker("", selection: $prefs.selectedInputDeviceUID) {
                        Text("System Default").tag(nil as String?)
                        ForEach(devices) { device in
                            Text(device.name).tag(device.id as String?)
                        }
                    }
                    .labelsHidden()
                }

                Text("Falls back to system default if the selected device is unavailable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -2)
            }
            .padding(12)
        }
        .onAppear { devices = AudioDeviceManager.inputDevices() }
    }
}
