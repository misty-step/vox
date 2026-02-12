import AppKit
import AVFoundation
import SwiftUI
import VoxMac

struct OnboardingChecklistView: View {
    @ObservedObject private var prefs = PreferencesStore.shared
    @ObservedObject private var onboarding: OnboardingStore
    private let onOpenSettings: () -> Void

    @State private var accessibilityTrusted = PermissionManager.isAccessibilityTrusted()
    @State private var microphoneStatus = PermissionManager.microphoneAuthorizationStatus()
    @State private var showingCloudKeys = false

    init(onboarding: OnboardingStore, onOpenSettings: @escaping () -> Void) {
        self.onboarding = onboarding
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    requiredSection
                    optionalSection
                }
                .padding(16)
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
        .sheet(isPresented: $showingCloudKeys) {
            CloudKeysSheet()
                .frame(minWidth: 640, minHeight: 520)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(requiredStepsComplete ? "Setup complete" : "Finish setup")
                .font(.title3.weight(.semibold))
            Text("Vox works out of the box (Apple Speech). Add cloud keys for faster transcription and rewriting.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var requiredSection: some View {
        GroupBox("Required") {
            VStack(alignment: .leading, spacing: 10) {
                ChecklistRow(
                    title: "Accessibility permission",
                    status: accessibilityStatusText,
                    isComplete: accessibilityTrusted,
                    actionTitle: accessibilityTrusted ? nil : "Open System Settings",
                    action: accessibilityTrusted ? nil : openAccessibilityPrivacy
                )

                ChecklistRow(
                    title: "Microphone permission",
                    status: microphoneStatusText,
                    isComplete: microphoneStatus == .authorized,
                    actionTitle: microphoneActionTitle,
                    action: microphoneStatus == .authorized ? nil : handleMicrophoneAction
                )
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var optionalSection: some View {
        GroupBox("Optional") {
            VStack(alignment: .leading, spacing: 10) {
                ChecklistRow(
                    title: "Cloud provider keys",
                    status: cloudStatusText,
                    isComplete: hasCloudSTT || hasRewrite,
                    actionTitle: "Manage Keys...",
                    action: { showingCloudKeys = true }
                )

                ChecklistRow(
                    title: "Microphone selection",
                    status: "Selected: \(selectedMicrophoneText)",
                    isComplete: true,
                    actionTitle: "Open Settings...",
                    action: onOpenSettings
                )

                ChecklistRow(
                    title: "Test dictation",
                    status: onboarding.hasCompletedFirstDictation ? "Done" : "Press Option+Space to try",
                    isComplete: onboarding.hasCompletedFirstDictation,
                    actionTitle: onboarding.hasCompletedFirstDictation ? nil : "Tips",
                    action: onboarding.hasCompletedFirstDictation ? nil : showDictationTips
                )
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var requiredStepsComplete: Bool {
        accessibilityTrusted
            && microphoneStatus == .authorized
    }

    private var selectedMicrophoneText: String {
        prefs.selectedInputDeviceUID == nil ? "System Default" : "Custom"
    }

    private var hasCloudSTT: Bool {
        isConfigured(prefs.elevenLabsAPIKey)
            || isConfigured(prefs.deepgramAPIKey)
            || isConfigured(prefs.openAIAPIKey)
    }

    private var hasRewrite: Bool {
        isConfigured(prefs.geminiAPIKey)
            || isConfigured(prefs.openRouterAPIKey)
    }

    private var cloudStatusText: String {
        switch (hasCloudSTT, hasRewrite) {
        case (true, true):
            return "Transcription + rewrite ready"
        case (true, false):
            return "Cloud STT ready; rewrite not configured"
        case (false, true):
            return "Rewrite ready; transcription on-device"
        case (false, false):
            return "On-device only"
        }
    }

    private var accessibilityStatusText: String {
        accessibilityTrusted ? "Granted" : "Required to paste into other apps"
    }

    private var microphoneStatusText: String {
        switch microphoneStatus {
        case .authorized:
            return "Granted"
        case .notDetermined:
            return "Not yet requested"
        case .denied:
            return "Denied in System Settings"
        case .restricted:
            return "Restricted by system policy"
        @unknown default:
            return "Unknown"
        }
    }

    private var microphoneActionTitle: String? {
        switch microphoneStatus {
        case .authorized:
            return nil
        case .notDetermined:
            return "Request Access"
        case .denied, .restricted:
            return "Open System Settings"
        @unknown default:
            return "Refresh"
        }
    }

    private func refresh() {
        accessibilityTrusted = PermissionManager.isAccessibilityTrusted()
        microphoneStatus = PermissionManager.microphoneAuthorizationStatus()
    }

    private func openAccessibilityPrivacy() {
        PermissionManager.promptForAccessibilityIfNeeded()
        _ = SystemSettingsLink.openAccessibilityPrivacy()
        refresh()
    }

    private func handleMicrophoneAction() {
        switch microphoneStatus {
        case .notDetermined:
            Task {
                _ = await PermissionManager.requestMicrophoneAccess()
                refresh()
            }
        case .denied, .restricted:
            _ = SystemSettingsLink.openMicrophonePrivacy()
            refresh()
        default:
            refresh()
        }
    }

    private func showDictationTips() {
        let alert = NSAlert()
        alert.messageText = "Try dictation"
        alert.informativeText = """
        1) Click into any text field.
        2) Press Option+Space to start.
        3) Speak, then press Option+Space again to stop.

        If nothing pastes, check Accessibility permission above.
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func isConfigured(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct ChecklistRow: View {
    let title: String
    let status: String
    let isComplete: Bool
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isComplete ? .green : .orange)
                .accessibilityLabel(isComplete ? "Complete" : "Needs attention")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let actionTitle, let action {
                Button(actionTitle) { action() }
            }
        }
    }
}
