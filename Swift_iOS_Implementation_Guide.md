# Swift iOS Implementation Guide for Satsat

## 📱 Complete iOS-Specific Implementation

This guide provides concrete Swift code and iOS-specific patterns that were missing from the original conversation.

## Package Dependencies

### Package.swift Setup

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Satsat",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "Satsat", targets: ["Satsat"])
    ],
    dependencies: [
        // Bitcoin & Cryptography
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1.git", .upToNextMajor(from: "0.21.1")),
        .package(url: "https://github.com/BlockchainCommons/BCSwiftSecureComponents.git", .upToNextMajor(from: "2.0.0")),

        // Nostr Implementation
        .package(url: "https://github.com/nostur-com/nostr-essentials.git", .upToNextMajor(from: "1.0.0")),

        // QR Code Generation
        .package(url: "https://github.com/dmrschmidt/QRCode", .upToNextMajor(from: "1.0.0")),

        // Networking & WebSockets
        .package(url: "https://github.com/daltoniam/Starscream.git", .upToNextMajor(from: "4.0.0")),
    ],
    targets: [
        .target(
            name: "Satsat",
            dependencies: [
                .product(name: "P256K", package: "swift-secp256k1"),
                .product(name: "SecureComponents", package: "BCSwiftSecureComponents"),
                .product(name: "NostrEssentials", package: "nostr-essentials"),
                .product(name: "QRCode", package: "QRCode"),
                .product(name: "Starscream", package: "Starscream"),
            ]
        )
    ]
)
```

## 1. Core Bitcoin Implementation

### Multisig Wallet with Swift Secp256k1

```swift
// MultisigWallet.swift
import Foundation
import P256K
import SecureComponents

class MultisigWallet: ObservableObject {
    @Published var balance: UInt64 = 0
    @Published var goal: UInt64
    @Published var progress: Double = 0.0

    private let threshold: Int
    private let publicKeys: [P256K.Signing.PublicKey]
    private let myPrivateKey: P256K.Signing.PrivateKey?

    init(threshold: Int, publicKeys: [Data], myPrivateKey: Data? = nil) throws {
        self.threshold = threshold
        self.goal = 0

        // Convert Data to P256K public keys
        self.publicKeys = try publicKeys.map { keyData in
            try P256K.Signing.PublicKey(dataRepresentation: keyData)
        }

        // Load private key if available
        if let privKeyData = myPrivateKey {
            self.myPrivateKey = try P256K.Signing.PrivateKey(dataRepresentation: privKeyData)
        } else {
            self.myPrivateKey = nil
        }
    }

    // Generate multisig address using Script descriptors
    func generateAddress() throws -> String {
        let sortedPubKeys = publicKeys.sorted { lhs, rhs in
            lhs.dataRepresentation.lexicographicallyPrecedes(rhs.dataRepresentation)
        }

        // Create witnessScript for P2WSH
        let witnessScript = try createMultisigScript(threshold: threshold, publicKeys: sortedPubKeys)
        let scriptHash = SHA256.hash(data: witnessScript)

        // Encode as bech32 P2WSH address
        return try encodeBech32Address(scriptHash: Data(scriptHash), network: .mainnet)
    }

    private func createMultisigScript(threshold: Int, publicKeys: [P256K.Signing.PublicKey]) throws -> Data {
        var script = Data()

        // OP_M (threshold)
        script.append(0x50 + UInt8(threshold))

        // Public keys
        for pubKey in publicKeys {
            let compressedPubKey = pubKey.dataRepresentation
            script.append(UInt8(compressedPubKey.count))
            script.append(compressedPubKey)
        }

        // OP_N (total keys)
        script.append(0x50 + UInt8(publicKeys.count))

        // OP_CHECKMULTISIG
        script.append(0xae)

        return script
    }

    // Update balance from external source
    func updateBalance() async {
        // In real implementation, query blockchain
        // For now, simulate with UserDefaults
        let savedBalance = UserDefaults.standard.object(forKey: "wallet_balance") as? UInt64 ?? 0

        await MainActor.run {
            self.balance = savedBalance
            self.progress = goal > 0 ? Double(balance) / Double(goal) : 0.0
        }
    }
}

// Bitcoin network configuration
enum BitcoinNetwork {
    case mainnet
    case testnet
    case regtest
}

// Bech32 address encoding (simplified)
func encodeBech32Address(scriptHash: Data, network: BitcoinNetwork) throws -> String {
    let hrp = network == .mainnet ? "bc" : "tb"
    // Simplified bech32 encoding - in production use proper library
    return "\(hrp)1q" + scriptHash.prefix(20).hexEncodedString()
}

