import Foundation
import Security
import VoxCore

/// Single source of truth for authentication and entitlement.
/// Hides: keychain, JWT lifecycle, TTL, caching, refresh logic.
@MainActor
final class VoxAuth: ObservableObject {
    enum State: Equatable {
        case unknown
        case checking
        case allowed
        case needsAuth
        case needsSubscription
        case error(String)
    }

    @Published private(set) var state: State = .unknown

    var isAllowed: Bool { state == .allowed }

    private let storage: VoxAuthStorage
    private let gateway: VoxAuthGateway?
    private let clock: VoxAuthClock

    private var activeCheckTask: Task<State, Never>?
    private var backgroundRefreshTask: Task<Void, Never>?

    init(
        storage: VoxAuthStorage = KeychainVoxAuthStorage(),
        gateway: VoxAuthGateway? = VoxAuth.defaultGateway(),
        clock: VoxAuthClock = SystemClock()
    ) {
        self.storage = storage
        self.gateway = gateway
        self.clock = clock
    }

    /// Check current state, refresh if needed.
    func check() async {
        guard gateway != nil else {
            state = .allowed
            return
        }

        if let activeCheckTask {
            state = .checking
            state = await activeCheckTask.value
            return
        }

        let task = Task<State, Never> { [weak self] in
            guard let self else { return .error("Auth deallocated") }
            return await self.performCheck()
        }

        activeCheckTask = task
        state = .checking
        let next = await task.value
        state = next
        activeCheckTask = nil
    }

    /// Process vox://auth?token=...
    func handleDeepLink(_ url: URL) {
        guard let token = deepLinkToken(from: url) else { return }

        let expiry = jwtExpiry(from: token)

        Task { [weak self] in
            guard let self else { return }
            do {
                try await storage.saveToken(token, expiry: expiry)
                await storage.clearEntitlement()
                Diagnostics.info("Stored auth token from deep link.")
            } catch {
                Diagnostics.error("Failed to save auth token: \(String(describing: error))")
                state = .error("Failed to store auth token")
                return
            }
            await check()
        }
    }

    /// Refresh entitlement state. `force` clears cache first.
    func refresh(force: Bool = false) async {
        guard gateway != nil else {
            state = .allowed
            return
        }
        if force {
            activeCheckTask?.cancel()
            activeCheckTask = nil
            await storage.clearEntitlement()
        }
        await check()
    }

    /// Seed a token (e.g., from env) when none stored yet.
    func seedTokenIfNeeded(_ token: String) async {
        guard gateway != nil else { return }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if await storage.loadToken() != nil { return }

        let expiry = jwtExpiry(from: trimmed)
        do {
            try await storage.saveToken(trimmed, expiry: expiry)
            Diagnostics.info("Seeded auth token.")
        } catch {
            Diagnostics.error("Failed to seed auth token: \(String(describing: error))")
        }
    }

    /// Clear everything.
    func signOut() {
        activeCheckTask?.cancel()
        backgroundRefreshTask?.cancel()
        activeCheckTask = nil
        backgroundRefreshTask = nil

        state = .needsAuth
        Task { [weak self] in
            guard let self else { return }
            await clearAll()
            Diagnostics.info("Signed out.")
        }
    }

    /// Internal token access for deep modules (e.g., VoxGateway).
    func currentToken() async -> String? {
        await storage.loadToken()?.token
    }

    // MARK: - Core Flow

    private func performCheck() async -> State {
        guard let gateway else { return .allowed }

        let now = clock.now

        guard let tokenRecord = await storage.loadToken() else {
            Diagnostics.info("No auth token found.")
            return .needsAuth
        }

        if let expiry = tokenRecord.expiry, now >= expiry {
            Diagnostics.warning("Auth token expired, clearing.")
            await clearAll()
            return .needsAuth
        }

        let token = tokenRecord.token
        let cache = await storage.loadEntitlement()

        if let cache, cache.isValid {
            if cache.isActive {
                if cache.isStale {
                    refreshInBackground(token: token, fallbackCache: cache)
                }
                return .allowed
            }

            if !cache.isStale {
                return .needsSubscription
            }
        }

        return await refreshForeground(token: token, fallbackCache: cache, gateway: gateway)
    }

