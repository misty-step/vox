import Foundation
import Security
import VoxCore

enum KeychainHelper {
    private static let service = "com.vox.auth"
    private static let account = "gateway_token"

    static func save(token: String) throws {
        let data = Data(token.utf8)
        let query = baseQuery()
        var attributes = query
        attributes[kSecValueData as String] = data

        let status = SecItemAdd(attributes as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            Diagnostics.info("Saved auth token to keychain.")
        case errSecDuplicateItem:
            let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if updateStatus == errSecSuccess {
                Diagnostics.info("Updated auth token in keychain.")
            } else {
                let message = errorMessage("Failed to update auth token", status: updateStatus)
                Diagnostics.error(message)
                throw VoxError.internalError(message)
            }
        default:
            let message = errorMessage("Failed to save auth token", status: status)
            Diagnostics.error(message)
            throw VoxError.internalError(message)
        }
    }

    static func load() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let token = String(data: data, encoding: .utf8),
                  !token.isEmpty else {
                Diagnostics.error("Failed to decode auth token from keychain.")
                return nil
            }
            return token
        case errSecItemNotFound:
            return nil
        default:
            let message = errorMessage("Failed to load auth token", status: status)
            Diagnostics.error(message)
            return nil
        }
    }

    static func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            Diagnostics.info("Cleared auth token from keychain.")
        default:
            let message = errorMessage("Failed to delete auth token", status: status)
            Diagnostics.error(message)
            throw VoxError.internalError(message)
        }
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func errorMessage(_ prefix: String, status: OSStatus) -> String {
        let description = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        return "\(prefix): \(description)"
    }
}
