import SwiftUI
import VoxMac

public struct ProcessingTab: View {
    @ObservedObject private var prefs = PreferencesStore.shared

    public init() {}

    public var body: some View {
        Form {
            Section("Model") {
                Picker("Model", selection: $prefs.selectedModel) {
                    ForEach(PreferencesStore.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }

            Section("Input") {
                Text(AudioRecorder.currentInputDeviceName() ?? "Unknown microphone")
            }
        }
        .padding(12)
    }
}