    private func refreshForeground(
        token: String,
        fallbackCache: EntitlementCache?,
        gateway: VoxAuthGateway
    ) async -> State {
        do {
            let response = try await gateway.getEntitlements(token: token)
            let cache = normalizedCache(from: response)

            do {
                try await storage.saveEntitlement(cache)
            } catch {
                Diagnostics.error("Failed to save entitlement cache: \(String(describing: error))")
            }

            if cache.isActive {
                Diagnostics.info("Entitlement active: \(cache.plan) (\(cache.status))")
                return .allowed
            } else {
                Diagnostics.info("Entitlement inactive: \(cache.plan) (\(cache.status))")
                return .needsSubscription
            }
        } catch let error as GatewayError {
            if isAuthError(error) {
                Diagnostics.warning("Gateway auth failed: \(error.localizedDescription)")
                await clearAll()
                return .needsAuth
            }
            Diagnostics.warning("Gateway error: \(error.localizedDescription)")
            return stateFromNetworkError(error, fallbackCache: fallbackCache)
        } catch {
            Diagnostics.error("Entitlement refresh failed: \(String(describing: error))")
            return stateFromNetworkError(error, fallbackCache: fallbackCache)
        }
    }

    private func refreshInBackground(token: String, fallbackCache: EntitlementCache) {
        guard backgroundRefreshTask == nil, let gateway else { return }

        backgroundRefreshTask = Task { [weak self] in
            guard let self else { return }
            let next = await refreshForeground(token: token, fallbackCache: fallbackCache, gateway: gateway)
            state = next
            backgroundRefreshTask = nil
        }
    }

    private func stateFromNetworkError(_ error: Error, fallbackCache: EntitlementCache?) -> State {
        if let fallbackCache, fallbackCache.isValid, fallbackCache.isActive {
            return .allowed
        }
        return .error(String(describing: error))
    }

    private func clearAll() async {
        await storage.clearToken()
        await storage.clearEntitlement()
    }

    // MARK: - Deep Link + JWT

    private func deepLinkToken(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            Diagnostics.warning("Ignoring auth deep link: invalid URL.")
            return nil
        }
        guard components.scheme == "vox" else { return nil }
        let host = components.host ?? ""
        let path = components.path
        guard host == "auth" || path == "/auth" else { return nil }

        guard let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else {
            Diagnostics.warning("Auth deep link missing token.")
            return nil
        }
        return token
    }

    private func jwtExpiry(from token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        let payloadPart = String(parts[1])
        guard let payloadData = base64URLDecode(payloadPart) else { return nil }

        do {
            let payload = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
            if let exp = payload?["exp"] as? TimeInterval {
                return Date(timeIntervalSince1970: exp)
            }
            if let expInt = payload?["exp"] as? Int {
                return Date(timeIntervalSince1970: TimeInterval(expInt))
            }
        } catch {
            Diagnostics.warning("Failed to parse JWT expiry: \(String(describing: error))")
        }
        return nil
    }

    private func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = (4 - base64.count % 4) % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: padding))
        }

        return Data(base64Encoded: base64)
    }

    // MARK: - Entitlement Mapping

    private func normalizedCache(from response: EntitlementResponse) -> EntitlementCache {
        let status = normalizedStatus(response.status)
        let normalized = EntitlementResponse(
            subject: response.subject,
            plan: response.plan,
            status: status,
            features: response.features,
            currentPeriodEnd: response.currentPeriodEnd
        )
        return EntitlementCache(from: normalized)
    }

    private func normalizedStatus(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == "active" || trimmed == "entitled" {
            return "active"
        }
        return trimmed
    }

    private func isAuthError(_ error: GatewayError) -> Bool {
        switch error {
        case .httpError(let status, _):
            return status == 401 || status == 403
        case .network:
            return false
        }
    }

    // MARK: - Defaults

    nonisolated private static func defaultGateway() -> VoxAuthGateway? {
        guard let baseURL = GatewayURL.api else { return nil }
        return DefaultVoxAuthGateway(baseURL: baseURL)
    }
}

// MARK: - Protocols

protocol VoxAuthClock: Sendable {
    var now: Date { get }
}

struct SystemClock: VoxAuthClock {
    var now: Date { Date() }
}

protocol VoxAuthGateway: Sendable {
    func getEntitlements(token: String) async throws -> EntitlementResponse
}

private struct DefaultVoxAuthGateway: VoxAuthGateway {
    let baseURL: URL

    func getEntitlements(token: String) async throws -> EntitlementResponse {
        let client = GatewayClient(baseURL: baseURL, token: token)
        return try await client.getEntitlements()
    }
}

