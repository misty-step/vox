import Foundation

/// Production entitlement checker backed by the gateway.
final class GatewayEntitlementChecker: EntitlementChecker, @unchecked Sendable {
    private let client: GatewayClient

    init(client: GatewayClient) {
        self.client = client
    }

    func check(token _: String) async throws -> AccessEntitlementStatus {
        let response = try await client.getEntitlements()
        return map(response)
    }

    private func map(_ response: EntitlementResponse) -> AccessEntitlementStatus {
        let status = response.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard status == "active" || status == "entitled" else {
            return .expired
        }

        if response.plan == "trial", let end = response.currentPeriodEnd {
            let until = Date(timeIntervalSince1970: TimeInterval(end))
            return .gracePeriod(until: until)
        }

        return .entitled
    }
}

