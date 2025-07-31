// Satsat_Encryption_Implementation.swift
// Two-tier encryption system for group Bitcoin savings app

import Foundation
import CryptoKit
import CoreData

// MARK: - Encryption Manager
class SatsatEncryptionManager: ObservableObject {
    static let shared = SatsatEncryptionManager()
    
    private let keychain = KeychainManager.shared
    
    // Encryption constants (matching Seed-E approach)
    private let pbkdf2Iterations: Int = 100_000
    private let keySize: Int = 32 // 256 bits
    private let saltSize: Int = 32
    
    // Context strings for different data types
    public enum ContextType: String {
        case userPrivateData = "user_private"
        case groupSharedData = "group_shared"
        case userMessages = "user_messages"
        case groupXpub = "group_xpub"
        case groupBalances = "group_balances"
        case groupGoals = "group_goals"
    }
    
    // MARK: - Master Key Management
    
    /// Get or create user's personal master key (for private data)
    func getUserMasterKey() throws -> SymmetricKey {
        do {
            let keyData = try keychain.retrieve(for: "master_encryption_key", prompt: "Authenticate to access encryption key")
            return SymmetricKey(data: keyData)
        } catch {
            // Generate new master key
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            try keychain.store(data: keyData, for: "master_encryption_key", requiresBiometrics: true)
            return newKey
        }
    }
    
    /// Get or create group shared key (derived from group seed)
    func getGroupMasterKey(for groupId: String) throws -> SymmetricKey {
        _ = "group_master_\(groupId)"
        
        do {
            let keyData = try keychain.retrieve(for: "group_secrets_\(groupId)", prompt: "Authenticate to access group data")
            return SymmetricKey(data: keyData)
        } catch {
            // This should be derived from group creation or received during invite
            throw EncryptionError.groupKeyNotFound
        }
    }
    
    /// Store group master key (when creating or joining group)
    func storeGroupMasterKey(_ key: SymmetricKey, for groupId: String) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        try keychain.store(data: keyData, for: "group_secrets_\(groupId)", requiresBiometrics: false)
    }
    
    // MARK: - Context-Specific Key Derivation (Seed-E approach)
    
    /// Derive context-specific key from master key + context string
    private func deriveContextKey(masterKey: SymmetricKey, context: ContextType, identifier: String = "") throws -> SymmetricKey {
        let contextString = identifier.isEmpty ? context.rawValue : "\(context.rawValue):\(identifier)"
        let contextData = Data(contextString.utf8)
        
        // Use HKDF to derive context-specific key (more secure than simple concatenation)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            info: contextData,
            outputByteCount: keySize
        )
        
        return derivedKey
    }
    
    // MARK: - User Private Data Encryption
    
    /// Encrypt user's private data (messages, private keys, personal notes)
    func encryptUserPrivateData<T: Codable>(_ data: T, context: ContextType, identifier: String = "") throws -> EncryptedData {
        let masterKey = try getUserMasterKey()
        let contextKey = try deriveContextKey(masterKey: masterKey, context: context, identifier: identifier)
        
        let jsonData = try JSONEncoder().encode(data)
        return try encrypt(data: jsonData, with: contextKey)
    }
    
    /// Decrypt user's private data
    func decryptUserPrivateData<T: Codable>(_ encryptedData: EncryptedData, type: T.Type, context: ContextType, identifier: String = "") throws -> T {
        let masterKey = try getUserMasterKey()
        let contextKey = try deriveContextKey(masterKey: masterKey, context: context, identifier: identifier)
        
        let jsonData = try decrypt(encryptedData: encryptedData, with: contextKey)
        return try JSONDecoder().decode(type, from: jsonData)
    }
    
    // MARK: - Group Shared Data Encryption
    
    /// Encrypt group shared data (xpubs, balances, goals) - all group members can decrypt
    func encryptGroupSharedData<T: Codable>(_ data: T, groupId: String, context: ContextType, identifier: String = "") throws -> EncryptedData {
        let groupMasterKey = try getGroupMasterKey(for: groupId)
        let contextKey = try deriveContextKey(masterKey: groupMasterKey, context: context, identifier: identifier)
        
        let jsonData = try JSONEncoder().encode(data)
        return try encrypt(data: jsonData, with: contextKey)
    }
    
    /// Decrypt group shared data
    func decryptGroupSharedData<T: Codable>(_ encryptedData: EncryptedData, type: T.Type, groupId: String, context: ContextType, identifier: String = "") throws -> T {
        let groupMasterKey = try getGroupMasterKey(for: groupId)
        let contextKey = try deriveContextKey(masterKey: groupMasterKey, context: context, identifier: identifier)
        
        let jsonData = try decrypt(encryptedData: encryptedData, with: contextKey)
        return try JSONDecoder().decode(type, from: jsonData)
    }
    
    // MARK: - Core Encryption/Decryption (AES-256-GCM)
    
    private func encrypt(data: Data, with key: SymmetricKey) throws -> EncryptedData {
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        return EncryptedData(
            ciphertext: sealedBox.ciphertext,
            nonce: sealedBox.nonce,
            tag: sealedBox.tag
        )
    }
    
    private func decrypt(encryptedData: EncryptedData, with key: SymmetricKey) throws -> Data {
        guard let nonce = encryptedData.nonceObject else {
            throw EncryptionError.decryptionFailed
        }
        
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: encryptedData.ciphertext,
            tag: encryptedData.tag
        )
        
        return try AES.GCM.open(sealedBox, using: key)
    }
}

// MARK: - Data Models

/// Encrypted data container (same structure as Seed-E)
struct EncryptedData: Codable {
    let ciphertext: Data
    let nonce: Data // Store as Data instead of AES.GCM.Nonce for Codable support
    let tag: Data
    
    init(ciphertext: Data, nonce: AES.GCM.Nonce, tag: Data) {
        self.ciphertext = ciphertext
        self.nonce = Data(nonce)
        self.tag = tag
    }
    
    var nonceObject: AES.GCM.Nonce? {
        try? AES.GCM.Nonce(data: nonce)
    }
}

/// Group member's extended public key data
struct MemberXpubData: Codable {
    let memberId: String
    let memberName: String
    let xpub: String
    let derivationPath: String
    let joinedAt: Date
}

/// Group balance and contribution data
struct GroupBalanceData: Codable {
    let totalBalance: UInt64
    let goalAmount: UInt64
    let contributions: [String: UInt64] // memberId -> contribution amount
    let lastUpdated: Date
}

/// User message data
struct UserMessageData: Codable {
    let messageId: String
    let content: String
    let sender: String
    let timestamp: Date
    let groupId: String
}

// MARK: - Error Types

enum EncryptionError: Error, LocalizedError {
    case keyGenerationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case groupKeyNotFound
    case dataNotFound
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed: return "Failed to generate encryption key"
        case .encryptionFailed: return "Failed to encrypt data"
        case .decryptionFailed: return "Failed to decrypt data"
        case .invalidData: return "Invalid data format"
        case .groupKeyNotFound: return "Group encryption key not found"
        case .dataNotFound: return "Encrypted data not found"
        }
    }
}

// MARK: - Extensions

extension Data {
    init?(hex: String) {
        let len = hex.count / 2
        var data = Data(capacity: len)
        var i = hex.startIndex
        for _ in 0..<len {
            let j = hex.index(i, offsetBy: 2)
            let bytes = hex[i..<j]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
            i = j
        }
        self = data
    }
    
    var hexEncodedString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}