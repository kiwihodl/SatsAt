# Data Encryption at Rest - iOS Implementation Guide

## 🔐 Comprehensive Encryption Strategy for Satsat

The user specifically requested that "all data stored should be encrypted at rest." Here's a complete implementation strategy for iOS.

## Security Architecture

### Three-Layer Security Model

1. **iOS Keychain** - For cryptographic keys and secrets
2. **Application-Level Encryption** - For Core Data and file storage
3. **Biometric Protection** - For access control

```swift
// SecurityManager.swift - Central security coordinator
import Security
import CryptoKit
import LocalAuthentication

class SecurityManager: ObservableObject {
    static let shared = SecurityManager()

    private let keychain = KeychainManager.shared
    private let crypto = CryptoManager.shared
    private let biometric = BiometricManager.shared

    // Master encryption key for app data
    private var masterKey: SymmetricKey?

    func initializeSecurity() async throws {
        try await authenticateUser()
        try await loadOrCreateMasterKey()
    }
}
```

## 1. iOS Keychain Implementation

### Secure Key Storage

```swift
// KeychainManager.swift
import Security
import LocalAuthentication

class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.satsthestandard.satsat"

    enum KeyType: String {
        case nostrPrivateKey = "nostr_private"
        case masterEncryptionKey = "master_encryption"
        case multisigXprv = "multisig_xprv"
        case groupSecrets = "group_secrets"
    }

    // Store sensitive data with biometric protection
    func store<T: Codable>(_ item: T, for key: KeyType, requireBiometrics: Bool = true) throws {
        let data = try JSONEncoder().encode(item)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        if requireBiometrics {
            query[kSecAttrAccessControl as String] = createBiometricAccessControl()
        }

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storageFailure(status)
        }
    }

    // Retrieve with biometric authentication
    func retrieve<T: Codable>(_ type: T.Type, for key: KeyType) throws -> T {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            throw KeychainError.retrievalFailure(status)
        }

        return try JSONDecoder().decode(type, from: data)
    }

    private func createBiometricAccessControl() -> SecAccessControl {
        return SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryAny, .devicePasscode],
            nil
        )!
    }
}

enum KeychainError: Error {
    case storageFailure(OSStatus)
    case retrievalFailure(OSStatus)
    case biometricFailure
}
```

## 2. Application-Level Encryption

### Master Key Generation

```swift
// CryptoManager.swift
import CryptoKit
import Foundation

class CryptoManager {
    static let shared = CryptoManager()

    // Generate or retrieve master encryption key
    func getMasterKey() throws -> SymmetricKey {
        do {
            // Try to retrieve existing key
            let keyData = try KeychainManager.shared.retrieve(Data.self, for: .masterEncryptionKey)
            return SymmetricKey(data: keyData)
        } catch {
            // Generate new key if none exists
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            try KeychainManager.shared.store(keyData, for: .masterEncryptionKey)
            return newKey
        }
    }

    // Encrypt data for storage
    func encrypt(_ data: Data, with key: SymmetricKey) throws -> EncryptedData {
        let sealedBox = try AES.GCM.seal(data, using: key)

        return EncryptedData(
            ciphertext: sealedBox.ciphertext,
            nonce: sealedBox.nonce,
            tag: sealedBox.tag
        )
    }

    // Decrypt data from storage
    func decrypt(_ encryptedData: EncryptedData, with key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(
            nonce: encryptedData.nonce,
            ciphertext: encryptedData.ciphertext,
            tag: encryptedData.tag
        )

        return try AES.GCM.open(sealedBox, using: key)
    }
}

// Encrypted data container
struct EncryptedData: Codable {
    let ciphertext: Data
    let nonce: AES.GCM.Nonce
    let tag: Data

    init(ciphertext: Data, nonce: AES.GCM.Nonce, tag: Data) {
        self.ciphertext = ciphertext
        self.nonce = nonce
        self.tag = tag
    }
}
```

## 3. Core Data Encryption

### Encrypted Core Data Model

```swift
// EncryptedGroup.swift - Core Data model
import CoreData
import Foundation

@objc(EncryptedGroup)
public class EncryptedGroup: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var encryptedData: Data  // Encrypted group data
    @NSManaged public var createdAt: Date
    @NSManaged public var lastModified: Date
}

// Group data that gets encrypted
struct GroupData: Codable {
    let name: String
    let members: [Member]
    let goal: Goal
    let multisigConfig: MultisigConfig
    let nostrGroupId: String
    let messages: [Message]
}

// Core Data service with encryption
class EncryptedCoreDataService {
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Satsat")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
        }
        return container
    }()

    func saveGroup(_ group: GroupData) throws {
        let context = persistentContainer.viewContext
        let masterKey = try CryptoManager.shared.getMasterKey()

        // Encrypt the group data
        let groupDataEncoded = try JSONEncoder().encode(group)
        let encryptedData = try CryptoManager.shared.encrypt(groupDataEncoded, with: masterKey)
        let encryptedDataEncoded = try JSONEncoder().encode(encryptedData)

        // Save to Core Data
        let encryptedGroup = EncryptedGroup(context: context)
        encryptedGroup.id = UUID()
        encryptedGroup.encryptedData = encryptedDataEncoded
        encryptedGroup.createdAt = Date()
        encryptedGroup.lastModified = Date()

        try context.save()
    }

    func loadGroup(id: UUID) throws -> GroupData {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<EncryptedGroup> = EncryptedGroup.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        guard let encryptedGroup = try context.fetch(request).first else {
            throw DataError.groupNotFound
        }

        // Decrypt the data
        let masterKey = try CryptoManager.shared.getMasterKey()
        let encryptedData = try JSONDecoder().decode(EncryptedData.self, from: encryptedGroup.encryptedData)
        let decryptedData = try CryptoManager.shared.decrypt(encryptedData, with: masterKey)

        return try JSONDecoder().decode(GroupData.self, from: decryptedData)
    }
}
```

