// NIP44Encryption.swift
// NIP-44 encryption implementation for secure Nostr messaging

import Foundation
import CryptoKit
import CommonCrypto

// MARK: - NIP-44 Encryption Implementation

/// Implementation of NIP-44 encryption for secure Nostr messaging
/// This provides end-to-end encryption for direct messages and group coordination
class NIP44Encryption {
    static let shared = NIP44Encryption()
    
    private init() {}
    
    // MARK: - Public Encryption Methods
    
    /// Encrypt a message using NIP-44 encryption
    /// - Parameters:
    ///   - message: The plaintext message to encrypt
    ///   - senderPrivateKey: Sender's private key (hex string)
    ///   - recipientPublicKey: Recipient's public key (hex string)
    /// - Returns: Base64 encoded encrypted message
    func encrypt(message: String, senderPrivateKey: String, recipientPublicKey: String) throws -> String {
        // Convert message to data
        guard let messageData = message.data(using: .utf8) else {
            throw NIP44Error.invalidMessageFormat
        }
        
        // Derive shared secret
        let sharedSecret = try deriveSharedSecret(
            privateKey: senderPrivateKey,
            publicKey: recipientPublicKey
        )
        
        // Generate random nonce (24 bytes for ChaCha20)
        let nonce = generateNonce()
        
        // Encrypt using ChaCha20-Poly1305
        let encryptedData = try encryptChaCha20Poly1305(
            data: messageData,
            key: sharedSecret,
            nonce: nonce
        )
        
        // Create NIP-44 payload structure
        let payload = NIP44Payload(
            version: 2,
            nonce: nonce,
            ciphertext: encryptedData.ciphertext,
            authTag: encryptedData.authTag
        )
        
        // Encode as base64
        return try payload.toBase64()
    }
    
    /// Decrypt a NIP-44 encrypted message
    /// - Parameters:
    ///   - encryptedMessage: Base64 encoded encrypted message
    ///   - recipientPrivateKey: Recipient's private key (hex string)
    ///   - senderPublicKey: Sender's public key (hex string)
    /// - Returns: Decrypted plaintext message
    func decrypt(encryptedMessage: String, recipientPrivateKey: String, senderPublicKey: String) throws -> String {
        // Parse NIP-44 payload
        let payload = try NIP44Payload.fromBase64(encryptedMessage)
        
        // Verify version
        guard payload.version == 2 else {
            throw NIP44Error.unsupportedVersion
        }
        
        // Derive shared secret
        let sharedSecret = try deriveSharedSecret(
            privateKey: recipientPrivateKey,
            publicKey: senderPublicKey
        )
        
        // Decrypt using ChaCha20-Poly1305
        let decryptedData = try decryptChaCha20Poly1305(
            ciphertext: payload.ciphertext,
            authTag: payload.authTag,
            key: sharedSecret,
            nonce: payload.nonce
        )
        
        // Convert back to string
        guard let decryptedMessage = String(data: decryptedData, encoding: .utf8) else {
            throw NIP44Error.invalidMessageFormat
        }
        
        return decryptedMessage
    }
    
    // MARK: - Group Encryption (Shared Secret)
    
    /// Encrypt a message for a group using a shared group key
    /// - Parameters:
    ///   - message: The plaintext message to encrypt
    ///   - groupSharedKey: Shared key for the group (hex string)
    /// - Returns: Base64 encoded encrypted message
    func encryptForGroup(message: String, groupSharedKey: String) throws -> String {
        guard let messageData = message.data(using: .utf8) else {
            throw NIP44Error.invalidMessageFormat
        }
        
        // Convert hex string to data
        guard let keyData = Data(hexString: groupSharedKey), keyData.count == 32 else {
            throw NIP44Error.invalidKeyFormat
        }
        
        let nonce = generateNonce()
        
        let encryptedData = try encryptChaCha20Poly1305(
            data: messageData,
            key: keyData,
            nonce: nonce
        )
        
        let payload = NIP44Payload(
            version: 2,
            nonce: nonce,
            ciphertext: encryptedData.ciphertext,
            authTag: encryptedData.authTag
        )
        
        return try payload.toBase64()
    }
    
