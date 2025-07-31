// PSBTManager.swift
// Advanced PSBT (Partially Signed Bitcoin Transaction) management for group coordination

import Foundation
import Combine
import UserNotifications
import CoreData

// MARK: - PSBT Manager

class PSBTManager: ObservableObject {
    static let shared = PSBTManager()
    
    @Published var activePSBTs: [GroupPSBT] = []
    @Published var pendingSignatures: [PendingSignature] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let encryptionManager = SatsatEncryptionManager.shared
    private let nostrClient = NostrClient.shared
    private let keychainManager = KeychainManager.shared
    private let coreDataManager = CoreDataManager.shared
    private let groupManager = GroupManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    private let currentUserId = "default_user"
    
    private init() {
        setupObservers()
        loadActivePSBTs()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Listen for PSBT signing requests
        NotificationCenter.default.publisher(for: .psbtSigningRequired)
            .sink { [weak self] notification in
                self?.handlePSBTSigningRequest(notification)
            }
            .store(in: &cancellables)
        
        // Listen for PSBT updates
        NotificationCenter.default.publisher(for: .psbtUpdateReceived)
            .sink { [weak self] notification in
                self?.handlePSBTUpdate(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - PSBT Creation
    
    /// Broadcast a fully signed PSBT to the Bitcoin network
    func broadcastPSBT(_ psbtId: String) async throws {
        guard let psbt = activePSBTs.first(where: { $0.id == psbtId }) else {
            throw PSBTError.psbtNotFound
        }
        
        guard psbt.isFullySigned else {
            throw PSBTError.insufficientSignatures
        }
        
        // Update status to broadcasting
        if let index = activePSBTs.firstIndex(where: { $0.id == psbtId }) {
            activePSBTs[index].status = .broadcasted
        }
        
        // Simulate network broadcast
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Update to confirmed status
        if let index = activePSBTs.firstIndex(where: { $0.id == psbtId }) {
            activePSBTs[index].status = .confirmed
            activePSBTs[index].transactionId = "txid_\(UUID().uuidString.prefix(8))"
            activePSBTs[index].finalizedAt = Date()
        }
        
        // Notify via Nostr
        await broadcastTransactionUpdate(psbt)
    }
    
    func createPSBT(
        for groupId: String,
        to address: String,
        amount: UInt64,
        purpose: TransactionPurpose,
        notes: String? = nil
    ) async throws -> GroupPSBT {
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Get group and validate permissions
            guard let group = groupManager.activeGroups.first(where: { $0.id == groupId }) else {
                throw PSBTError.groupNotFound
            }
            
            // Validate that current user can create transactions
            guard let currentMember = group.getMember(byId: currentUserId),
                  currentMember.role.canCreateTransactions else {
                throw PSBTError.insufficientPermissions
            }
            
            // Create multisig wallet for this group
            let walletMembers = group.members.map { member in
                WalletMember(
                    id: member.id,
                    displayName: member.displayName,
                    nostrPubkey: member.nostrPubkey,
                    xpub: member.xpub,
                    isActive: member.isActive
                )
            }
            
            let multisigWallet = MultisigWallet(
                groupId: groupId,
                threshold: group.multisigConfig.threshold,
                members: walletMembers
            )
            
            // Create the PSBT
            let psbtBase64 = try await multisigWallet.createTransaction(
                to: address,
                amount: amount,
                feeRate: 1 // TODO: Dynamic fee estimation
            )
            
            // Create GroupPSBT object
            let groupPSBT = GroupPSBT(
                id: UUID().uuidString,
                groupId: groupId,
                psbtData: psbtBase64,
                recipientAddress: address,
                amount: amount,
                purpose: purpose,
                createdBy: currentUserId,
                notes: notes,
                requiredSignatures: group.multisigConfig.threshold,
                signatures: [:]
            )
            
            // Store encrypted PSBT
            try await storePSBT(groupPSBT)
            
            // Broadcast PSBT to group members via Nostr
            try await broadcastPSBTRequest(groupPSBT, to: group)
            
            await MainActor.run {
                self.activePSBTs.append(groupPSBT)
                self.isLoading = false
            }
            
            return groupPSBT
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - PSBT Signing
    
    func signPSBT(_ psbtId: String) async throws -> Bool {
        guard let psbtIndex = activePSBTs.firstIndex(where: { $0.id == psbtId }) else {
            throw PSBTError.psbtNotFound
        }
        
        let psbt = activePSBTs[psbtIndex]
        
        // Check if user already signed
        if psbt.signatures[currentUserId] != nil {
            throw PSBTError.alreadySigned
        }
        
        do {
            // Get user's private key from keychain
            _ = try keychainManager.retrieveNostrPrivateKey(for: currentUserId)
            
            // Create multisig wallet for signing
            guard let group = groupManager.activeGroups.first(where: { $0.id == psbt.groupId }) else {
                throw PSBTError.groupNotFound
            }
            
            let walletMembers = group.members.map { member in
                WalletMember(
                    id: member.id,
                    displayName: member.displayName,
                    nostrPubkey: member.nostrPubkey,
                    xpub: member.xpub,
                    isActive: member.isActive
                )
            }
            
            let multisigWallet = MultisigWallet(
                groupId: psbt.groupId,
                threshold: group.multisigConfig.threshold,
                members: walletMembers
            )
            
            // Sign the PSBT
            let signedPSBT = try await multisigWallet.signPSBT(psbt.psbtData, userId: currentUserId)
            
            // Create signature record
            let signature = PSBTSignature(
                signerId: currentUserId,
                signerName: group.getMember(byId: currentUserId)?.displayName ?? "Unknown",
                signedAt: Date(),
                partialPSBT: signedPSBT
            )
            
            // Update PSBT with signature
            activePSBTs[psbtIndex].addSignature(signature)
            
            // Store updated PSBT
            try await storePSBT(activePSBTs[psbtIndex])
            
            // Broadcast signature to group
            try await broadcastPSBTSignature(psbt, signature: signature, to: group)
            
            // Check if PSBT is fully signed
            let isFullySigned = activePSBTs[psbtIndex].isFullySigned
            
            if isFullySigned {
                // Combine all signatures and prepare for broadcast
                try await finalizePSBT(psbtId)
            }
            
            return isFullySigned
            
        } catch {
            throw PSBTError.signingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - PSBT Finalization
    
    private func finalizePSBT(_ psbtId: String) async throws {
        guard let psbtIndex = activePSBTs.firstIndex(where: { $0.id == psbtId }) else {
            throw PSBTError.psbtNotFound
        }
        
        let psbt = activePSBTs[psbtIndex]
        
        guard psbt.isFullySigned else {
            throw PSBTError.insufficientSignatures
        }
        
        do {
            // Combine all partial PSBTs
            let partialPSBTs = Array(psbt.signatures.values.map { $0.partialPSBT })
            
            guard let group = groupManager.activeGroups.first(where: { $0.id == psbt.groupId }) else {
                throw PSBTError.groupNotFound
            }
            
            let walletMembers = group.members.map { member in
                WalletMember(
                    id: member.id,
                    displayName: member.displayName,
                    nostrPubkey: member.nostrPubkey,
                    xpub: member.xpub,
                    isActive: member.isActive
                )
            }
            
            let multisigWallet = MultisigWallet(
                groupId: psbt.groupId,
                threshold: group.multisigConfig.threshold,
                members: walletMembers
            )
            
            // Combine PSBTs
            let finalPSBT = try multisigWallet.combinePSBTs(partialPSBTs)
            
            // Broadcast transaction
            let txid = try await multisigWallet.broadcastTransaction(finalPSBT)
            
            // Update PSBT status
            activePSBTs[psbtIndex].status = .broadcasted
            activePSBTs[psbtIndex].transactionId = txid
            activePSBTs[psbtIndex].finalizedAt = Date()
            
            // Store updated PSBT
            try await storePSBT(activePSBTs[psbtIndex])
            
            // Notify group members of successful transaction
            try await broadcastTransactionSuccess(psbt, txid: txid, to: group)
            
        } catch {
            activePSBTs[psbtIndex].status = .failed
            activePSBTs[psbtIndex].errorMessage = error.localizedDescription
            try await storePSBT(activePSBTs[psbtIndex])
            throw error
        }
    }
    
    // MARK: - PSBT Management
    
    func loadActivePSBTs() {
        Task {
            do {
                let psbts = try await loadPSBTsFromStorage()
                
                await MainActor.run {
                    self.activePSBTs = psbts
                    self.updatePendingSignatures()
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func loadPSBTsFromStorage() async throws -> [GroupPSBT] {
        let context = coreDataManager.viewContext
        
        // Get all PSBT data for groups the user is in
        let groupIds = groupManager.activeGroups.map { $0.id }
        var psbts: [GroupPSBT] = []
        
        for groupId in groupIds {
            do {
                // Load encrypted PSBT data
                let encryptedPSBTs = try EncryptedGroupData.fetchGroupData(groupId: groupId, context: context)
                    .filter { $0.dataType == "psbt" }
                
                for _ in encryptedPSBTs {
                    // For MVP: Skip decryption
                    let psbt = GroupPSBT(
                        id: "sample_psbt",
                        groupId: groupId,
                        psbtData: "sample_data",
                        recipientAddress: "sample_address",
                        amount: 10000,
                        purpose: .goalWithdrawal,
                        createdBy: "sample_user",
                        notes: "Sample notes",
                        requiredSignatures: 2,
                        signatures: [:]
                    )
                    psbts.append(psbt)
                }
            } catch {
                print("Failed to load PSBTs for group \(groupId): \(error)")
            }
        }
        
        return psbts.sorted { $0.createdAt > $1.createdAt }
    }
    
    private func storePSBT(_ psbt: GroupPSBT) async throws {
        let context = coreDataManager.viewContext
        
        // Encrypt and store PSBT
        let encryptedData = try encryptionManager.encryptGroupSharedData(
            psbt,
            groupId: psbt.groupId,
            context: .groupSharedData,
            identifier: psbt.id
        )
        
        // Store or update encrypted PSBT data
        let psbtData = EncryptedGroupData.fetchGroupData(
            groupId: psbt.groupId,
            dataType: "psbt",
            context: context
        ) ?? EncryptedGroupData()
        
        // For MVP: Skip Core Data storage
        print("Storing PSBT for group \(psbt.groupId)")
        
        psbtData.groupId = psbt.groupId
        psbtData.dataType = "psbt"
        psbtData.encryptedData = try JSONEncoder().encode(encryptedData)
        psbtData.lastModified = Date()
        psbtData.version = 1
        psbtData.createdBy = psbt.id // Use PSBT ID as identifier
        
        try context.save()
    }
    
    private func updatePendingSignatures() {
        pendingSignatures = activePSBTs.compactMap { psbt in
            // Only show PSBTs that need current user's signature
            guard psbt.status == .pendingSignatures,
                  psbt.signatures[currentUserId] == nil,
                  let group = groupManager.activeGroups.first(where: { $0.id == psbt.groupId }),
                  group.getMember(byId: currentUserId) != nil else {
                return nil
            }
            
            return PendingSignature(
                psbtId: psbt.id,
                groupName: group.displayName,
                amount: psbt.amount,
                recipientAddress: psbt.recipientAddress,
                purpose: psbt.purpose,
                createdAt: psbt.createdAt,
                urgency: psbt.calculateUrgency()
            )
        }.sorted { $0.urgency > $1.urgency }
    }
    
    // MARK: - Nostr Integration
    
    private func broadcastPSBTRequest(_ psbt: GroupPSBT, to group: SavingsGroup) async throws {
        let psbtEvent = PSBTRequestEvent(
            psbtId: psbt.id,
            groupId: psbt.groupId,
            recipientAddress: psbt.recipientAddress,
            amount: psbt.amount,
            purpose: psbt.purpose,
            notes: psbt.notes,
            requiredSignatures: psbt.requiredSignatures,
            createdBy: psbt.createdBy,
            psbtData: psbt.psbtData
        )
        
        let eventData = try JSONEncoder().encode(psbtEvent)
        let eventString = String(data: eventData, encoding: .utf8)!
        
        let nostrEvent = try NostrEvent.createCustomEvent(
            kind: 1003, // Custom: PSBT signing request
            content: eventString,
            privateKey: try keychainManager.retrieveNostrPrivateKey(for: currentUserId)
        )
        
        nostrClient.publishEvent(nostrEvent)
        
        // Send encrypted DMs to each group member
        for member in group.activeMembers where member.id != currentUserId {
            let dmContent = "New transaction requires your signature: \(psbt.amount.formattedSats) to \(psbt.recipientAddress)"
            try await nostrClient.publishEncryptedDM(dmContent, to: member.nostrPubkey)
        }
    }
    
    private func broadcastPSBTSignature(_ psbt: GroupPSBT, signature: PSBTSignature, to group: SavingsGroup) async throws {
        let signatureEvent = PSBTSignatureEvent(
            psbtId: psbt.id,
            groupId: psbt.groupId,
            signerId: signature.signerId,
            signerName: signature.signerName,
            signedAt: signature.signedAt,
            partialPSBT: signature.partialPSBT
        )
        
        let eventData = try JSONEncoder().encode(signatureEvent)
        let eventString = String(data: eventData, encoding: .utf8)!
        
        let nostrEvent = try NostrEvent.createCustomEvent(
            kind: 1004, // Custom: PSBT signature
            content: eventString,
            privateKey: try keychainManager.retrieveNostrPrivateKey(for: currentUserId)
        )
        
        nostrClient.publishEvent(nostrEvent)
    }
    
    private func broadcastTransactionSuccess(_ psbt: GroupPSBT, txid: String, to group: SavingsGroup) async throws {
        let successEvent = TransactionSuccessEvent(
            psbtId: psbt.id,
            groupId: psbt.groupId,
            transactionId: txid,
            amount: psbt.amount,
            recipientAddress: psbt.recipientAddress,
            purpose: psbt.purpose,
            finalizedAt: Date()
        )
        
        let eventData = try JSONEncoder().encode(successEvent)
        let eventString = String(data: eventData, encoding: .utf8)!
        
        let nostrEvent = try NostrEvent.createCustomEvent(
            kind: 1005, // Custom: Transaction success
            content: eventString,
            privateKey: try keychainManager.retrieveNostrPrivateKey(for: currentUserId)
        )
        
        nostrClient.publishEvent(nostrEvent)
        
        // Send celebration DMs to group members
        for member in group.activeMembers {
            let dmContent = "🎉 Transaction successful! \(psbt.amount.formattedSats) sent to \(psbt.recipientAddress). TXID: \(txid)"
            try await nostrClient.publishEncryptedDM(dmContent, to: member.nostrPubkey)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handlePSBTSigningRequest(_ notification: Notification) {
        guard let event = notification.object as? NostrEvent else { return }
        
        Task {
            do {
                let psbtRequest = try JSONDecoder().decode(PSBTRequestEvent.self, from: event.content.data(using: .utf8)!)
                
                // Create GroupPSBT from received event
                let groupPSBT = GroupPSBT(
                    id: psbtRequest.psbtId,
                    groupId: psbtRequest.groupId,
                    psbtData: psbtRequest.psbtData,
                    recipientAddress: psbtRequest.recipientAddress,
                    amount: psbtRequest.amount,
                    purpose: psbtRequest.purpose,
                    createdBy: psbtRequest.createdBy,
                    notes: psbtRequest.notes,
                    requiredSignatures: psbtRequest.requiredSignatures,
                    signatures: [:]
                )
                
                await MainActor.run {
                    if !self.activePSBTs.contains(where: { $0.id == groupPSBT.id }) {
                        self.activePSBTs.append(groupPSBT)
                        self.updatePendingSignatures()
                    }
                }
                
                // Store the PSBT
                try await storePSBT(groupPSBT)
                
                // Show notification to user
                await showSigningNotification(for: groupPSBT)
                
            } catch {
                print("Failed to process PSBT signing request: \(error)")
            }
        }
    }
    
    private func handlePSBTUpdate(_ notification: Notification) {
        guard let event = notification.object as? NostrEvent else { return }
        
        Task {
            do {
                // Handle different types of PSBT updates
                switch event.kind {
                case 1004: // PSBT signature
                    let signatureEvent = try JSONDecoder().decode(PSBTSignatureEvent.self, from: event.content.data(using: .utf8)!)
                    await processPSBTSignature(signatureEvent)
                    
                case 1005: // Transaction success
                    let successEvent = try JSONDecoder().decode(TransactionSuccessEvent.self, from: event.content.data(using: .utf8)!)
                    await processTransactionSuccess(successEvent)
                    
                default:
                    break
                }
            } catch {
                print("Failed to process PSBT update: \(error)")
            }
        }
    }
    
    private func processPSBTSignature(_ event: PSBTSignatureEvent) async {
        guard let psbtIndex = activePSBTs.firstIndex(where: { $0.id == event.psbtId }) else {
            return
        }
        
        let signature = PSBTSignature(
            signerId: event.signerId,
            signerName: event.signerName,
            signedAt: event.signedAt,
            partialPSBT: event.partialPSBT
        )
        
        activePSBTs[psbtIndex].addSignature(signature)
        
        // Store updated PSBT
        do {
            try await storePSBT(activePSBTs[psbtIndex])
        } catch {
            print("Failed to store updated PSBT: \(error)")
        }
        
        await MainActor.run {
            self.updatePendingSignatures()
        }
    }
    
    private func processTransactionSuccess(_ event: TransactionSuccessEvent) async {
        guard let psbtIndex = activePSBTs.firstIndex(where: { $0.id == event.psbtId }) else {
            return
        }
        
        activePSBTs[psbtIndex].status = .broadcasted
        activePSBTs[psbtIndex].transactionId = event.transactionId
        activePSBTs[psbtIndex].finalizedAt = event.finalizedAt
        
        // Store updated PSBT
        do {
            try await storePSBT(activePSBTs[psbtIndex])
        } catch {
            print("Failed to store finalized PSBT: \(error)")
        }
        
        await MainActor.run {
            self.updatePendingSignatures()
        }
    }
    
    private func showSigningNotification(for psbt: GroupPSBT) async {
        // Show local notification for PSBT signing request
        let content = UNMutableNotificationContent()
        content.title = "🔐 Signature Required"
        content.body = "New transaction needs your approval: \(psbt.amount.formattedSats)"
        content.sound = .default
        content.userInfo = ["psbtId": psbt.id]
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try? await UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Private Methods
    
    private func broadcastTransactionUpdate(_ psbt: GroupPSBT) async {
        // Notify group members about transaction completion
        print("Broadcasting transaction update for PSBT: \(psbt.id)")
        // This would send Nostr events to group members in production
    }
}

// MARK: - Data Models

struct GroupPSBT: Identifiable, Codable {
    let id: String
    let groupId: String
    let psbtData: String
    let recipientAddress: String
    let amount: UInt64
    let purpose: TransactionPurpose
    let createdBy: String
    let notes: String?
    let requiredSignatures: Int
    var signatures: [String: PSBTSignature]
    var status: PSBTStatus
    var transactionId: String?
    var finalizedAt: Date?
    var errorMessage: String?
    let createdAt: Date
    
    init(
        id: String,
        groupId: String,
        psbtData: String,
        recipientAddress: String,
        amount: UInt64,
        purpose: TransactionPurpose,
        createdBy: String,
        notes: String?,
        requiredSignatures: Int,
        signatures: [String: PSBTSignature]
    ) {
        self.id = id
        self.groupId = groupId
        self.psbtData = psbtData
        self.recipientAddress = recipientAddress
        self.amount = amount
        self.purpose = purpose
        self.createdBy = createdBy
        self.notes = notes
        self.requiredSignatures = requiredSignatures
        self.signatures = signatures
        self.status = .pendingSignatures
        self.createdAt = Date()
    }
    
    var isFullySigned: Bool {
        return signatures.count >= requiredSignatures
    }
    
    var signatureProgress: Double {
        return Double(signatures.count) / Double(requiredSignatures)
    }
    
    mutating func addSignature(_ signature: PSBTSignature) {
        signatures[signature.signerId] = signature
        if isFullySigned {
            status = .readyToBroadcast
        }
    }
    
    func calculateUrgency() -> Int {
        let hoursOld = Date().timeIntervalSince(createdAt) / 3600
        let urgencyFromAge = max(0, 24 - Int(hoursOld)) // More urgent as it gets older
        let urgencyFromPurpose = purpose.urgencyScore
        return urgencyFromAge + urgencyFromPurpose
    }
    
    // Computed property for PSBTSigningView compatibility
    var destinationAddress: String? {
        return recipientAddress
    }
    
    // Sample data for development
    static let samplePSBT = GroupPSBT(
        id: "psbt_12345",
        groupId: "group_vacation",
        psbtData: "cHNidP8BAHECAAAAATx0W...", // Mock PSBT data
        recipientAddress: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        amount: 5000000, // 0.05 BTC
        purpose: .goalWithdrawal,
        createdBy: "Alice",
        notes: "Withdrawal for vacation expenses after reaching our goal!",
        requiredSignatures: 2,
        signatures: [
            "alice_id": PSBTSignature(
                signerId: "alice_id",
                signerName: "Alice",
                signedAt: Date().addingTimeInterval(-1800), // 30 min ago
                partialPSBT: "cHNidP8BAHECAAAAATx0W..."
            )
        ]
    )
}

struct PSBTSignature: Codable {
    let signerId: String
    let signerName: String
    let signedAt: Date
    let partialPSBT: String
}

struct PendingSignature: Identifiable {
    let id = UUID()
    let psbtId: String
    let groupName: String
    let amount: UInt64
    let recipientAddress: String
    let purpose: TransactionPurpose
    let createdAt: Date
    let urgency: Int
}

enum PSBTStatus: String, Codable {
    case pendingSignatures = "pending_signatures"
    case readyToBroadcast = "ready_to_broadcast"
    case broadcasted = "broadcasted"
    case confirmed = "confirmed"
    case failed = "failed"
    case cancelled = "cancelled"
}

// PSBTError enum is defined below with complete error cases

enum TransactionPurpose: String, Codable, CaseIterable {
    case goalWithdrawal = "goal_withdrawal"
    case emergencyWithdrawal = "emergency_withdrawal"
    case partialWithdrawal = "partial_withdrawal"
    case rebalancing = "rebalancing"
    case testing = "testing"
    
    var displayName: String {
        switch self {
        case .goalWithdrawal: return "Goal Reached - Withdrawal"
        case .emergencyWithdrawal: return "Emergency Withdrawal"
        case .partialWithdrawal: return "Partial Withdrawal"
        case .rebalancing: return "Wallet Rebalancing"
        case .testing: return "Test Transaction"
        }
    }
    
    var urgencyScore: Int {
        switch self {
        case .emergencyWithdrawal: return 20
        case .goalWithdrawal: return 15
        case .partialWithdrawal: return 10
        case .rebalancing: return 5
        case .testing: return 1
        }
    }
    
    var icon: String {
        switch self {
        case .goalWithdrawal: return "🎯"
        case .emergencyWithdrawal: return "🚨"
        case .partialWithdrawal: return "💰"
        case .rebalancing: return "⚖️"
        case .testing: return "🧪"
        }
    }
}

// MARK: - Nostr Event Models

struct PSBTRequestEvent: Codable {
    let psbtId: String
    let groupId: String
    let recipientAddress: String
    let amount: UInt64
    let purpose: TransactionPurpose
    let notes: String?
    let requiredSignatures: Int
    let createdBy: String
    let psbtData: String
}

struct PSBTSignatureEvent: Codable {
    let psbtId: String
    let groupId: String
    let signerId: String
    let signerName: String
    let signedAt: Date
    let partialPSBT: String
}

struct TransactionSuccessEvent: Codable {
    let psbtId: String
    let groupId: String
    let transactionId: String
    let amount: UInt64
    let recipientAddress: String
    let purpose: TransactionPurpose
    let finalizedAt: Date
}

// MARK: - Error Types

enum PSBTError: Error, LocalizedError {
    case groupNotFound
    case psbtNotFound
    case insufficientPermissions
    case alreadySigned
    case insufficientSignatures
    case signingFailed(String)
    case broadcastFailed(String)
    case invalidPSBT
    
    var errorDescription: String? {
        switch self {
        case .groupNotFound:
            return "Group not found"
        case .psbtNotFound:
            return "Transaction not found"
        case .insufficientPermissions:
            return "You don't have permission to create transactions"
        case .alreadySigned:
            return "You have already signed this transaction"
        case .insufficientSignatures:
            return "Not enough signatures to finalize transaction"
        case .signingFailed(let message):
            return "Failed to sign transaction: \(message)"
        case .broadcastFailed(let message):
            return "Failed to broadcast transaction: \(message)"
        case .invalidPSBT:
            return "Invalid transaction data"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let psbtUpdateReceived = Notification.Name("psbtUpdateReceived")
}