## 4. Biometric Authentication

### Face ID / Touch ID Integration

```swift
// BiometricManager.swift
import LocalAuthentication

class BiometricManager: ObservableObject {
    static let shared = BiometricManager()

    @Published var biometricType: LABiometryType = .none
    @Published var isAvailable = false

    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?

        isAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricType = context.biometryType
    }

    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        let context = LAContext()

        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return result
        } catch {
            throw BiometricError.authenticationFailed(error)
        }
    }

    func authenticateWithDevicePasscode(reason: String) async throws -> Bool {
        let context = LAContext()

        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return result
        } catch {
            throw BiometricError.authenticationFailed(error)
        }
    }
}

enum BiometricError: Error {
    case authenticationFailed(Error)
    case notAvailable
    case notEnrolled
}
```

## 5. Nostr Event Encryption

### NIP-44 Message Encryption

```swift
// NostrEncryption.swift
import NostrEssentials
import CryptoKit

class NostrEncryption {
    static let shared = NostrEncryption()

    // Encrypt messages using NIP-44
    func encryptMessage(_ message: String, to recipientPubkey: String, from senderPrivkey: String) throws -> String {
        // Use NostrEssentials for NIP-44 encryption
        guard let encryptedMessage = Keys.encryptDirectMessageContent44(
            withPrivatekey: senderPrivkey,
            pubkey: recipientPubkey,
            content: message
        ) else {
            throw NostrError.encryptionFailed
        }

        return encryptedMessage
    }

    // Decrypt messages using NIP-44
    func decryptMessage(_ encryptedMessage: String, from senderPubkey: String, to recipientPrivkey: String) throws -> String {
        guard let decryptedMessage = Keys.decryptDirectMessageContent44(
            withPrivateKey: recipientPrivkey,
            pubkey: senderPubkey,
            content: encryptedMessage
        ) else {
            throw NostrError.decryptionFailed
        }

        return decryptedMessage
    }
}

enum NostrError: Error {
    case encryptionFailed
    case decryptionFailed
    case invalidKey
}
```

## 6. Secure File Storage

### Encrypted Document Storage

```swift
// SecureFileManager.swift
import Foundation

class SecureFileManager {
    static let shared = SecureFileManager()

    private let documentsURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()

    // Save encrypted file
    func saveSecureFile<T: Codable>(_ object: T, to filename: String) throws {
        let masterKey = try CryptoManager.shared.getMasterKey()
        let data = try JSONEncoder().encode(object)
        let encryptedData = try CryptoManager.shared.encrypt(data, with: masterKey)
        let encryptedDataEncoded = try JSONEncoder().encode(encryptedData)

        let fileURL = documentsURL.appendingPathComponent("\(filename).encrypted")
        try encryptedDataEncoded.write(to: fileURL)
    }

    // Load encrypted file
    func loadSecureFile<T: Codable>(_ type: T.Type, from filename: String) throws -> T {
        let fileURL = documentsURL.appendingPathComponent("\(filename).encrypted")
        let encryptedDataEncoded = try Data(contentsOf: fileURL)

        let masterKey = try CryptoManager.shared.getMasterKey()
        let encryptedData = try JSONDecoder().decode(EncryptedData.self, from: encryptedDataEncoded)
        let decryptedData = try CryptoManager.shared.decrypt(encryptedData, with: masterKey)

        return try JSONDecoder().decode(type, from: decryptedData)
    }
}
```

## 7. Memory Protection

### Secure Memory Handling

```swift
// SecureMemory.swift
import Foundation

class SecureMemory {
    // Zero out sensitive data when done
    static func secureZero(_ data: inout Data) {
        data.withUnsafeMutableBytes { bytes in
            memset_s(bytes.baseAddress, bytes.count, 0, bytes.count)
        }
    }

    // Secure string handling
    static func withSecureString<T>(_ string: String, perform: (UnsafePointer<CChar>) throws -> T) rethrows -> T {
        return try string.withCString(perform)
    }
}
```

## Implementation Checklist

### Essential Security Measures

- ✅ **Keychain Storage**: All cryptographic keys stored in iOS Keychain
- ✅ **Biometric Protection**: Face ID/Touch ID for key access
- ✅ **AES-256-GCM Encryption**: All data encrypted with modern crypto
- ✅ **Core Data Encryption**: Database contents encrypted
- ✅ **File System Encryption**: Documents encrypted on disk
- ✅ **NIP-44 Messaging**: Nostr messages encrypted end-to-end
- ✅ **Memory Protection**: Sensitive data zeroed after use
- ✅ **No Plain Text Storage**: No sensitive data stored unencrypted

### Security Best Practices

1. **Never log sensitive data** in production
2. **Use secure deletion** for temporary files
3. **Implement app backgrounding protection** (hide sensitive UI)
4. **Regular security audits** of encryption implementation
5. **Key rotation strategy** for long-term security

This comprehensive encryption strategy ensures that all data is properly encrypted at rest on iOS devices, meeting the user's security requirements while maintaining usability.