extension Data {
    var hexEncodedString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
```

### PSBT (Partially Signed Bitcoin Transaction) Handler

```swift
// PSBTManager.swift
import Foundation
import P256K

struct PSBT {
    let version: UInt32
    let inputs: [PSBTInput]
    let outputs: [PSBTOutput]
    var signatures: [Int: Data] = [:]

    var isComplete: Bool {
        // Check if we have enough signatures
        return signatures.count >= requiredSignatures
    }

    private let requiredSignatures: Int

    init(inputs: [PSBTInput], outputs: [PSBTOutput], requiredSignatures: Int) {
        self.version = 2
        self.inputs = inputs
        self.outputs = outputs
        self.requiredSignatures = requiredSignatures
    }
}

struct PSBTInput {
    let previousOutput: OutPoint
    let witnessScript: Data
    let value: UInt64
}

struct PSBTOutput {
    let address: String
    let value: UInt64
}

struct OutPoint {
    let txid: Data
    let vout: UInt32
}

class PSBTManager: ObservableObject {
    @Published var pendingPSBTs: [PSBT] = []
    @Published var completedPSBTs: [PSBT] = []

    private let wallet: MultisigWallet
    private let privateKey: P256K.Signing.PrivateKey?

    init(wallet: MultisigWallet, privateKey: P256K.Signing.PrivateKey?) {
        self.wallet = wallet
        self.privateKey = privateKey
    }

    // Create new PSBT for spending
    func createPSBT(to address: String, amount: UInt64, fee: UInt64 = 1000) throws -> PSBT {
        // Simplified PSBT creation
        let output = PSBTOutput(address: address, value: amount)
        let inputs = try createInputsForAmount(amount + fee)

        let psbt = PSBT(
            inputs: inputs,
            outputs: [output],
            requiredSignatures: wallet.threshold
        )

        pendingPSBTs.append(psbt)
        return psbt
    }

    // Sign PSBT with our private key
    func signPSBT(_ psbt: inout PSBT) throws {
        guard let privateKey = privateKey else {
            throw PSBTError.noPrivateKey
        }

        for (index, input) in psbt.inputs.enumerated() {
            let sighash = try createSighash(for: input, psbt: psbt, inputIndex: index)
            let signature = try privateKey.signature(for: sighash)
            psbt.signatures[index] = signature.derRepresentation
        }
    }

    private func createInputsForAmount(_ amount: UInt64) throws -> [PSBTInput] {
        // Simplified - in real implementation, select UTXOs
        return []
    }

    private func createSighash(for input: PSBTInput, psbt: PSBT, inputIndex: Int) throws -> Data {
        // Simplified sighash calculation
        // In real implementation, follow BIP 143 for witness transactions
        return Data("dummy_sighash".utf8)
    }
}

enum PSBTError: Error {
    case noPrivateKey
    case insufficientFunds
    case invalidTransaction
}
```

## 2. Nostr Integration

### Nostr Client with Starscream WebSockets

```swift
// NostrClient.swift
import Foundation
import NostrEssentials
import Starscream
import Combine

class NostrClient: ObservableObject, WebSocketDelegate {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var receivedEvents: [NostrEvent] = []

    private var webSocket: WebSocket?
    private let relayURL: URL
    private var subscriptions: [String: Subscription] = [:]
    private let keys: Keys

    enum ConnectionStatus {
        case connected
        case connecting
        case disconnected
        case error(Error)
    }

    init(relayURL: URL, keys: Keys) {
        self.relayURL = relayURL
        self.keys = keys
    }

    // Connect to Nostr relay
    func connect() {
        connectionStatus = .connecting

        var request = URLRequest(url: relayURL)
        request.setValue("nostr", forHTTPHeaderField: "Sec-WebSocket-Protocol")

        webSocket = WebSocket(request: request)
        webSocket?.delegate = self
        webSocket?.connect()
    }

    // Subscribe to events
    func subscribe(filters: [Filters], subscriptionId: String = UUID().uuidString) {
        let subscription = Subscription(id: subscriptionId, filters: filters)
        subscriptions[subscriptionId] = subscription

        let message = ClientMessage(type: .REQ, subscriptionId: subscriptionId, filters: filters)
        if let jsonString = message.json() {
            webSocket?.write(string: jsonString)
        }
    }

    // Publish event
    func publish(event: Event) {
        let message = ClientMessage(type: .EVENT, event: event)
        if let jsonString = message.json() {
            webSocket?.write(string: jsonString)
        }
    }

