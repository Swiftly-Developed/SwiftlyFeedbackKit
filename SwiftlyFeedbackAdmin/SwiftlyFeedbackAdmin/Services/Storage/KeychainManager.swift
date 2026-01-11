import Foundation
import Security

/// Low-level Keychain operations with environment-aware key namespacing.
///
/// Marked as `nonisolated` to opt out of MainActor isolation since
/// Security framework functions are thread-safe.
nonisolated
enum KeychainManager {
    private static let service = "com.swiftly-developed.SwiftlyFeedbackAdmin"

    // MARK: - Public API

    /// Saves data to the Keychain with the given scoped key.
    /// - Parameters:
    ///   - data: The data to store
    ///   - scopedKey: The full key including scope prefix (e.g., "production.authToken")
    /// - Throws: `KeychainManagerError.unableToSave` if the operation fails
    static func save(_ data: Data, forKey scopedKey: String) throws {
        // Delete existing item first
        delete(forKey: scopedKey)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: scopedKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainManagerError.unableToSave(status: status)
        }
    }

    /// Retrieves data from the Keychain for the given scoped key.
    /// - Parameter scopedKey: The full key including scope prefix
    /// - Returns: The stored data, or nil if not found
    static func get(forKey scopedKey: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: scopedKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return data
    }

    /// Deletes an item from the Keychain.
    /// - Parameter scopedKey: The full key including scope prefix
    @discardableResult
    static func delete(forKey scopedKey: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: scopedKey
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Deletes all items matching a scope prefix.
    /// - Parameter scopePrefix: The scope prefix (e.g., "production", "debug")
    static func deleteAll(withScopePrefix scopePrefix: String) {
        // Query all items for our service
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return
        }

        // Delete items matching the prefix
        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  account.hasPrefix("\(scopePrefix).") else {
                continue
            }
            delete(forKey: account)
        }
    }

    /// Deletes ALL items stored by this app in the Keychain.
    static func deleteAllItems() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Lists all keys currently stored in the Keychain (for debugging).
    static func listAllKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
}

// MARK: - Errors

enum KeychainManagerError: Error, LocalizedError {
    case unableToSave(status: OSStatus)
    case unableToRead(status: OSStatus)
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .unableToSave(let status):
            return "Unable to save to keychain (status: \(status))"
        case .unableToRead(let status):
            return "Unable to read from keychain (status: \(status))"
        case .encodingFailed:
            return "Failed to encode value for keychain storage"
        case .decodingFailed:
            return "Failed to decode value from keychain storage"
        }
    }
}
