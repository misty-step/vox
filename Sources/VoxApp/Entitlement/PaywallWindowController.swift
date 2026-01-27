import AppKit
import Combine
import SwiftUI

/// AppKit window controller hosting the SwiftUI PaywallView
final class PaywallWindowController: NSWindowController {
    private static var shared: PaywallWindowController?
    private var cancellables = Set<AnyCancellable>()
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
        guard let url = GatewayURL.authDesktop else {
            Diagnostics.error("No gateway URL configured for sign-in.")
            return
        }
        Diagnostics.info("Opening sign-in page: \(url.absoluteString)")
        NSWorkspace.shared.open(url)
        startAuthPolling()
    }

    private func handleUpgrade() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let auth = currentAuth() else { return }
            guard let token = await auth.currentToken() else {
                Diagnostics.error("No auth token for checkout.")
                handleSignIn()
                return
            }
            guard let url = GatewayURL.checkoutPage(token: token) else {
                Diagnostics.error("No gateway URL configured for upgrade.")
                return
            }
            Diagnostics.info("Opening checkout: \(url.absoluteString)")
            NSWorkspace.shared.open(url)
            startPaymentPolling()
        }
    }

    private func startAuthPolling() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor in
            let intervals: [UInt64] = [2, 2, 5, 5, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10]

            for interval in intervals {
                if Task.isCancelled { return }

                guard let auth = currentAuth() else { return }
                if await auth.currentToken() != nil {
                    Diagnostics.info("Auth detected, refreshing entitlements.")
                    await auth.refresh(force: true)
                    if auth.isAllowed {
                        Diagnostics.info("Entitlement confirmed, closing paywall.")
                        dismiss()
                        return
                    }
                }

                try? await Task.sleep(nanoseconds: interval * 1_000_000_000)
            }

            Diagnostics.info("Auth polling timed out.")
        }
    }

    private func startPaymentPolling() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor in
            for _ in 0..<12 {
                if Task.isCancelled { return }

                guard let auth = currentAuth() else { return }
                await auth.refresh(force: true)
                if auth.isAllowed {
                    Diagnostics.info("Payment confirmed, closing paywall.")
                    dismiss()
                    return
                }

                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }

            Diagnostics.info("Payment polling timed out.")
        }
    }

    private func dismiss() {
        pollingTask?.cancel()
        window?.close()
        onDismiss?()
        Self.shared = nil
    }

    override func close() {
        dismiss()
    }

    private func startEntitlementObservation() {
        guard cancellables.isEmpty else { return }

        guard let auth = AppDelegate.currentAuth() else {
            Diagnostics.error("Missing VoxAuth for paywall.")
            return
        }

        auth.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self else { return }
                let entitlement = entitlementState(from: newState)
                updateContent(state: entitlement)
                if entitlement == .entitled || entitlement == .gracePeriod {
                    close()
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func currentAuth() -> VoxAuth? {
        guard let auth = AppDelegate.currentAuth() else {
            Diagnostics.error("Missing VoxAuth.")
            return nil
        }
        return auth
    }

    private func entitlementState(from state: VoxAuth.State) -> EntitlementState {
        switch state {
        case .allowed:
            return .entitled
        case .needsAuth:
            return .unauthenticated
        case .needsSubscription:
            return .expired
        case .error(let message):
            return .error(message)
        case .unknown, .checking:
            return .unknown
        }
    }

    // MARK: - Static API

    @MainActor
    static func show(for state: EntitlementState, onDismiss: @escaping () -> Void = {}) {
        if let existing = shared {
            existing.updateContent(state: state)
            existing.startEntitlementObservation()
            existing.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = PaywallWindowController(state: state, onDismiss: onDismiss)
        shared = controller
        controller.startEntitlementObservation()
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    static func hide() {
        shared?.dismiss()
    }
}
