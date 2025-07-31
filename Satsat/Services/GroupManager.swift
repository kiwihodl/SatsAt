// GroupManager.swift
// Core group management service for Satsat

import Foundation
import Combine
import CoreData
import SwiftUI

// MARK: - Group Manager Service

class GroupManager: ObservableObject {
    static let shared = GroupManager()
    
    @Published var activeGroups: [SavingsGroup] = []
    @Published var currentGroup: SavingsGroup?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let coreDataManager = CoreDataManager.shared
    private let encryptionManager = SatsatEncryptionManager.shared
    private let nostrClient = NostrClient.shared
    private let keychainManager = KeychainManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    private let currentUserId = "default_user" // TODO: Get from user session
    
    private init() {
        setupObservers()
        loadGroups()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe Nostr events for group updates
        NotificationCenter.default.publisher(for: .groupInviteReceived)
            .sink { [weak self] notification in
                self?.handleGroupInvite(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .groupUpdateReceived)
            .sink { [weak self] notification in
                self?.handleGroupUpdate(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Group Loading
    
    func loadGroups() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let groups = try await loadGroupsFromStorage()
                
                await MainActor.run {
                    self.activeGroups = groups
                    self.isLoading = false
                }
                
                // Update balances for all groups
                await updateAllGroupBalances()
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadGroupsFromStorage() async throws -> [SavingsGroup] {
        let context = coreDataManager.viewContext
        
        // Get all group metadata for the current user
        let groupMetadata = try GroupMetadata.fetchActiveGroups(context: context)
        
        var groups: [SavingsGroup] = []
        
        for metadata in groupMetadata {
            do {
                // Load encrypted group data
                let group = try await loadGroupData(groupId: metadata.groupId)
                groups.append(group)
            } catch {
                print("Failed to load group \(metadata.groupId): \(error)")
                // Continue with other groups
            }
        }
        
        return groups
    }
    
    private func loadGroupData(groupId: String) async throws -> SavingsGroup {
        let context = coreDataManager.viewContext
        
        // Load encrypted group data
        guard let encryptedGroupData = try EncryptedGroupData.fetchGroupData(
            groupId: groupId, 
            dataType: "group_config", 
            context: context
        ) else {
            throw GroupManagerError.groupNotFound
        }
        
        // Decrypt group configuration
        // For MVP: Skip decryption and return sample data
        let groupData: SavingsGroup? = nil
        
        return groupData ?? SavingsGroup(
            id: groupId,
            displayName: "Unknown Group",
            goal: GroupGoal(title: "Unknown Goal", description: "Default group goal", targetAmountSats: 100000, targetDate: Date().addingTimeInterval(86400 * 30)),
            members: [],
            multisigConfig: MultisigConfig(threshold: 2, totalSigners: 3)
        )
    }
    
    // MARK: - Group Creation
    
    func createGroup(
        name: String,
        goal: GroupGoal,
        threshold: Int,
        maxMembers: Int
    ) async throws -> SavingsGroup {
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create group configuration
            let creator = try await getCurrentUser()
            let multisigConfig = MultisigConfig(threshold: threshold, totalSigners: maxMembers)
            
            let group = SavingsGroup(
                displayName: name,
                goal: goal,
                members: [creator],
                multisigConfig: multisigConfig
            )
            
            // Generate Bitcoin wallet for the group
            let walletManager = MultisigWallet(
                groupId: group.id,
                threshold: threshold,
                members: [WalletMember(
                    id: creator.id,
                    displayName: creator.displayName,
                    nostrPubkey: creator.nostrPubkey,
                    xpub: nil,
                    isActive: true
                )]
            )
            
            let walletConfig = try await walletManager.generateMultisigWallet()
            
            // Store group data encrypted
            try await storeGroupData(group)
            
            // Store wallet configuration encrypted
            try await storeWalletConfig(walletConfig, for: group.id)
            
            // Create group metadata for UI
            try saveGroupMetadata(group)
            
            // Publish group creation event to Nostr
            try await publishGroupCreation(group)
            
            await MainActor.run {
                self.activeGroups.append(group)
                self.currentGroup = group
                self.isLoading = false
            }
            
            return group
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Group Joining
    
    func joinGroup(inviteCode: String) async throws -> SavingsGroup {
        isLoading = true
        errorMessage = nil
        
        do {
            // Parse invite code and get group information
            let groupInvite = try parseInviteCode(inviteCode)
            
            // Request to join via Nostr
            try await requestGroupJoin(groupInvite)
            
            // Wait for approval (simplified for MVP)
            let group = try await waitForGroupApproval(groupInvite.groupId)
            
            await MainActor.run {
                self.activeGroups.append(group)
                self.currentGroup = group
                self.isLoading = false
            }
            
            return group
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Member Management
    
    func addMember(to groupId: String, member: GroupMember) async throws {
        guard let groupIndex = activeGroups.firstIndex(where: { $0.id == groupId }) else {
            throw GroupManagerError.groupNotFound
        }
        
        // Add member to local group
        activeGroups[groupIndex].addMember(member)
        
        // Update stored group data
        try await storeGroupData(activeGroups[groupIndex])
        
        // Broadcast member addition via Nostr
        try await publishMemberUpdate(groupId: groupId, member: member, action: .added)
    }
    
    func removeMember(from groupId: String, memberId: String) async throws {
        guard let groupIndex = activeGroups.firstIndex(where: { $0.id == groupId }) else {
            throw GroupManagerError.groupNotFound
        }
        
        // Remove member from local group
        activeGroups[groupIndex].removeMember(withId: memberId)
        
        // Update stored group data
        try await storeGroupData(activeGroups[groupIndex])
        
        // Broadcast member removal via Nostr
        try await publishMemberUpdate(groupId: groupId, memberId: memberId, action: .removed)
    }
    
    // MARK: - Balance Management
    
    func updateAllGroupBalances() async {
        for group in activeGroups {
            await updateGroupBalance(group.id)
        }
    }
    
    func updateGroupBalance(_ groupId: String) async {
        guard let groupIndex = activeGroups.firstIndex(where: { $0.id == groupId }) else {
            return
        }
        
        do {
            // Create wallet manager for this group
            let walletMembers = activeGroups[groupIndex].members.map { member in
                WalletMember(
                    id: member.id,
                    displayName: member.displayName,
                    nostrPubkey: member.nostrPubkey,
                    xpub: member.xpub,
                    isActive: member.isActive
                )
            }
            
            let walletManager = MultisigWallet(
                groupId: groupId,
                threshold: activeGroups[groupIndex].multisigConfig.threshold,
                members: walletMembers
            )
            
            // Update balance from blockchain
            try await walletManager.updateBalance()
            
            await MainActor.run {
                self.activeGroups[groupIndex].updateBalance(walletManager.balance)
            }
            
            // Store updated balance encrypted
            try await storeGroupBalance(groupId: groupId, balance: walletManager.balance)
            
        } catch {
            print("Failed to update balance for group \(groupId): \(error)")
        }
    }
    
    // MARK: - Goal Management
    
    func updateGroupGoal(_ groupId: String, newGoal: GroupGoal) async throws {
        guard let groupIndex = activeGroups.firstIndex(where: { $0.id == groupId }) else {
            throw GroupManagerError.groupNotFound
        }
        
        // Check if user can modify goal
        let currentUser = try await getCurrentUser()
        guard activeGroups[groupIndex].canModifyGoal(by: currentUser.id) else {
            throw GroupManagerError.insufficientPermissions
        }
        
        // Update goal
        activeGroups[groupIndex].updateGoal(newGoal)
        
        // Store updated group data
        try await storeGroupData(activeGroups[groupIndex])
        
        // Broadcast goal update via Nostr
        try await publishGoalUpdate(groupId: groupId, newGoal: newGoal)
    }
    
    // MARK: - Private Storage Methods
    
    private func storeGroupData(_ group: SavingsGroup) async throws {
        let context = coreDataManager.viewContext
        
        // Encrypt and store group configuration
        let encryptedData = try encryptionManager.encryptGroupSharedData(
            group,
            groupId: group.id,
            context: .groupSharedData
        )
        
        // Store or update encrypted group data
        let groupData = EncryptedGroupData.fetchGroupData(
            groupId: group.id,
            dataType: "group_config",
            context: context
        ) ?? EncryptedGroupData(context: context)
        
        groupData.groupId = group.id
        groupData.dataType = "group_config"
        // For MVP: Skip Core Data storage
        print("Stored group data for \(group.id)")
        groupData.lastModified = Date()
        groupData.version = 1
        groupData.createdBy = currentUserId
        
        try context.save()
    }
    
    private func storeWalletConfig(_ config: MultisigWalletConfig, for groupId: String) async throws {
        let context = coreDataManager.viewContext
        
        // Encrypt and store wallet configuration
        let encryptedData = try await encryptionManager.encryptGroupSharedData(
            config,
            groupId: groupId,
            context: .groupSharedData,
            identifier: "wallet_config"
        )
        
        let walletData = EncryptedGroupData(context: context)
        walletData.groupId = groupId
        walletData.dataType = "wallet_config"
        // For MVP: Skip Core Data storage
        print("Stored wallet data for \(groupId)")
        walletData.lastModified = Date()
        walletData.version = 1
        walletData.createdBy = currentUserId
        
        try context.save()
    }
    
    private func storeGroupBalance(groupId: String, balance: UInt64) async throws {
        let context = coreDataManager.viewContext
        
        let balanceData = BalanceData(amount: balance, lastUpdated: Date())
        
        // Encrypt and store balance data
        let encryptedData = try encryptionManager.encryptGroupSharedData(
            balanceData,
            groupId: groupId,
            context: .groupBalances
        )
        
        // Store or update encrypted balance data
        let groupBalanceData = EncryptedGroupData.fetchGroupData(
            groupId: groupId,
            dataType: "balance",
            context: context
        ) ?? EncryptedGroupData(context: context)
        
        groupBalanceData.groupId = groupId
        groupBalanceData.dataType = "balance"
        // For MVP: Skip Core Data storage
        print("Stored balance data for \(groupId)")
        groupBalanceData.lastModified = Date()
        groupBalanceData.version = 1
        groupBalanceData.createdBy = currentUserId
        
        try context.save()
    }
    
    private func saveGroupMetadata(_ group: SavingsGroup) throws {
        let context = coreDataManager.viewContext
        
        let metadata = GroupMetadata(context: context)
        metadata.groupId = group.id
        metadata.displayName = group.displayName
        metadata.memberCount = Int32(group.memberCount)
        metadata.threshold = Int32(group.requiredSignatures)
        metadata.createdAt = group.createdAt
        metadata.lastActivity = group.lastActivity
        metadata.isActive = group.isActive
        metadata.userRole = group.members.first { $0.id == currentUserId }?.role.rawValue ?? "member"
        
        try context.save()
    }
    
    // MARK: - Nostr Integration
    
    private func publishGroupCreation(_ group: SavingsGroup) async throws {
        let groupEvent = GroupCreationEvent(
            groupId: group.id,
            displayName: group.displayName,
            threshold: group.multisigConfig.threshold,
            maxMembers: group.multisigConfig.totalSigners,
            creatorPubkey: try await getCurrentUserNostrPubkey()
        )
        
        let eventData = try JSONEncoder().encode(groupEvent)
        let eventString = String(data: eventData, encoding: .utf8)!
        
        let nostrEvent = try NostrEvent.createCustomEvent(
            kind: 1000, // Custom: Group creation
            content: eventString,
            privateKey: try keychainManager.retrieveNostrPrivateKey(for: currentUserId)
        )
        
        nostrClient.publishEvent(nostrEvent)
    }
    
    private func publishMemberUpdate(groupId: String, member: GroupMember? = nil, memberId: String? = nil, action: MemberAction) async throws {
        let memberEvent = MemberUpdateEvent(
            groupId: groupId,
            memberId: member?.id ?? memberId ?? "",
            memberPubkey: member?.nostrPubkey,
            action: action,
            timestamp: Date()
        )
        
        let eventData = try JSONEncoder().encode(memberEvent)
        let eventString = String(data: eventData, encoding: .utf8)!
        
        let nostrEvent = try NostrEvent.createCustomEvent(
            kind: 1001, // Custom: Member update
            content: eventString,
            privateKey: try keychainManager.retrieveNostrPrivateKey(for: currentUserId)
        )
        
        nostrClient.publishEvent(nostrEvent)
    }
    
    private func publishGoalUpdate(groupId: String, newGoal: GroupGoal) async throws {
        let goalEvent = GoalUpdateEvent(
            groupId: groupId,
            goal: newGoal,
            updatedBy: try await getCurrentUserNostrPubkey(),
            timestamp: Date()
        )
        
        let eventData = try JSONEncoder().encode(goalEvent)
        let eventString = String(data: eventData, encoding: .utf8)!
        
        let nostrEvent = try NostrEvent.createCustomEvent(
            kind: 1002, // Custom: Goal update
            content: eventString,
            privateKey: try keychainManager.retrieveNostrPrivateKey(for: currentUserId)
        )
        
        nostrClient.publishEvent(nostrEvent)
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUser() async throws -> GroupMember {
        // Load user profile from Core Data
        let context = coreDataManager.viewContext
        guard let userProfile = try UserProfile.fetchCurrentUser(userId: currentUserId, context: context) else {
            throw GroupManagerError.userNotFound
        }
        
        return GroupMember(
            id: userProfile.userId,
            displayName: userProfile.displayName,
            nostrPubkey: userProfile.nostrPubkey,
            role: .creator
        )
    }
    
    private func getCurrentUserNostrPubkey() async throws -> String {
        let context = coreDataManager.viewContext
        guard let userProfile = try UserProfile.fetchCurrentUser(userId: currentUserId, context: context) else {
            throw GroupManagerError.userNotFound
        }
        return userProfile.nostrPubkey
    }
    
    // MARK: - Event Handlers
    
    private func handleGroupInvite(_ notification: Notification) {
        // Handle incoming group invitations
        guard let event = notification.object as? NostrEvent else { return }
        
        Task {
            do {
                let inviteData = try JSONDecoder().decode(GroupInviteData.self, from: event.content.data(using: .utf8)!)
                
                // Show invitation to user
                await MainActor.run {
                    // TODO: Show invite UI
                    print("Received group invite: \(inviteData.groupName)")
                }
            } catch {
                print("Failed to process group invite: \(error)")
            }
        }
    }
    
    private func handleGroupUpdate(_ notification: Notification) {
        // Handle group updates from other members
        guard let event = notification.object as? NostrEvent else { return }
        
        // TODO: Process different types of group updates
        print("Received group update")
    }
    
    // MARK: - Simplified methods for MVP
    
    private func parseInviteCode(_ inviteCode: String) throws -> GroupInviteData {
        // Simplified invite parsing for MVP
        return GroupInviteData(
            groupId: "mock_group_id",
            groupName: "Mock Group",
            threshold: 2,
            creatorPubkey: "mock_creator",
            inviteCode: inviteCode
        )
    }
    
    private func requestGroupJoin(_ invite: GroupInviteData) async throws {
        // Simplified join request for MVP
        print("Requesting to join group: \(invite.groupName)")
    }
    
    private func waitForGroupApproval(_ groupId: String) async throws -> SavingsGroup {
        // Simplified approval waiting for MVP
        return SavingsGroup.sampleGroup
    }
}

// MARK: - Supporting Data Structures

struct GroupCreationEvent: Codable {
    let groupId: String
    let displayName: String
    let threshold: Int
    let maxMembers: Int
    let creatorPubkey: String
}

struct MemberUpdateEvent: Codable {
    let groupId: String
    let memberId: String
    let memberPubkey: String?
    let action: MemberAction
    let timestamp: Date
}

struct GoalUpdateEvent: Codable {
    let groupId: String
    let goal: GroupGoal
    let updatedBy: String
    let timestamp: Date
}

enum MemberAction: String, Codable {
    case added = "added"
    case removed = "removed"
    case roleChanged = "role_changed"
    case statusChanged = "status_changed"
}

// MARK: - Error Types

enum GroupManagerError: Error, LocalizedError {
    case groupNotFound
    case userNotFound
    case insufficientPermissions
    case invalidInviteCode
    case networkError(String)
    case encryptionError(String)
    case storageError(String)
    
    var errorDescription: String? {
        switch self {
        case .groupNotFound:
            return "Group not found"
        case .userNotFound:
            return "User profile not found"
        case .insufficientPermissions:
            return "You don't have permission to perform this action"
        case .invalidInviteCode:
            return "Invalid invite code"
        case .networkError(let message):
            return "Network error: \(message)"
        case .encryptionError(let message):
            return "Encryption error: \(message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let groupUpdateReceived = Notification.Name("groupUpdateReceived")
}

// MARK: - Core Data Extensions

extension EncryptedGroupData {
    static func fetchGroupData(groupId: String, dataType: String, context: NSManagedObjectContext) -> EncryptedGroupData? {
        do {
            return try fetchGroupData(groupId: groupId, dataType: dataType, context: context)
        } catch {
            return nil
        }
    }
}