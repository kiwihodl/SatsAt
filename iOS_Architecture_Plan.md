# Satsat - iOS Multisig Bitcoin Savings App

## Complete Implementation Architecture

### 🏗️ iOS App Structure

```
Satsat/
├── App/
│   ├── SatsatApp.swift                    # Main app entry point
│   └── ContentView.swift                  # Root view
├── Core/
│   ├── Security/
│   │   ├── KeychainManager.swift          # Encrypted storage
│   │   ├── CryptoManager.swift            # Encryption utilities
│   │   └── BiometricAuth.swift           # Touch/Face ID
│   ├── Bitcoin/
│   │   ├── MultisigWallet.swift          # Caravan integration
│   │   ├── PSBTManager.swift             # Transaction signing
│   │   ├── LightningManager.swift        # Lightning Network
│   │   └── BitcoinService.swift          # Core Bitcoin logic
│   ├── Nostr/
│   │   ├── NostrClient.swift             # Relay management
│   │   ├── EventManager.swift            # Event creation/signing
│   │   ├── MessageEncryption.swift       # NIP-04/44 encryption
│   │   └── InviteManager.swift           # Group invites
│   └── Networking/
│       ├── RelayConnection.swift         # WebSocket management
│       └── APIService.swift             # External APIs
├── Features/
│   ├── Onboarding/
│   │   ├── KeySetupView.swift           # Nostr key generation
│   │   └── PermissionsView.swift        # Notification setup
│   ├── Groups/
│   │   ├── CreateGroupView.swift        # Pool creation
│   │   ├── JoinGroupView.swift          # Join via invite
│   │   ├── GroupDashboardView.swift     # Main pool view
│   │   └── MemberManagementView.swift   # Add/remove members
│   ├── Wallet/
│   │   ├── ReceiveView.swift            # Address generation
│   │   ├── SendView.swift               # PSBT creation
│   │   ├── TransactionHistoryView.swift # TX history
│   │   └── PSBTSigningView.swift        # QR signing flow
│   ├── Messaging/
│   │   ├── GroupChatView.swift          # NIP-04 messaging
│   │   └── MessageBubbleView.swift      # Chat UI components
│   └── Settings/
│       ├── SettingsView.swift           # App preferences
│       ├── SecurityView.swift           # Security settings
│       └── BackupView.swift             # Key backup
├── Models/
│   ├── Group.swift                      # Pool data model
│   ├── Member.swift                     # Member model
│   ├── Goal.swift                       # Savings goal
│   ├── Transaction.swift               # Bitcoin transaction
│   └── NostrEvent.swift                # Nostr event model
├── Services/
│   ├── NotificationService.swift        # Push notifications
│   ├── BackgroundTaskService.swift     # Background updates
│   └── QRCodeService.swift             # QR generation/scanning
└── Resources/
    ├── Localizable.strings              # Localization
    └── Assets.xcassets/                 # Dark mode assets
```

## 🔐 Two-Tier Encryption Strategy (Based on Seed-E)

### Personal vs Group Data Encryption

Following your Seed-E approach with AES-256-GCM and context-specific keys:

```swift
// Two encryption tiers:
// 1. Personal Data: Only user can decrypt (messages, private keys)
// 2. Group Data: All group members can decrypt (xpubs, balances, goals)

class SatsatEncryptionManager {
    // Personal master key (user-specific, stored in Keychain)
    func getUserMasterKey() -> SymmetricKey

    // Group master key (shared among group members via Nostr)
    func getGroupMasterKey(for groupId: String) -> SymmetricKey

    // Context-specific key derivation (Seed-E approach)
    func deriveContextKey(masterKey: SymmetricKey, context: ContextType, identifier: String) -> SymmetricKey
}
```

### Context-Specific Encryption (Seed-E Pattern)

```swift
// Different contexts for different data types
enum ContextType: String {
    case userPrivateData = "user_private"
    case groupSharedData = "group_shared"
    case userMessages = "user_messages"
    case groupXpub = "group_xpub"        // All members can decrypt
    case groupBalances = "group_balances" // All members can decrypt
    case groupGoals = "group_goals"       // All members can decrypt
}

// Example: Store extended public keys (group-shared)
func storeGroupXpubs(_ xpubData: [MemberXpubData], groupId: String) throws {
    let encryptedData = try encryptionManager.encryptGroupSharedData(
        xpubData,
        groupId: groupId,
        context: .groupXpub
    )
    // Store in Core Data as JSON
}
```

### Database Schema (Encrypted Fields)

```swift
// Core Data entities store encrypted JSON blobs
@objc(EncryptedGroupData)
public class EncryptedGroupData: NSManagedObject {
    @NSManaged public var groupId: String
    @NSManaged public var dataType: String // "xpubs", "balances", "goals"
    @NSManaged public var encryptedData: Data // JSON serialized EncryptedData
    @NSManaged public var lastModified: Date
    @NSManaged public var version: Int32 // For future key rotation
}

// User's private data (messages, keys)
@objc(EncryptedUserData)
public class EncryptedUserData: NSManagedObject {
    @NSManaged public var userId: String
    @NSManaged public var dataType: String
    @NSManaged public var identifier: String
    @NSManaged public var encryptedData: Data
    @NSManaged public var lastModified: Date
}
```

