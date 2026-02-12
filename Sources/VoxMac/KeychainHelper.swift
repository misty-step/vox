import Foundation
import Security

public enum KeychainHelper {
    private static let serviceIdentifier = Bundle.main.bundleIdentifier ?? "com.misty-step.Vox"

    public enum Key: String {
        case elevenLabsAPIKey = "com.vox.elevenlabs.apikey"
        case openRouterAPIKey = "com.vox.openrouter.apikey"
        case deepgramAPIKey = "com.vox.deepgram.apikey"
        case openAIAPIKey = "com.vox.openai.apikey"
        case geminiAPIKey = "com.vox.gemini.apikey"
    }

    @discardableResult
    public static func save(_ value: String, for key: Key) -> Bool {
        delete(key)
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecValueData as String: data
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    public static func load(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: serviceIdentifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    @discardableResult
    public static func delete(_ key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: serviceIdentifier
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