    // Send encrypted message to group
    func sendGroupMessage(_ content: String, to groupMembers: [String]) throws {
        for memberPubkey in groupMembers {
            guard let encryptedContent = Keys.encryptDirectMessageContent44(
                withPrivatekey: keys.privateKeyHex,
                pubkey: memberPubkey,
                content: content
            ) else {
                throw NostrError.encryptionFailed
            }

            let dmEvent = Event(
                pubkey: keys.publicKeyHex,
                content: encryptedContent,
                kind: 4, // DM
                tags: [["p", memberPubkey]]
            )

            let signedEvent = try dmEvent.sign(keys)
            publish(event: signedEvent)
        }
    }

    // WebSocket Delegate Methods
    func didReceive(event: WebSocketEvent, client: any WebSocketClient) {
        switch event {
        case .connected:
            DispatchQueue.main.async {
                self.connectionStatus = .connected
            }
        case .disconnected(let reason, let code):
            DispatchQueue.main.async {
                self.connectionStatus = .disconnected
            }
        case .text(let text):
            handleNostrMessage(text)
        case .error(let error):
            DispatchQueue.main.async {
                self.connectionStatus = .error(error)
            }
        default:
            break
        }
    }

    private func handleNostrMessage(_ message: String) {
        guard let messageData = message.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: messageData) as? [Any],
              let messageType = jsonArray.first as? String else {
            return
        }

        switch messageType {
        case "EVENT":
            if jsonArray.count >= 3,
               let eventDict = jsonArray[2] as? [String: Any],
               let eventData = try? JSONSerialization.data(withJSONObject: eventDict),
               let event = try? JSONDecoder().decode(Event.self, from: eventData) {

                DispatchQueue.main.async {
                    self.receivedEvents.append(event)
                }

                // Handle specific event types
                handleEvent(event)
            }
        case "EOSE":
            // End of stored events
            break
        case "NOTICE":
            // Relay notice
            break
        default:
            break
        }
    }

    private func handleEvent(_ event: Event) {
        switch event.kind {
        case 4: // Encrypted DM
            handleEncryptedMessage(event)
        case 1000: // Custom: PSBT signing request
            handlePSBTRequest(event)
        case 1001: // Custom: Goal update
            handleGoalUpdate(event)
        default:
            break
        }
    }

    private func handleEncryptedMessage(_ event: Event) {
        // Decrypt and process message
        if let decryptedContent = Keys.decryptDirectMessageContent44(
            withPrivateKey: keys.privateKeyHex,
            pubkey: event.pubkey,
            content: event.content
        ) {
            // Process decrypted message
            NotificationCenter.default.post(
                name: .newGroupMessage,
                object: GroupMessage(
                    sender: event.pubkey,
                    content: decryptedContent,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(event.created_at))
                )
            )
        }
    }

    private func handlePSBTRequest(_ event: Event) {
        // Handle PSBT signing request
        NotificationCenter.default.post(
            name: .psbtSigningRequest,
            object: event
        )
    }

    private func handleGoalUpdate(_ event: Event) {
        // Handle goal progress update
        NotificationCenter.default.post(
            name: .goalProgressUpdate,
            object: event
        )
    }
}

// Custom notification names
extension Notification.Name {
    static let newGroupMessage = Notification.Name("newGroupMessage")
    static let psbtSigningRequest = Notification.Name("psbtSigningRequest")
    static let goalProgressUpdate = Notification.Name("goalProgressUpdate")
}

struct GroupMessage {
    let sender: String
    let content: String
    let timestamp: Date
}

struct Subscription {
    let id: String
    let filters: [Filters]
}

enum NostrError: Error {
    case encryptionFailed
    case decryptionFailed
    case connectionFailed
    case invalidEvent
}
```

## 3. SwiftUI Views

### Main Dashboard View

```swift
// GroupDashboardView.swift
import SwiftUI
import QRCode

struct GroupDashboardView: View {
    @StateObject private var wallet: MultisigWallet
    @StateObject private var nostrClient: NostrClient
    @State private var showingReceiveView = false
    @State private var showingSendView = false