## 📱 iOS-Specific Library Recommendations

### Bitcoin Stack

```swift
// Package.swift dependencies
dependencies: [
    // Bitcoin Core
    .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1.git", .upToNextMajor(from: "0.21.1")),
    .package(url: "https://github.com/BlockchainCommons/BCSwiftSecureComponents.git", .upToNextMajor(from: "2.0.0")),

    // Nostr
    .package(url: "https://github.com/nostur-com/nostr-essentials.git", .upToNextMajor(from: "1.0.0")),

    // Lightning (if needed)
    .package(url: "https://github.com/lightningdevkit/ldk-swift", .upToNextMajor(from: "0.1.0")),

    // QR Codes
    .package(url: "https://github.com/dmrschmidt/QRCode", .upToNextMajor(from: "1.0.0")),
]
```

### Multisig Wallet Implementation

```swift
// MultisigWallet.swift
import BCSecureComponents
import P256K

class MultisigWallet: ObservableObject {
    @Published var balance: UInt64 = 0
    @Published var goal: UInt64
    @Published var members: [Member]

    private let threshold: Int
    private let scriptType: ScriptType = .witnessScriptHash

    func generateMultisigAddress() throws -> String {
        let publicKeys = members.compactMap { $0.publicKey }
        guard publicKeys.count >= threshold else {
            throw WalletError.insufficientKeys
        }

        // Create multisig script using BCSecureComponents
        let script = try MultisigScript(
            threshold: threshold,
            publicKeys: publicKeys
        )

        return try script.address(for: .mainnet)
    }

    func createPSBT(to address: String, amount: UInt64) throws -> String {
        // Use Caravan-style PSBT creation
        // Implementation details...
    }
}
```

## 🔔 Push Notifications Without Backend

### Nostr-Based Notification Strategy

```swift
// NotificationService.swift
import UserNotifications
import NostrEssentials

class NotificationService: ObservableObject {
    private let nostrClient = NostrClient.shared

    func setupNotifications() {
        // Subscribe to group events on Nostr relays
        subscribeToGroupEvents()

        // Handle incoming events
        nostrClient.onEvent = { [weak self] event in
            self?.handleNostrEvent(event)
        }
    }

    private func handleNostrEvent(_ event: NostrEvent) {
        switch event.kind {
        case 1000: // Custom: PSBT requires signing
            scheduleSigningNotification(event)
        case 1001: // Custom: Goal reached
            scheduleGoalNotification(event)
        default:
            break
        }
    }

    private func scheduleSigningNotification(_ event: NostrEvent) {
        let content = UNMutableNotificationContent()
        content.title = "🔐 Signature Required"
        content.body = "Your group needs your signature to complete a transaction"
        content.sound = .default
        content.userInfo = ["eventId": event.id]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
```

## 🏪 App Store Compliance Strategy

### Key Compliance Points

1. **Avoid "Buy" Language**: Use "Request Payment", "Generate Invoice"
2. **No Direct Exchange Features**: Link to external exchanges via Safari
3. **Clear Educational Purpose**: Position as savings/education tool
4. **Proper Disclaimers**: Include financial risk warnings

### App Store Description Template

```
Satsat - Bitcoin Savings Groups

Build financial discipline with friends through collaborative Bitcoin savings goals.

KEY FEATURES:
• Create savings groups with trusted friends (2-9 people)
• Set collective Bitcoin savings targets
• Secure multisig wallet technology
• Encrypted group messaging
• Goal tracking and progress sharing

EDUCATIONAL FOCUS:
Learn about Bitcoin, multisig security, and collaborative saving while building healthy financial habits with your social circle.

IMPORTANT: This app is for educational purposes. Bitcoin involves financial risk. Only save amounts you can afford to lose.
```

## ⚡ Lightning Integration for iOS

### LDK Swift Integration

```swift
// LightningManager.swift
import LightningDevKit

class LightningManager: ObservableObject {
    private var channelManager: ChannelManager?
    private var peerManager: PeerManager?

    func setupLightningNode() {
        // Initialize LDK components for iOS
        // This enables Lightning deposits to the multisig
    }

    func generateInvoice(amountSats: UInt64, memo: String) -> String {
        // Create Lightning invoice for group deposits
        // Implementation using LDK...
    }
}
```

## 🚀 Development Timeline (Revised)

### Day 1-2: Foundation & Security

- Set up project structure
- Implement Keychain integration
- Basic Nostr key generation
- Biometric authentication

### Day 3-4: Core Functionality

- Multisig wallet creation (Caravan integration)
- Group creation/joining via Nostr
- Basic messaging (NIP-04)

### Day 5-6: UI & UX

- Dark mode implementation
- Cash App-inspired design
- QR code scanning/generation
- PSBT signing flow

### Day 7: Polish & Submission

- App Store compliance review
- Final testing
- Submission preparation

This enhanced plan addresses the encryption, iOS-specific libraries, App Store compliance, and detailed architecture that were missing from the original response.
