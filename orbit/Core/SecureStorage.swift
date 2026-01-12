//
//  SecureStorage.swift
//  orbit
//
//  Secure storage utility for sensitive data using Keychain
//

import Foundation
import Security

/// Secure storage manager for API keys, OAuth tokens, and other sensitive data
class SecureStorage {
    // MARK: - Storage Keys

    /// API Key storage keys
    static let openAIKey = "com.orbit.openai.apikey"
    static let geminiKey = "com.orbit.gemini.apikey"
    static let claudeKey = "com.orbit.claude.apikey"
    static let openRouterKey = "com.orbit.openrouter.apikey"
    static let localLlamaURL = "com.orbit.localllama.url"

    /// OAuth token storage key generator
    /// Format: "com.orbit.google.token.{googleUserID}"
    static func googleAccessTokenKey(for userID: String) -> String {
        return "com.orbit.google.token.\(userID)"
    }

    /// OAuth refresh token storage key generator
    /// Format: "com.orbit.google.refresh.{googleUserID}"
    static func googleRefreshTokenKey(for userID: String) -> String {
        return "com.orbit.google.refresh.\(userID)"
    }

    // MARK: - Errors

    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case invalidData
        case unexpectedError(OSStatus)

        var localizedDescription: String {
            switch self {
            case .itemNotFound:
                return "Item not found in keychain"
            case .duplicateItem:
                return "Item already exists in keychain"
            case .invalidData:
                return "Invalid data format"
            case .unexpectedError(let status):
                return "Keychain error: \(status)"
            }
        }
    }

    // MARK: - Public Methods

    /// Save a string value to the keychain
    /// - Parameters:
    ///   - key: Unique identifier for the value
    ///   - value: String value to store
    /// - Returns: Result with success or error
    func save(key: String, value: String) -> Result<Void, KeychainError> {
        guard let data = value.data(using: .utf8) else {
            return .failure(.invalidData)
        }

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                return .failure(.duplicateItem)
            }
            return .failure(.unexpectedError(status))
        }

        return .success(())
    }

    /// Retrieve a string value from the keychain
    /// - Parameter key: Unique identifier for the value
    /// - Returns: Result with the string value or error
    func retrieve(key: String) -> Result<String, KeychainError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return .failure(.itemNotFound)
            }
            return .failure(.unexpectedError(status))
        }

        guard let data = dataTypeRef as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return .failure(.invalidData)
        }

        return .success(string)
    }

    /// Delete a value from the keychain
    /// - Parameter key: Unique identifier for the value
    /// - Returns: Result with success or error
    func delete(key: String) -> Result<Void, KeychainError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            return .failure(.unexpectedError(status))
        }

        return .success(())
    }

    /// Check if a key exists in the keychain
    /// - Parameter key: Unique identifier to check
    /// - Returns: True if key exists, false otherwise
    func exists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Delete all items stored by this app (use with caution)
    /// - Returns: Result with success or error
    func deleteAll() -> Result<Void, KeychainError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            return .failure(.unexpectedError(status))
        }

        return .success(())
    }
}
