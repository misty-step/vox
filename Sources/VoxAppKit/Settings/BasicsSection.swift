import SwiftUI
import VoxMac

struct BasicsSection: View {
    @ObservedObject private var prefs = PreferencesStore.shared
    @State private var devices: [AudioInputDevice] = []
    @ObservedObject var hotkeyStateStore: HotkeyStateStore

    var body: some View {
        GroupBox("Basics") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Hotkey") {
                    HStack(spacing: 8) {
                        Text("Option + Space")
                            .font(.system(.body, design: .monospaced))

                        if !hotkeyStateStore.isAvailable {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .help("Hotkey unavailable")
                        }
                    }
                }

                if !hotkeyStateStore.isAvailable {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hotkey unavailable")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.orange)

                        Text("Another app may be using Option+Space. You can still start dictation from the menu bar menu, or click Retry to attempt registration again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Retry Hotkey Registration") {
                            hotkeyStateStore.onRetryHotkey?()
                        }
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
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
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { devices = AudioDeviceManager.inputDevices() }
    }
}