    init(wallet: MultisigWallet, nostrClient: NostrClient) {
        self._wallet = StateObject(wrappedValue: wallet)
        self._nostrClient = StateObject(wrappedValue: nostrClient)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Goal Progress Section
                    goalProgressSection

                    // Member Avatars
                    memberAvatarsSection

                    // Quick Actions
                    quickActionsSection

                    // Recent Activity
                    recentActivitySection
                }
                .padding()
            }
            .navigationTitle("Bitcoin Squad")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .task {
                await wallet.updateBalance()
            }
        }
    }

    private var goalProgressSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Road Trip Fund")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("\(wallet.balance) sats")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Goal: \(wallet.goal) sats")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(Int(wallet.progress * 100))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }

            // Progress bar
            ProgressView(value: wallet.progress)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(x: 1, y: 2)
                .animation(.easeInOut, value: wallet.progress)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }

    private var memberAvatarsSection: some View {
        VStack(alignment: .leading) {
            Text("Squad Members")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5) { index in
                        MemberAvatarView(
                            name: "Member \(index + 1)",
                            isOnline: Bool.random()
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var quickActionsSection: some View {
        HStack(spacing: 16) {
            ActionButton(
                title: "Receive",
                icon: "qrcode",
                color: .green
            ) {
                showingReceiveView = true
            }

            ActionButton(
                title: "Send",
                icon: "arrow.up.circle",
                color: .blue
            ) {
                showingSendView = true
            }

            NavigationLink(destination: GroupChatView()) {
                ActionButtonView(
                    title: "Chat",
                    icon: "message.circle",
                    color: .purple
                )
            }
        }
        .sheet(isPresented: $showingReceiveView) {
            ReceiveView(wallet: wallet)
        }
        .sheet(isPresented: $showingSendView) {
            SendView(wallet: wallet)
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.horizontal)

            LazyVStack(spacing: 8) {
                ForEach(0..<3) { index in
                    ActivityRowView(
                        title: "Received 50,000 sats",
                        subtitle: "From Alice • 2 hours ago",
                        icon: "arrow.down.circle.fill",
                        iconColor: .green
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct MemberAvatarView: View {
    let name: String
    let isOnline: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.orange.gradient)
                    .frame(width: 50, height: 50)

                Text(String(name.prefix(1)))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .offset(x: 18, y: -18)
                }
            }

            Text(name.components(separatedBy: " ").first ?? "")
                .font(.caption)
                .lineLimit(1)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ActionButtonView(title: title, icon: icon, color: color)
        }
    }
}

struct ActionButtonView: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct ActivityRowView: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}
```

### QR Code Receive View

```swift
// ReceiveView.swift
import SwiftUI
import QRCode

struct ReceiveView: View {
    let wallet: MultisigWallet
    @State private var address: String = ""
    @State private var showingCopiedAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Receive Bitcoin")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Share this address with your group members or external Bitcoin apps")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                // QR Code
                if !address.isEmpty {
                    QRCodeView(data: address)
                        .frame(width: 250, height: 250)
                        .background(Color.white)
                        .cornerRadius(16)
                }

                // Address text
                VStack(spacing: 12) {
                    Text("Bitcoin Address")
                        .font(.headline)

                    Text(address)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                        .onTapGesture {
                            UIPasteboard.general.string = address
                            showingCopiedAlert = true
                        }
                }

                Button("Copy Address") {
                    UIPasteboard.general.string = address
                    showingCopiedAlert = true
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                // Educational disclaimer
                Text("Educational Note: To obtain Bitcoin, use external licensed services like Strike or Cash App.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Address Copied", isPresented: $showingCopiedAlert) {
                Button("OK") { }
            }
            .task {
                do {
                    address = try wallet.generateAddress()
                } catch {
                    print("Failed to generate address: \(error)")
                }
            }
        }
    }
}

struct QRCodeView: View {
    let data: String

    var body: some View {
        if let qrCodeImage = generateQRCode(from: data) {
            Image(uiImage: qrCodeImage)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Text("Unable to generate QR code")
                        .foregroundColor(.secondary)
                )
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 3, y: 3)

            if let output = filter.outputImage?.transformed(by: transform) {
                let context = CIContext()
                if let cgImage = context.createCGImage(output, from: output.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }

        return nil
    }
}
```

## 4. Push Notifications

### Notification Service

```swift
// NotificationService.swift
import UserNotifications
import Foundation

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )

            await MainActor.run {
                self.authorizationStatus = granted ? .authorized : .denied
            }
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    func scheduleSigningNotification(for psbt: PSBT) {
        let content = UNMutableNotificationContent()
        content.title = "🔐 Signature Required"
        content.body = "Your group needs your signature to complete a transaction"
        content.sound = .default
        content.categoryIdentifier = "PSBT_SIGNING"

        let request = UNNotificationRequest(
            identifier: "psbt-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleGoalNotification(progress: Double) {
        let content = UNMutableNotificationContent()
        content.title = "🎯 Goal Progress"
        content.body = "Your group has reached \(Int(progress * 100))% of your savings goal!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "goal-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        let identifier = response.notification.request.identifier

        if identifier.starts(with: "psbt-") {
            // Navigate to PSBT signing view
            NotificationCenter.default.post(name: .openPSBTSigning, object: nil)
        }

        completionHandler()
    }
}

extension Notification.Name {
    static let openPSBTSigning = Notification.Name("openPSBTSigning")
}
```

This comprehensive iOS implementation guide provides the concrete Swift code that was missing from the original conversation, covering Bitcoin multisig wallets, Nostr integration, SwiftUI views, and iOS-specific features like push notifications and QR codes.
