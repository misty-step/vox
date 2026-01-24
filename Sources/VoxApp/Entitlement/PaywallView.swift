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

    @ViewBuilder
    private var title: some View {
        switch state {
        case .unauthenticated:
            Text("Sign In Required")
                .font(.title2)
                .fontWeight(.semibold)
        case .expired:
            Text("Subscription Expired")
                .font(.title2)
                .fontWeight(.semibold)
        case .error(let message):
            Text("Connection Error")
                .font(.title2)
                .fontWeight(.semibold)
        default:
            Text("Vox")
                .font(.title2)
                .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        switch state {
        case .unauthenticated:
            Text("Sign in to your account to use Vox dictation.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        case .expired:
            Text("Your trial or subscription has ended. Upgrade to continue using Vox.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        case .error(let message):
            Text("Unable to verify your subscription. Check your internet connection and try again.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        default:
            EmptyView()
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
