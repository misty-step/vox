import SwiftUI
import VoxCore
import VoxMac

public struct ProcessingTab: View {
    @ObservedObject private var prefs = PreferencesStore.shared

    public init() {}

    public var body: some View {
        Form {
            Section("Processing") {
                Picker("Rewrite Level", selection: $prefs.processingLevel) {
                    Text("Off").tag(ProcessingLevel.off)
                    Text("Light").tag(ProcessingLevel.light)
                    Text("Aggressive").tag(ProcessingLevel.aggressive)
                    Text("Enhance").tag(ProcessingLevel.enhance)
                }

                Picker("Model", selection: $prefs.selectedModel) {
                    ForEach(PreferencesStore.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }

            Section("Custom Context") {
                TextEditor(text: $prefs.customContext)
                    .frame(minHeight: 120)
                    .font(.system(size: 12))
            }

            Section("Input") {
                Text(AudioRecorder.currentInputDeviceName() ?? "Unknown microphone")
            }
        }
        .padding(12)
    }
}
