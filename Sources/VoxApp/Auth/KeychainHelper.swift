import Foundation
import Security
import VoxCore

enum KeychainHelper {
    private static let service = "com.vox.auth"

    private enum Account: String {
        case token = "gateway_token"
        case tokenExpiry = "gateway_token_expiry"
        case entitlement = "entitlement_cache"
    }

    // MARK: - Auth Token

    static func save(token: String) throws {
        try saveData(Data(token.utf8), account: .token, name: "auth token")
    }

    static func load() -> String? {
        sessionToken
    }

    static func delete() throws {
        try deleteData(account: .token, name: "auth token", throwing: true)
        // Best-effort cleanup of related expiry metadata
        try? deleteData(account: .tokenExpiry, name: "auth token expiry", throwing: false)
    }

    // MARK: - Session Token (non-throwing)

    static func saveSessionToken(_ token: String) {
        do {
            try save(token: token)
        } catch {
            Diagnostics.error("Failed to save session token: \(error.localizedDescription)")
        }
    }

    static var sessionToken: String? {
        guard let data = loadData(account: .token, name: "auth token"),
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    static func clearSessionToken() {
        do {
            try delete()
        } catch {
            Diagnostics.error("Failed to clear session token: \(error.localizedDescription)")
        }
    }

    // MARK: - Token Expiry

    static func saveTokenExpiry(_ date: Date) {
        do {
            let data = try JSONEncoder().encode(date)
            try saveData(data, account: .tokenExpiry, name: "auth token expiry")
        } catch {
            Diagnostics.error("Failed to save auth token expiry: \(error.localizedDescription)")
        }
    }

    static var tokenExpiry: Date? {
        guard let data = loadData(account: .tokenExpiry, name: "auth token expiry") else {
            return nil
        }
        do {
            return try JSONDecoder().decode(Date.self, from: data)
        } catch {
            Diagnostics.error("Failed to decode auth token expiry: \(error.localizedDescription)")
            return nil
        }
    }

    static func clearTokenExpiry() {
        try? deleteData(account: .tokenExpiry, name: "auth token expiry", throwing: false)
    }

    // MARK: - Entitlement Cache

    static func saveEntitlement(_ cache: EntitlementCache) throws {
        let data = try JSONEncoder().encode(cache)
        try saveData(data, account: .entitlement, name: "entitlement cache")
    }

    static func loadEntitlement() -> EntitlementCache? {
        guard let data = loadData(account: .entitlement, name: "entitlement cache") else {
            return nil
        }
        do {
            return try JSONDecoder().decode(EntitlementCache.self, from: data)
        } catch {
            Diagnostics.error("Failed to decode entitlement cache: \(error.localizedDescription)")
            return nil
        }
    }

    static func deleteEntitlement() {
        try? deleteData(account: .entitlement, name: "entitlement cache", throwing: false)
    }

    // MARK: - Private Helpers

    private static func query(for account: Account) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue
        ]
    }

    private static func saveData(_ data: Data, account: Account, name: String) throws {
        let query = query(for: account)
        var attributes = query
        attributes[kSecValueData as String] = data

        let status = SecItemAdd(attributes as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            Diagnostics.info("Saved \(name) to keychain.")
        case errSecDuplicateItem:
            let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if updateStatus == errSecSuccess {
                Diagnostics.info("Updated \(name) in keychain.")
            } else {
                throw keychainError("Failed to update \(name)", status: updateStatus)
            }
        default:
            throw keychainError("Failed to save \(name)", status: status)
        }
    }

    private static func loadData(account: Account, name: String) -> Data? {
        var query = query(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                Diagnostics.error("Failed to decode \(name) from keychain.")
                return nil
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            Diagnostics.error(errorMessage("Failed to load \(name)", status: status))
            return nil
        }
    }

    private static func deleteData(account: Account, name: String, throwing: Bool) throws {
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

    private static func keychainError(_ prefix: String, status: OSStatus) -> VoxError {
        let message = errorMessage(prefix, status: status)
        Diagnostics.error(message)
        return VoxError.internalError(message)
    }

    private static func errorMessage(_ prefix: String, status: OSStatus) -> String {
        let description = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        return "\(prefix): \(description)"
    }
}
