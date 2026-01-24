import Foundation

/// Cached entitlement stored in Keychain
/// Enables optimistic access while background refresh happens
struct EntitlementCache: Codable, Equatable, Sendable {
    let plan: String
    let status: String
    let features: [String]
    let currentPeriodEnd: Date?
    let lastVerified: Date

    /// Soft TTL: trigger background refresh after 4 hours
    var isStale: Bool {
        Date().timeIntervalSince(lastVerified) > 4 * 3600
    }

    /// Hard TTL: block user after 24 hours without verification
    var isValid: Bool {
        Date().timeIntervalSince(lastVerified) < 24 * 3600
    }

    /// Whether the subscription itself is active
    var isActive: Bool {
        status == "active"
    }

    /// Create from gateway response
    init(from response: EntitlementResponse) {
        self.plan = response.plan
        self.status = response.status
        self.features = response.features
        self.currentPeriodEnd = response.currentPeriodEnd.map {
            Date(timeIntervalSince1970: TimeInterval($0))
        }
        self.lastVerified = Date()
    }

    /// For testing
    init(
        plan: String,
        status: String,
        features: [String],
        currentPeriodEnd: Date?,
        lastVerified: Date
    ) {
        self.plan = plan
        self.status = status
        self.features = features
        self.currentPeriodEnd = currentPeriodEnd
        self.lastVerified = lastVerified
    }
}