    /// Decrypt a group message using a shared group key
    /// - Parameters:
    ///   - encryptedMessage: Base64 encoded encrypted message
    ///   - groupSharedKey: Shared key for the group (hex string)
    /// - Returns: Decrypted plaintext message
    func decryptFromGroup(encryptedMessage: String, groupSharedKey: String) throws -> String {
        let payload = try NIP44Payload.fromBase64(encryptedMessage)
        
        guard payload.version == 2 else {
            throw NIP44Error.unsupportedVersion
        }
        
        guard let keyData = Data(hexString: groupSharedKey), keyData.count == 32 else {
            throw NIP44Error.invalidKeyFormat
        }
        
        let decryptedData = try decryptChaCha20Poly1305(
            ciphertext: payload.ciphertext,
            authTag: payload.authTag,
            key: keyData,
            nonce: payload.nonce
        )
        
        guard let decryptedMessage = String(data: decryptedData, encoding: .utf8) else {
            throw NIP44Error.invalidMessageFormat
        }
        
        return decryptedMessage
    }
    
    // MARK: - Private Helper Methods
    
    private func deriveSharedSecret(privateKey: String, publicKey: String) throws -> Data {
        // Convert hex strings to data
        guard let privateKeyData = Data(hexString: privateKey), privateKeyData.count == 32 else {
            throw NIP44Error.invalidKeyFormat
        }
        
        guard let publicKeyData = Data(hexString: publicKey), publicKeyData.count == 33 else {
            throw NIP44Error.invalidKeyFormat
        }
        
        // Perform ECDH (simplified implementation for MVP)
        // In production, this would use proper secp256k1 ECDH
        let sharedSecret = try performECDH(privateKey: privateKeyData, publicKey: publicKeyData)
        
        // Apply SHA256 to the shared secret (NIP-44 requirement)
        return Data(SHA256.hash(data: sharedSecret))
    }
    
    private func performECDH(privateKey: Data, publicKey: Data) throws -> Data {
        // Simplified ECDH for MVP - in production use secp256k1
        // This is a placeholder that would need proper secp256k1 implementation
        
        // For now, create a deterministic shared secret from the keys
        var combinedData = Data()
        combinedData.append(privateKey)
        combinedData.append(publicKey)
        
        return Data(SHA256.hash(data: combinedData))
    }
    
    private func generateNonce() -> Data {
        var nonce = Data(count: 12) // 12 bytes for ChaCha20
        let result = nonce.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 12, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        if result != errSecSuccess {
            // Fallback to less secure random if SecRandom fails
            nonce = Data((0..<12).map { _ in UInt8.random(in: 0...255) })
        }
        
        return nonce
    }
    
    private func encryptChaCha20Poly1305(data: Data, key: Data, nonce: Data) throws -> NIP44EncryptedData {
        guard key.count == 32 else {
            throw NIP44Error.invalidKeyFormat
        }
        
        guard nonce.count == 12 else {
            throw NIP44Error.invalidNonce
        }
        
        do {
            let symmetricKey = SymmetricKey(data: key)
            let chachaNonce = try ChaChaPoly.Nonce(data: nonce)
            
            let sealedBox = try ChaChaPoly.seal(data, using: symmetricKey, nonce: chachaNonce)
            
            return NIP44EncryptedData(
                ciphertext: sealedBox.ciphertext,
                authTag: sealedBox.tag
            )
        } catch {
            throw NIP44Error.encryptionFailed(error.localizedDescription)
        }
    }
    
    private func decryptChaCha20Poly1305(ciphertext: Data, authTag: Data, key: Data, nonce: Data) throws -> Data {
        guard key.count == 32 else {
            throw NIP44Error.invalidKeyFormat
        }
        
        guard nonce.count == 12 else {
            throw NIP44Error.invalidNonce
        }
        
        do {
            let symmetricKey = SymmetricKey(data: key)
            let chachaNonce = try ChaChaPoly.Nonce(data: nonce)
            
            // Combine ciphertext and tag
            var combined = Data()
            combined.append(ciphertext)
            combined.append(authTag)
            
            let sealedBox = try ChaChaPoly.SealedBox(combined: combined)
            
            return try ChaChaPoly.open(sealedBox, using: symmetricKey)
        } catch {
            throw NIP44Error.decryptionFailed(error.localizedDescription)
        }
    }
}

// MARK: - Supporting Data Structures

struct NIP44Payload {
    let version: UInt8
    let nonce: Data
    let ciphertext: Data
    let authTag: Data
    
    func toBase64() throws -> String {
        var data = Data()
        data.append(version)
        data.append(nonce)
        data.append(ciphertext)
        data.append(authTag)
        
        return data.base64EncodedString()
    }
    
