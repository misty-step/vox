import AppKit
import SwiftUI

/// AppKit window controller hosting the SwiftUI PaywallView
final class PaywallWindowController: NSWindowController {
    private static var shared: PaywallWindowController?
    private var pollingTask: Task<Void, Never>?
    private var onDismiss: (() -> Void)?

    private init(state: EntitlementState, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vox"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        updateContent(state: state)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateContent(state: EntitlementState) {
        let view = PaywallView(
            state: state,
            onSignIn: { [weak self] in self?.handleSignIn() },
            onUpgrade: { [weak self] in self?.handleUpgrade() },
            onDismiss: { [weak self] in self?.dismiss() }
        )
        let hostingController = NSHostingController(rootView: view)
        window?.contentViewController = hostingController
    }

    private func handleSignIn() {
        // Open web auth page
        guard let gatewayURL = gatewayURL() else {
            Diagnostics.error("No gateway URL configured for sign-in")
            return
        }

        // The auth page is on the web app, not gateway
        // Derive web URL from gateway URL (same origin, /auth/desktop path)
        var components = URLComponents(url: gatewayURL, resolvingAgainstBaseURL: false)
        components?.path = "/auth/desktop"

        guard let url = components?.url else {
            Diagnostics.error("Failed to construct auth URL")
            return
        }

        Diagnostics.info("Opening sign-in page: \(url.absoluteString)")
        NSWorkspace.shared.open(url)

        // Start polling for auth completion
        startAuthPolling()
    }

    private func handleUpgrade() {
        // Open checkout page
        guard let gatewayURL = gatewayURL() else {
            Diagnostics.error("No gateway URL configured for upgrade")
            return
        }

        let checkoutURL = gatewayURL.appendingPathComponent("api/stripe/checkout")
        Diagnostics.info("Opening checkout: \(checkoutURL.absoluteString)")
        NSWorkspace.shared.open(checkoutURL)

        // Start polling for payment completion
        startPaymentPolling()
    }

    private func startAuthPolling() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor in
            // Poll for up to 5 minutes with exponential backoff
            let intervals: [UInt64] = [2, 2, 5, 5, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10]

            for interval in intervals {
                if Task.isCancelled { return }

                // Check if auth completed via deep link
                if AuthManager.shared.token != nil {
                    Diagnostics.info("Auth detected, refreshing entitlements")
                    await EntitlementManager.shared.refresh()

                    if EntitlementManager.shared.isAllowed {
                        Diagnostics.info("Entitlement confirmed, closing paywall")
                        dismiss()
                        return
                    }
                }

                try? await Task.sleep(nanoseconds: interval * 1_000_000_000)
            }

            Diagnostics.info("Auth polling timed out")
        }
    }

    private func startPaymentPolling() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor in
            // Poll for up to 60 seconds
            for _ in 0..<12 {
                if Task.isCancelled { return }

                await EntitlementManager.shared.refresh()

                if EntitlementManager.shared.isAllowed {
                    Diagnostics.info("Payment confirmed, closing paywall")
                    dismiss()
                    return
                }

                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }

            Diagnostics.info("Payment polling timed out")
        }
    }

    private func dismiss() {
        pollingTask?.cancel()
        window?.close()
        onDismiss?()
        Self.shared = nil
    }

    private func gatewayURL() -> URL? {
        guard let raw = ProcessInfo.processInfo.environment["VOX_GATEWAY_URL"],
              !raw.isEmpty,
              let url = URL(string: raw) else {
            return nil
        }
        return url
    }

    // MARK: - Static API

    @MainActor
    static func show(for state: EntitlementState, onDismiss: @escaping () -> Void = {}) {
        if let existing = shared {
            existing.updateContent(state: state)
            existing.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = PaywallWindowController(state: state, onDismiss: onDismiss)
        shared = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    static func hide() {
        shared?.dismiss()
    }
}
