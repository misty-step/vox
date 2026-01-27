import Foundation

/// Errors from token operations
enum TokenError: Error {
    case noToken
    case refreshFailed
    case invalidToken
}

/// Protocol for token storage (allows testing with mocks)
protocol TokenStorage: Sendable {
    func save(token: String, expiresAt: Date?) async throws
    func load() async -> (token: String, expiresAt: Date?)?
    func clear() async
}

/// Protocol for token refresh (allows testing with mocks)
protocol TokenRefresher: Sendable {
    func refresh() async throws -> (token: String, expiresAt: Date?)
}

/// Single source of truth for auth tokens.
/// Handles caching, expiry, refresh, and concurrent access.
protocol TokenService: Sendable {
    /// Returns a valid token, refreshing if necessary.
    /// Throws if no token available and refresh fails.
    func validToken() async throws -> String

    /// Clears the current token (sign out)
    func clearToken() async

    /// Whether we have a token (may be expired)
    var isAuthenticated: Bool { get async }
}

/// Concrete implementation of TokenService
actor TokenServiceImpl: TokenService {
    private let storage: TokenStorage
    private let refresher: TokenRefresher

    // Cached state
    private var cachedToken: String?
    private var cachedExpiry: Date?
    private var hasLoaded = false

    // Coalesce concurrent refresh requests
    private var activeRefresh: Task<(token: String, expiresAt: Date?), Error>?

    init(storage: TokenStorage, refresher: TokenRefresher) {
        self.storage = storage
        self.refresher = refresher
    }

    var isAuthenticated: Bool {
        get async {
            await loadIfNeeded(forceReloadIfEmpty: true)
            return cachedToken != nil
        }
    }

    func validToken() async throws -> String {
        await loadIfNeeded(forceReloadIfEmpty: true)

        // Check if cached token is still valid
        if let token = cachedToken, !isExpired(cachedExpiry) {
            return token
        }

        // Need to refresh - coalesce concurrent calls
        if let active = activeRefresh {
            do {
                let result = try await active.value
                cachedToken = result.token
                cachedExpiry = result.expiresAt
                return result.token
            } catch {
                await clearTokenInternal()
                throw error
            }
        }

        let task = Task<(token: String, expiresAt: Date?), Error> { [refresher, storage] in
            let result = try await refresher.refresh()
            try await storage.save(token: result.token, expiresAt: result.expiresAt)
            return result
        }

        activeRefresh = task
        defer { activeRefresh = nil }

        do {
            let result = try await task.value
            cachedToken = result.token
            cachedExpiry = result.expiresAt
            return result.token
        } catch {
            await clearTokenInternal()
            throw error
        }
    }

    func clearToken() async {
        await clearTokenInternal()
    }

    private func clearTokenInternal() async {
        cachedToken = nil
        cachedExpiry = nil
        await storage.clear()
    }

    private func loadIfNeeded(forceReloadIfEmpty: Bool = false) async {
        if hasLoaded, !(forceReloadIfEmpty && cachedToken == nil) { return }
        hasLoaded = true

        if let stored = await storage.load() {
            cachedToken = stored.token
            cachedExpiry = stored.expiresAt
        } else {
            cachedToken = nil
            cachedExpiry = nil
        }
    }

    private func isExpired(_ expiry: Date?) -> Bool {
        guard let expiry = expiry else {
            // No expiry = assume valid
            return false
        }
        // Add a small buffer to refresh before hard expiry
        return Date() >= expiry.addingTimeInterval(-30)
    }
}

// MARK: - Keychain-backed storage implementation

/// Production storage that uses KeychainHelper
struct KeychainTokenStorage: TokenStorage {
    func save(token: String, expiresAt: Date?) async throws {
        KeychainHelper.saveSessionToken(token)
        if let expiresAt {
            KeychainHelper.saveTokenExpiry(expiresAt)
        } else {
            KeychainHelper.clearTokenExpiry()
        }
    }

    func load() async -> (token: String, expiresAt: Date?)? {
        guard let token = KeychainHelper.sessionToken else { return nil }
        return (token, KeychainHelper.tokenExpiry)
    }

    func clear() async {
        KeychainHelper.clearSessionToken()
        KeychainHelper.clearTokenExpiry()
    }
}
