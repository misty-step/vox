import Foundation

/// Why access was blocked.
enum BlockReason: Sendable, Equatable {
    case notAuthenticated
    case notEntitled
    case permissionDenied
    case networkError(String)
}

/// Result of access check.
enum AccessDecision: Sendable, Equatable {
    case allowed
    case blocked(BlockReason)
}

/// Minimal entitlement status for access decisions.
enum AccessEntitlementStatus: Sendable, Equatable {
    case entitled
    case gracePeriod(until: Date)
    case expired
}

/// Protocol for checking entitlements (allows testing).
protocol EntitlementChecker: Sendable {
    func check(token: String) async throws -> AccessEntitlementStatus
}

/// Protocol for caching entitlements (allows testing).
protocol EntitlementCacheStore: Sendable {
    func get() async -> (status: AccessEntitlementStatus, expiresAt: Date)?
    func save(_ status: AccessEntitlementStatus, ttl: TimeInterval) async
    func clear() async
}

/// Unified access control — hides auth + entitlement complexity.
protocol AccessGate: Sendable {
    func preflight() async -> AccessDecision
}

/// Concrete implementation.
actor AccessGateImpl: AccessGate {
    private let tokenService: TokenService
    private let entitlementChecker: EntitlementChecker
    private let cache: EntitlementCacheStore?

    // Cache TTLs.
    private let softTTL: TimeInterval
    private let hardTTL: TimeInterval

    init(
        tokenService: TokenService,
        entitlementChecker: EntitlementChecker,
        cache: EntitlementCacheStore? = nil,
        softTTL: TimeInterval = 4 * 3600,
        hardTTL: TimeInterval = 24 * 3600
    ) {
        self.tokenService = tokenService
        self.entitlementChecker = entitlementChecker
        self.cache = cache
        self.softTTL = softTTL
        self.hardTTL = hardTTL
    }

    func preflight() async -> AccessDecision {
        let token: String
        do {
            token = try await tokenService.validToken()
        } catch {
            return .blocked(.notAuthenticated)
        }

        return await checkEntitlement(token: token)
    }

    private func checkEntitlement(token: String) async -> AccessDecision {
        if let cached = await cache?.get() {
            let now = Date()
            let hardExpiry = cached.expiresAt.addingTimeInterval(hardTTL - softTTL)

            if cached.expiresAt >= now {
                return decision(for: cached.status, now: now)
            }

            if hardExpiry >= now, isAllowed(cached.status, now: now) {
                Task { await backgroundRefresh(token: token) }
                return .allowed
            }
        }

        do {
            let status = try await entitlementChecker.check(token: token)
            await cache?.save(status, ttl: softTTL)
            return decision(for: status, now: Date())
        } catch let error as GatewayError {
            if isAuthError(error) {
                await tokenService.clearToken()
                return .blocked(.notAuthenticated)
            }
            return await handleNetworkError(error)
        } catch {
            return await handleNetworkError(error)
        }
    }

    private func backgroundRefresh(token: String) async {
        do {
            let status = try await entitlementChecker.check(token: token)
            await cache?.save(status, ttl: softTTL)
        } catch {
            Diagnostics.warning("AccessGate background refresh failed: \(String(describing: error))")
        }
    }

    private func handleNetworkError(_ error: Error) async -> AccessDecision {
        if let cached = await cache?.get() {
            let now = Date()
            let hardExpiry = cached.expiresAt.addingTimeInterval(hardTTL - softTTL)
            if hardExpiry >= now, isAllowed(cached.status, now: now) {
                return .allowed
            }
        }
        return .blocked(.networkError(String(describing: error)))
    }

    private func decision(for status: AccessEntitlementStatus, now: Date) -> AccessDecision {
        if isAllowed(status, now: now) { return .allowed }
        return .blocked(.notEntitled)
    }

    private func isAllowed(_ status: AccessEntitlementStatus, now: Date) -> Bool {
        switch status {
        case .entitled:
            return true
        case .gracePeriod(let until):
            return until > now
        case .expired:
            return false
        }
    }

    private func isAuthError(_ error: GatewayError) -> Bool {
        switch error {
        case .httpError(let status, _):
            return status == 401 || status == 403
        case .network:
            return false
        }
    }
}
