import SwiftUI
import VoxCore
import VoxMac

/// Connection status for Vox Cloud token
enum VoxCloudConnectionStatus: Equatable {
    case missing
    case testing
    case invalidToken
    case error(String)
    case ready(used: Int, remaining: Int)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .missing:
            return "No token configured"
        case .testing:
            return "Testing connection..."
        case .invalidToken:
            return "Invalid token"
        case .error(let message):
            return "Error: \(message)"
        case .ready(let used, let remaining):
            return "Connected • \(remaining) min remaining of \(used + remaining) total"
        }
    }

    var statusColor: Color {
        switch self {
        case .missing:
            return .secondary
        case .testing:
            return .orange
        case .invalidToken, .error:
            return .red
        case .ready:
            return .green
        }
    }
}

/// Sheet for entering and managing Vox Cloud token
struct VoxCloudTokenSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var prefs = PreferencesStore.shared

    @State private var tokenInput: String = ""
    @State private var connectionStatus: VoxCloudConnectionStatus = .missing
    @State private var isTesting = false

    private let api = VoxCloudAPI()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerSection
            Divider()
            contentSection
            Divider()
            footerSection
        }
        .frame(minWidth: 520, minHeight: 380)
        .onAppear {
            loadExistingToken()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vox Cloud")
                .font(.title3.weight(.semibold))
            Text("Enter your Vox Cloud token to enable cloud transcription and rewriting without individual provider keys.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vox Cloud Token")
                        .font(.subheadline.weight(.semibold))

                    if hasStoredToken {
                        HStack {
                            Text(String(repeating: "•", count: 24))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Clear") {
                                clearToken()
                            }
                            .foregroundStyle(.red)
                        }
                    } else {
                        SecureField("Enter your Vox Cloud token", text: $tokenInput)
                            .textContentType(.password)
                            .textFieldStyle(.roundedBorder)
                    }

                    Text("Get your token from your Vox Cloud dashboard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }

            statusSection

            HStack(spacing: 12) {
                Button(action: testConnection) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text("Test Connection")
                    }
                }
                .disabled(isTesting || (tokenInput.isEmpty && !hasStoredToken))

                if hasStoredToken {
                    Button(action: testConnection) {
                        Text("Refresh Status")
                    }
                    .disabled(isTesting)
                }
            }
        }
        .padding(16)
    }

    private var statusSection: some View {
        GroupBox {
            HStack {
                Circle()
                    .fill(connectionStatus.statusColor)
                    .frame(width: 8, height: 8)
                Text(connectionStatus.displayText)
                    .font(.subheadline)
                    .foregroundStyle(connectionStatus.statusColor)
                Spacer()
            }
            .padding(8)

            if case .error = connectionStatus, let error = connectionStatusError {
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if case .invalidToken = connectionStatus {
                VStack(alignment: .leading, spacing: 4) {
                    Text("The token you entered is invalid or has been revoked.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Go to your Vox Cloud dashboard to generate a new token.")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if connectionStatus.isReady {
                quotaSection
            }
        }
    }

    private var quotaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quota Status")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if case .ready(let used, let remaining) = connectionStatus {
                let total = used + remaining
                let usedPercent = total > 0 ? Double(used) / Double(total) : 0

                ProgressView(value: usedPercent)
                    .tint(usedPercent > 0.8 ? .red : .green)

                HStack {
                    Text("\(used) min used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(remaining) min remaining")
                        .font(.caption)
                        .foregroundStyle(remaining < 100 ? .red : .secondary)
                }
            }
        }
        .padding(8)
    }

    private var footerSection: some View {
        HStack {
            Spacer(minLength: 0)
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    private var hasStoredToken: Bool {
        !prefs.voxCloudToken.isEmpty
    }

    private var connectionStatusError: Error? {
        switch connectionStatus {
        case .error(let message):
            return NSError(domain: "VoxCloud", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        case .invalidToken:
            return VoxCloudAPIError.invalidToken
        default:
            return nil
        }
    }

    private func loadExistingToken() {
        if hasStoredToken {
            connectionStatus = .ready(used: 0, remaining: 0)
            Task {
                await testConnectionAndUpdateStatus()
            }
        } else {
            connectionStatus = .missing
        }
    }

    private func testConnection() {
        if !tokenInput.isEmpty {
            prefs.voxCloudToken = tokenInput
            tokenInput = ""
        }
        Task {
            await testConnectionAndUpdateStatus()
        }
    }

    private func testConnectionAndUpdateStatus() async {
        isTesting = true
        connectionStatus = .testing

        let token = prefs.voxCloudToken
        guard !token.isEmpty else {
            connectionStatus = .missing
            isTesting = false
            return
        }

        do {
            let quota = try await api.fetchQuota(token: token)
            connectionStatus = .ready(used: quota.used, remaining: quota.remaining)
            prefs.voxCloudEnabled = true
        } catch let error as VoxCloudAPIError {
            switch error {
            case .invalidToken:
                connectionStatus = .invalidToken
            default:
                connectionStatus = .error(error.localizedDescription)
            }
            prefs.voxCloudEnabled = false
        } catch {
            connectionStatus = .error(error.localizedDescription)
            prefs.voxCloudEnabled = false
        }

        isTesting = false
    }

    private func clearToken() {
        prefs.voxCloudToken = ""
        prefs.voxCloudEnabled = false
        connectionStatus = .missing
    }
}

#if DEBUG
struct VoxCloudTokenSheet_Previews: PreviewProvider {
    static var previews: some View {
        VoxCloudTokenSheet()
    }
}
#endif
