import SwiftUI

struct PaywallView: View {
    let state: EntitlementState
    let onSignIn: () -> Void
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            icon
            title
            subtitle
            buttons
        }
        .padding(32)
        .frame(width: 320)
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .unauthenticated:
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.blue)
        case .expired:
            Image(systemName: "lock.circle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
        case .error:
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.red)
        default:
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
        }
    }

    private var title: some View {
        let text: String = switch state {
        case .unauthenticated: "Sign In Required"
        case .expired: "Subscription Expired"
        case .error: "Connection Error"
        default: "Vox"
        }
        return Text(text)
            .font(.title2)
            .fontWeight(.semibold)
    }

    @ViewBuilder
    private var subtitle: some View {
        let text: String? = switch state {
        case .unauthenticated: "Sign in to your account to use Vox dictation."
        case .expired: "Your trial or subscription has ended. Upgrade to continue using Vox."
        case .error: "Unable to verify your subscription. Check your internet connection and try again."
        default: nil
        }
        if let text {
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: 12) {
            switch state {
            case .unauthenticated:
                Button(action: onSignIn) {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            case .expired:
                Button(action: onUpgrade) {
                    Text("Upgrade Now")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            case .error:
                Button(action: {
                    Task { await EntitlementManager.shared.refresh() }
                }) {
                    Text("Retry")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            default:
                EmptyView()
            }

            Button(action: onDismiss) {
                Text("Dismiss")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

#Preview("Unauthenticated") {
    PaywallView(
        state: .unauthenticated,
        onSignIn: {},
        onUpgrade: {},
        onDismiss: {}
    )
}

#Preview("Expired") {
    PaywallView(
        state: .expired,
        onSignIn: {},
        onUpgrade: {},
        onDismiss: {}
    )
}

#Preview("Error") {
    PaywallView(
        state: .error("Network timeout"),
        onSignIn: {},
        onUpgrade: {},
        onDismiss: {}
    )
}
