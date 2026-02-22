import SwiftUI
import VoxMac

struct BasicsSection: View {
    @ObservedObject private var prefs = PreferencesStore.shared
    @ObservedObject var hotkeyState: HotkeyState
    @ObservedObject private var deviceObserver = AudioDeviceObserver.shared

    var body: some View {
        SettingsSection(
            title: "Basics",
            systemImage: "keyboard",
            prominence: .primary
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hotkey")
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 8) {
                        KeyboardShortcutBadge(text: "⌥ Space")

                        if !hotkeyState.isAvailable {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .help("Hotkey unavailable")
                        }
                    }
                }

                if !hotkeyState.isAvailable {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Hotkey unavailable")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)

                        Text("Another app may be using Option+Space. You can still start dictation from the menu bar menu, or click Retry to attempt registration again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Retry Hotkey Registration") { hotkeyState.onRetry() }
                            .controlSize(.small)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.orange.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.orange.opacity(0.30), lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Microphone")
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.secondary)
                        Picker("", selection: $prefs.selectedInputDeviceUID) {
                            Text("System Default").tag(nil as String?)
                            ForEach(deviceObserver.devices) { device in
                                Text(device.name).tag(device.id as String?)
                            }
                        }
                        .labelsHidden()
                    }
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

private struct KeyboardShortcutBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(0.18), lineWidth: 1)
            )
    }
}
