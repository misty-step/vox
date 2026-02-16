import SwiftUI
import VoxMac

struct BasicsSection: View {
    @ObservedObject private var prefs = PreferencesStore.shared
    var hotkeyAvailable: Bool = true
    var onRetryHotkey: () -> Void = {}
    @ObservedObject private var deviceObserver = AudioDeviceObserver.shared

    var body: some View {
        GroupBox("Basics") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Hotkey") {
                    HStack(spacing: 8) {
                        Text("Option + Space")
                            .font(.system(.body, design: .monospaced))

                        if !hotkeyAvailable {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .help("Hotkey unavailable")
                        }
                    }
                }

                if !hotkeyAvailable {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hotkey unavailable")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.orange)

                        Text("Another app may be using Option+Space. You can still start dictation from the menu bar menu, or click Retry to attempt registration again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Retry Hotkey Registration") {
                            onRetryHotkey()
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
                        ForEach(deviceObserver.devices) { device in
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
            deviceObserver.setSelectedDeviceUID(prefs.selectedInputDeviceUID)
            deviceObserver.startListening()
        }
        .onDisappear {
            deviceObserver.stopListening()
        }
        .onChange(of: prefs.selectedInputDeviceUID) { _, newUID in
            deviceObserver.setSelectedDeviceUID(newUID)
        }
    }
}