    static func fromBase64(_ base64String: String) throws -> NIP44Payload {
        guard let data = Data(base64Encoded: base64String) else {
            throw NIP44Error.invalidBase64
        }
        
        guard data.count >= 1 + 12 + 16 else { // version + nonce + minimum ciphertext + authTag
            throw NIP44Error.invalidPayloadLength
        }
        
        let version = data[0]
        let nonce = data.subdata(in: 1..<13)
        let authTagStart = data.count - 16
        let ciphertext = data.subdata(in: 13..<authTagStart)
        let authTag = data.subdata(in: authTagStart..<data.count)
        
        return NIP44Payload(
            version: version,
            nonce: nonce,
            ciphertext: ciphertext,
            authTag: authTag
        )
    }
}

struct NIP44EncryptedData {
    let ciphertext: Data
    let authTag: Data
}

// MARK: - Error Types

enum NIP44Error: Error, LocalizedError {
    case invalidMessageFormat
    case invalidKeyFormat
    case invalidNonce
    case invalidBase64
    case invalidPayloadLength
    case unsupportedVersion
    case encryptionFailed(String)
    case decryptionFailed(String)
    case keyDerivationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidMessageFormat:
            return "Invalid message format"
        case .invalidKeyFormat:
            return "Invalid key format"
        case .invalidNonce:
            return "Invalid nonce"
        case .invalidBase64:
            return "Invalid base64 encoding"
        case .invalidPayloadLength:
            return "Invalid payload length"
        case .unsupportedVersion:
            return "Unsupported NIP-44 version"
        case .encryptionFailed(let reason):
            return "Encryption failed: \(reason)"
        case .decryptionFailed(let reason):
            return "Decryption failed: \(reason)"
        case .keyDerivationFailed:
            return "Key derivation failed"
        }
    }
}

// MARK: - Convenience Extensions

extension Data {
    init?(hexString: String) {
        let cleanHex = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        
        guard cleanHex.count % 2 == 0 else { return nil }
        
        var data = Data()
        var index = cleanHex.startIndex
        
        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteString = String(cleanHex[index..<nextIndex])
            
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            
            index = nextIndex
        }
        
        self = data
    }
    
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Satsat Integration

extension NIP44Encryption {
    
    /// Convenience method for encrypting Satsat group messages
    func encryptSatsatGroupMessage(_ message: String, groupId: String, groupSharedKey: String) throws -> String {
        // Add Satsat-specific metadata
        let messageWithMetadata = SatsatMessage(
            content: message,
            groupId: groupId,
            timestamp: Date(),
            messageType: .groupChat
        )
        
        let messageData = try JSONEncoder().encode(messageWithMetadata)
        guard let messageString = String(data: messageData, encoding: .utf8) else {
            throw NIP44Error.invalidMessageFormat
        }
        
        return try encryptForGroup(message: messageString, groupSharedKey: groupSharedKey)
    }
    
    /// Convenience method for decrypting Satsat group messages
    func decryptSatsatGroupMessage(_ encryptedMessage: String, groupSharedKey: String) throws -> SatsatMessage {
        let decryptedString = try decryptFromGroup(
            encryptedMessage: encryptedMessage,
            groupSharedKey: groupSharedKey
        )
        
        guard let messageData = decryptedString.data(using: .utf8) else {
            throw NIP44Error.invalidMessageFormat
        }
        
        return try JSONDecoder().decode(SatsatMessage.self, from: messageData)
    }
    
    /// Encrypt a PSBT for secure sharing within a group
    func encryptPSBTForGroup(_ psbtBase64: String, groupId: String, groupSharedKey: String) throws -> String {
        let psbtMessage = SatsatMessage(
            content: psbtBase64,
            groupId: groupId,
            timestamp: Date(),
            messageType: .psbtShare
        )
        
        let messageData = try JSONEncoder().encode(psbtMessage)
        guard let messageString = String(data: messageData, encoding: .utf8) else {
            throw NIP44Error.invalidMessageFormat
        }
        
        return try encryptForGroup(message: messageString, groupSharedKey: groupSharedKey)
    }
}

// MARK: - Satsat Message Structure

struct SatsatMessage: Codable {
    let content: String
    let groupId: String
    let timestamp: Date
    let messageType: SatsatMessageType
    let metadata: [String: String]?
    
    init(content: String, groupId: String, timestamp: Date, messageType: SatsatMessageType, metadata: [String: String]? = nil) {
        self.content = content
        self.groupId = groupId
        self.timestamp = timestamp
        self.messageType = messageType
        self.metadata = metadata
    }
}

enum SatsatMessageType: String, Codable {
    case groupChat = "group_chat"
    case psbtShare = "psbt_share"
    case goalUpdate = "goal_update"
    case memberUpdate = "member_update"
    case systemMessage = "system_message"
}