protocol VoxAuthStorage: Sendable {
    func loadToken() async -> (token: String, expiry: Date?)?
    func saveToken(_ token: String, expiry: Date?) async throws
    func clearToken() async

    func loadEntitlement() async -> EntitlementCache?
    func saveEntitlement(_ cache: EntitlementCache) async throws
    func clearEntitlement() async
}

// MARK: - Keychain Storage

actor KeychainVoxAuthStorage: VoxAuthStorage {
    private enum Account: String {
        case token = "gateway_token"
        case tokenExpiry = "gateway_token_expiry"
        case entitlement = "entitlement_cache"
    }

    private static let service = "io.mistystep.vox.auth"

    func loadToken() async -> (token: String, expiry: Date?)? {
        guard let data = loadData(account: .token),
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }

        let expiry: Date?
        if let expiryData = loadData(account: .tokenExpiry) {
            do {
                expiry = try JSONDecoder().decode(Date.self, from: expiryData)
            } catch {
                Diagnostics.error("Failed to decode token expiry: \(String(describing: error))")
                expiry = nil
            }
        } else {
            expiry = nil
        }

        return (token, expiry)
    }

    func saveToken(_ token: String, expiry: Date?) async throws {
        try saveData(Data(token.utf8), account: .token, name: "auth token")
        if let expiry {
            let data = try JSONEncoder().encode(expiry)
            try saveData(data, account: .tokenExpiry, name: "auth token expiry")
        } else {
            try? deleteData(account: .tokenExpiry, name: "auth token expiry", throwing: false)
        }
    }

    func clearToken() async {
        do {
            try deleteData(account: .token, name: "auth token", throwing: true)
            try? deleteData(account: .tokenExpiry, name: "auth token expiry", throwing: false)
        } catch {
            Diagnostics.error("Failed to clear auth token: \(String(describing: error))")
        }
    }

    func loadEntitlement() async -> EntitlementCache? {
        guard let data = loadData(account: .entitlement) else { return nil }
        do {
            return try JSONDecoder().decode(EntitlementCache.self, from: data)
        } catch {
            Diagnostics.error("Failed to decode entitlement cache: \(String(describing: error))")
            return nil
        }
    }

    func saveEntitlement(_ cache: EntitlementCache) async throws {
        let data = try JSONEncoder().encode(cache)
        try saveData(data, account: .entitlement, name: "entitlement cache")
    }

    func clearEntitlement() async {
        do {
            try deleteData(account: .entitlement, name: "entitlement cache", throwing: false)
        } catch {
            Diagnostics.error("Failed to clear entitlement cache: \(String(describing: error))")
        }
    }

    // MARK: - Keychain Helpers

    private func query(for account: Account) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account.rawValue
        ]
    }

    private func saveData(_ data: Data, account: Account, name: String) throws {
        let query = query(for: account)
        var attributes = query
        attributes[kSecValueData as String] = data

        let status = SecItemAdd(attributes as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            Diagnostics.info("Saved \(name) to keychain.")
        case errSecDuplicateItem:
            let updateStatus = SecItemUpdate(
                query as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            if updateStatus == errSecSuccess {
                Diagnostics.info("Updated \(name) in keychain.")
            } else {
                throw keychainError("Failed to update \(name)", status: updateStatus)
            }
        default:
            throw keychainError("Failed to save \(name)", status: status)
        }
    }

    private func loadData(account: Account) -> Data? {
        var query = query(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                Diagnostics.error("Failed to load keychain data.")
                return nil
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            Diagnostics.error(errorMessage("Failed to load keychain data", status: status))
            return nil
        }
    }

    private func deleteData(account: Account, name: String, throwing: Bool) throws {
        let status = SecItemDelete(query(for: account) as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            Diagnostics.info("Cleared \(name) from keychain.")
        default:
            let error = keychainError("Failed to delete \(name)", status: status)
            if throwing {
                throw error
            } else {
                Diagnostics.error(error.localizedDescription)
            }
        }
    }

    private func keychainError(_ prefix: String, status: OSStatus) -> VoxError {
        let message = errorMessage(prefix, status: status)
        Diagnostics.error(message)
        return VoxError.internalError(message)
    }

    private func errorMessage(_ prefix: String, status: OSStatus) -> String {
        let description = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        return "\(prefix): \(description)"
    }
}
