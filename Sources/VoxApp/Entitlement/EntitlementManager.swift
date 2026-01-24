import Combine
import Foundation

/// Entitlement state for UI and access control
enum EntitlementState: Equatable {
    case unknown
    case entitled(EntitlementCache)
    case gracePeriod(EntitlementCache)
    case expired
    case unauthenticated
    case error(String)

    static func == (lhs: EntitlementState, rhs: EntitlementState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown): return true
        case (.entitled(let a), .entitled(let b)): return a == b
        case (.gracePeriod(let a), .gracePeriod(let b)): return a == b
        case (.expired, .expired): return true
        case (.unauthenticated, .unauthenticated): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

/// Manages entitlement state with optimistic caching
/// - Loads from Keychain on init
/// - Observes AuthManager for sign-in/sign-out
/// - Background refreshes without blocking UI
@MainActor
final class EntitlementManager: ObservableObject {
    static let shared = EntitlementManager()

    @Published private(set) var state: EntitlementState = .unknown
    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?

    /// O(1) check for hotkey - never blocks
    var isAllowed: Bool {
        switch state {
        case .entitled, .gracePeriod:
            return true
        case .unknown:
            // Optimistic: allow if authenticated but haven't fetched yet
            return AuthManager.shared.isAuthenticated
        default:
            return false
        }
    }

    /// Whether a background refresh is recommended
    var shouldRefresh: Bool {
        switch state {
        case .entitled(let cache), .gracePeriod(let cache):
            return cache.isStale
        case .unknown:
            return AuthManager.shared.isAuthenticated
        default:
            return false
        }
    }

    init() {
        loadFromCache()
        observeAuthChanges()
    }

    /// Load cached entitlement from Keychain
    private func loadFromCache() {
        guard AuthManager.shared.isAuthenticated else {
            state = .unauthenticated
            return
        }

        if let cache = KeychainHelper.loadEntitlement() {
            if cache.isValid && cache.isActive {
                state = cache.isStale ? .gracePeriod(cache) : .entitled(cache)
            } else if cache.isValid && !cache.isActive {
                state = .expired
            } else {
                // Cache too old, treat as unknown until refresh
                state = .unknown
            }
        } else {
            state = .unknown
        }
    }

    /// Subscribe to auth state changes
    private func observeAuthChanges() {
        AuthManager.shared.$state
            .dropFirst() // Skip initial value
            .sink { [weak self] authState in
                Task { @MainActor in
                    self?.handleAuthChange(authState)
                }
            }
            .store(in: &cancellables)
    }

    private func handleAuthChange(_ authState: AuthManager.State) {
        switch authState {
        case .authenticated:
            Diagnostics.info("Auth state changed to authenticated, refreshing entitlements.")
            Task { await refresh() }
        case .unauthenticated:
            Diagnostics.info("Auth state changed to unauthenticated, clearing entitlements.")
            clearCache()
        case .unknown:
            break
        }
    }

    /// Fetch fresh entitlement from gateway
    func refresh() async {
        refreshTask?.cancel()

        guard let token = AuthManager.shared.token else {
            state = .unauthenticated
            return
        }

        guard let url = GatewayURL.current else {
            Diagnostics.warning("No gateway URL configured, cannot refresh entitlements.")
            return
        }

        let client = GatewayClient(baseURL: url, token: token)

        do {
            let response = try await client.getEntitlements()
            let cache = EntitlementCache(from: response)

            try? KeychainHelper.saveEntitlement(cache)

            if cache.isActive {
                state = .entitled(cache)
                Diagnostics.info("Entitlement refreshed: \(cache.plan) (\(cache.status))")
            } else {
                state = .expired
                Diagnostics.info("Entitlement expired: \(cache.plan) (\(cache.status))")
            }
        } catch let error as GatewayError {
            switch error {
            case .httpError(401, _), .httpError(403, _):
                // Token invalid or forbidden - clear and require re-auth
                Diagnostics.warning("Gateway auth failed: \(error.localizedDescription)")
                clearCache()
            default:
                // Network error - keep grace period if we have valid cache
                Diagnostics.warning("Gateway error: \(error.localizedDescription)")
                handleNetworkError(error.localizedDescription ?? "Network error")
            }
        } catch {
            Diagnostics.warning("Entitlement refresh failed: \(error.localizedDescription)")
            handleNetworkError(error.localizedDescription)
        }
    }

    private func handleNetworkError(_ message: String) {
        // If we have a valid cache, enter grace period
        if let cache = KeychainHelper.loadEntitlement(), cache.isValid {
            state = .gracePeriod(cache)
        } else {
            state = .error(message)
        }
    }

    /// Clear all cached state (on sign-out)
    func clearCache() {
        refreshTask?.cancel()
        KeychainHelper.deleteEntitlement()
        state = .unauthenticated
    }

    /// Invalidate cache (e.g., after gateway 403)
    func invalidate() {
        KeychainHelper.deleteEntitlement()
        state = AuthManager.shared.isAuthenticated ? .expired : .unauthenticated
    }
}
