import SwiftUI
import VoxMac

struct BasicsSection: View {
    @ObservedObject private var prefs = PreferencesStore.shared
    @ObservedObject private var deviceObserver = AudioDeviceObserver.shared
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

                if deviceObserver.selectedDeviceUnavailable {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("Your selected microphone is unavailable. Using system default.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("Falls back to system default if the selected device is unavailable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            devices = AudioDeviceManager.inputDevices()
            deviceObserver.setSelectedDeviceUID(prefs.selectedInputDeviceUID)
            deviceObserver.startListening()
        }
        .onDisappear {
            deviceObserver.stopListening()
        }
        .onReceive(deviceObserver.$devices) { newDevices in
            devices = newDevices
        }
        .onChange(of: prefs.selectedInputDeviceUID) { _, newUID in
            deviceObserver.setSelectedDeviceUID(newUID)
        }
    }
}
