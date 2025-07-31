// KeychainManager.swift
// Secure keychain storage with OPTIONAL biometric authentication
// Biometrics are only used if user has Face ID/Touch ID enabled AND chooses to use them
// Always falls back to device passcode - NO MANDATORY BIOMETRICS

import Foundation
import Security
import LocalAuthentication
import CryptoKit

// MARK: - Keychain Manager

/// Secure keychain manager for storing sensitive data with biometric protection
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    // MARK: - Keychain Operations
    
    /// Stores data in the keychain with optional biometric protection
    /// Falls back to device passcode if biometrics unavailable/disabled
    func store(data: Data, for key: String, requiresBiometrics: Bool = false) throws {
        // Use simpler keychain storage for iOS Simulator compatibility
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Only add access control on physical devices to avoid simulator issues
        #if !targetEnvironment(simulator)
        if let accessControl = createAccessControl(requiresBiometrics: requiresBiometrics) {
            query[kSecAttrAccessControl as String] = accessControl
        }
        #endif
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storageFailure(status)
        }
    }
    
    /// Retrieves data from the keychain with biometric authentication
    func retrieve(for key: String, prompt: String = "Authenticate to access secure data") throws -> Data {
        // Simple query for simulator compatibility
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // Only use authentication context on physical devices
        #if !targetEnvironment(simulator)
        let context = LAContext()
        context.localizedReason = prompt
        query[kSecUseAuthenticationContext as String] = context
        #endif
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecUserCanceled else {
            throw KeychainError.userCancelled
        }
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            } else {
                throw KeychainError.retrievalFailure(status)
            }
        }
        
        guard let data = item as? Data else {
            throw KeychainError.invalidData
        }
        
        return data
    }
    
    /// Deletes an item from the keychain
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deletionFailure(status)
        }
    }
    
    /// Checks if an item exists in the keychain
    func exists(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanFalse!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Convenience Methods for Satsat
    
    /// Stores a Nostr private key securely (biometrics 100% OPTIONAL)
    /// - Parameter useBiometrics: nil = auto-detect if user has biometrics enabled, 
    ///                            true = force biometrics (still falls back to passcode),
    ///                            false = only use device passcode
    func storeNostrPrivateKey(_ privateKeyHex: String, for userId: String, useBiometrics: Bool? = nil) throws {
        let data = privateKeyHex.data(using: .utf8)!
        let shouldUseBiometrics = useBiometrics ?? BiometricAuthManager.shared.isAvailable
        try store(data: data, for: "nostr_private_\(userId)", requiresBiometrics: shouldUseBiometrics)
    }
    
    /// Retrieves a Nostr private key securely
    func retrieveNostrPrivateKey(for userId: String) throws -> String {
        let data = try retrieve(for: "nostr_private_\(userId)", prompt: "Authenticate to access your Nostr key")
        guard let privateKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return privateKey
    }
    
    /// Stores the user's master encryption key (biometrics optional)
    func storeMasterKey(_ key: SymmetricKey, for context: String, useBiometrics: Bool? = nil) throws {
        let shouldUseBiometrics = useBiometrics ?? BiometricAuthManager.shared.isAvailable
        try store(data: key.withUnsafeBytes { Data($0) }, for: "master_key_\(context)", requiresBiometrics: shouldUseBiometrics)
    }
    
    /// Retrieves the user's master encryption key
    func retrieveMasterKey(for context: String) throws -> SymmetricKey {
        let data = try retrieve(for: "master_key_\(context)", prompt: "Authenticate to access encryption key")
        return SymmetricKey(data: data)
    }
    
    /// Stores a group's shared encryption key
    func storeGroupKey(_ key: SymmetricKey, for groupId: String) throws {
        try store(data: key.withUnsafeBytes { Data($0) }, for: "group_key_\(groupId)", requiresBiometrics: false)
    }
    
    /// Retrieves a group's shared encryption key
    func retrieveGroupKey(for groupId: String) throws -> SymmetricKey {
        let data = try retrieve(for: "group_key_\(groupId)", prompt: "Authenticate to access group data")
        return SymmetricKey(data: data)
    }
    
    // MARK: - Access Control
    
    private func createAccessControl(requiresBiometrics: Bool) -> SecAccessControl? {
        // Always include device passcode as fallback
        var flags: SecAccessControlCreateFlags = [.devicePasscode]
        
        // Only add biometrics if requested AND available
        if requiresBiometrics && BiometricAuthManager.shared.isAvailable {
            flags.insert(.biometryAny)
        }
        
        var error: Unmanaged<CFError>?
        let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags,
            &error
        )
        
        if let error = error {
            print("⚠️ Failed to create access control: \(error)")
            return nil
        }
        
        return accessControl
    }
}

// MARK: - Biometric Authentication Manager

class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    
    @Published var biometricType: LABiometryType = .none
    @Published var isAvailable: Bool = false
    @Published var errorMessage: String?
    
    private let context = LAContext()
    
    private init() {
        checkBiometricAvailability()
    }
    
    func checkBiometricAvailability() {
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isAvailable = true
            biometricType = context.biometryType
        } else {
            isAvailable = false
            biometricType = .none
            errorMessage = error?.localizedDescription
        }
    }
    
    func authenticateUser(reason: String) async throws -> Bool {
        let context = LAContext()
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return result
        } catch {
            throw BiometricError.authenticationFailed(error.localizedDescription)
        }
    }
    
    func authenticateWithPasscode(reason: String) async throws -> Bool {
        let context = LAContext()
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return result
        } catch {
            throw BiometricError.authenticationFailed(error.localizedDescription)
        }
    }
    
    var biometricTypeString: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "None"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Error Types

enum KeychainError: Error, LocalizedError {
    case storageFailure(OSStatus)
    case retrievalFailure(OSStatus)
    case deletionFailure(OSStatus)
    case itemNotFound
    case userCancelled
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .storageFailure(let status):
            return "Failed to store item in keychain: \(status)"
        case .retrievalFailure(let status):
            return "Failed to retrieve item from keychain: \(status)"
        case .deletionFailure(let status):
            return "Failed to delete item from keychain: \(status)"
        case .itemNotFound:
            return "Item not found in keychain"
        case .userCancelled:
            return "User cancelled authentication"
        case .invalidData:
            return "Invalid data format"
        }
    }
}

enum BiometricError: Error, LocalizedError {
    case authenticationFailed(String)
    case notAvailable
    case notEnrolled
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let reason):
            return "Biometric authentication failed: \(reason)"
        case .notAvailable:
            return "Biometric authentication is not available"
        case .notEnrolled:
            return "No biometric data enrolled on this device"
        }
    }
}

// MARK: - Keychain Access Policy

struct KeychainAccessPolicy {
    static let userPrivateData = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    static let groupSharedData = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    static let appSettings = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
}

// MARK: - Security Constants

struct SecurityConstants {
    static let keychainService = "com.satsthestandard.satsat"
    static let userMasterKeyTag = "user_master_key"
    static let nostrPrivateKeyTag = "nostr_private_key"
    static let groupKeyPrefix = "group_key_"
    
    // Authentication prompts (biometrics optional - falls back to device passcode)
    static let masterKeyPrompt = "Authenticate to access your secure Bitcoin savings data"
    static let nostrKeyPrompt = "Authenticate to access your Nostr identity"
    static let groupDataPrompt = "Authenticate to access group financial data"
    static let signingPrompt = "Authenticate to sign the Bitcoin transaction"
}