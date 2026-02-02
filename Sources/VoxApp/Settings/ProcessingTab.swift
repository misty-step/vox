import SwiftUI
import VoxMac

public struct ProcessingTab: View {
    @ObservedObject private var prefs = PreferencesStore.shared

    public init() {}

    public var body: some View {
        Form {
            Section("Input") {
                Text(AudioRecorder.currentInputDeviceName() ?? "Unknown microphone")
            }
        }
        .padding(12)
    }
}
