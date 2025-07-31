// MessageManager.swift
// Message management service for Satsat group messaging

import Foundation
import Combine
import CoreData
import SwiftUI
import CryptoKit

// MARK: - Message Manager Service

class MessageManager: ObservableObject {
    static let shared = MessageManager()
    
    @Published var groupMessages: [String: [GroupMessage]] = [:]
    @Published var unreadCounts: [String: Int] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let coreDataManager = CoreDataManager.shared
    private let encryptionManager = SatsatEncryptionManager.shared
    private let nostrClient = NostrClient.shared
    private let nip44Encryption = NIP44Encryption.shared
    private let keychainManager = KeychainManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    private let currentUserId = "default_user"
    private let maxMessagesPerGroup = 500
    
    private init() {
        setupMessageObservers()
    }
    
    // MARK: - Setup
    
    private func setupMessageObservers() {
        // Listen for new Nostr events that contain messages
        NotificationCenter.default.publisher(for: .nostrMessageReceived)
            .sink { [weak self] notification in
                self?.handleNostrMessage(notification)
            }
            .store(in: &cancellables)
        
        // Listen for group message events
        NotificationCenter.default.publisher(for: .groupMessageReceived)
            .sink { [weak self] notification in
                self?.handleGroupMessage(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Message Loading
    
    func loadMessages(for groupId: String) async {
        isLoading = true
        
        do {
            let messages = try await loadMessagesFromStorage(groupId: groupId)
            
            await MainActor.run {
                self.groupMessages[groupId] = messages
                self.unreadCounts[groupId] = 0 // Mark as read when loaded
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func loadMessagesFromStorage(groupId: String) async throws -> [GroupMessage] {
        let context = coreDataManager.viewContext
        
        // Get encrypted message data for this group
        let encryptedMessages = try EncryptedUserData.fetchUserData(
            userId: currentUserId,
            dataType: "group_messages",
            context: context
        ).filter { 
            $0.groupId == groupId 
        }
        
        var messages: [GroupMessage] = []
        
        for encryptedMessage in encryptedMessages {
            do {
                let encryptedDataStruct = try JSONDecoder().decode(EncryptedData.self, from: encryptedMessage.encryptedData)
                let message: GroupMessage = try encryptionManager.decryptUserPrivateData(
                    encryptedDataStruct,
                    type: GroupMessage.self,
                    context: .userMessages,
                    identifier: encryptedMessage.identifier
                )
                messages.append(message)
            } catch {
                print("Failed to decrypt message \(encryptedMessage.identifier): \(error)")
            }
        }
        
        return messages.sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Message Sending
    
    func sendMessage(_ content: String, to groupId: String, messageType: MessageType = .text) async throws {
        // Get group shared key for encryption
        guard let groupSharedKey = try? await getGroupSharedKey(for: groupId) else {
            throw MessageError.groupKeyNotFound
        }
        
        // Create message
        let message = GroupMessage(
            id: UUID().uuidString,
            groupId: groupId,
            senderId: currentUserId,
            senderName: try await getCurrentUserDisplayName(),
            content: content,
            messageType: messageType,
            timestamp: Date()
        )
        
        // Encrypt message using NIP-44
        let encryptedContent = try nip44Encryption.encryptSatsatGroupMessage(
            content,
            groupId: groupId,
            groupSharedKey: groupSharedKey
        )
        
        // Store message locally (encrypted)
        try await storeMessage(message)
        
        // Broadcast via Nostr
        try await broadcastMessage(message, encryptedContent: encryptedContent)
        
        // Update local UI
        await MainActor.run {
            if self.groupMessages[groupId] == nil {
                self.groupMessages[groupId] = []
            }
            self.groupMessages[groupId]?.append(message)
        }
    }
    
    func sendSystemMessage(_ content: String, to groupId: String, systemType: SystemMessageType) async throws {
        let message = GroupMessage(
            id: UUID().uuidString,
            groupId: groupId,
            senderId: "system",
            senderName: "System",
            content: content,
            messageType: .system,
            timestamp: Date()
        )
        
        // Store locally
        try await storeMessage(message)
        
        // Update UI
        await MainActor.run {
            if self.groupMessages[groupId] == nil {
                self.groupMessages[groupId] = []
            }
            self.groupMessages[groupId]?.append(message)
        }
    }
    
    // MARK: - Message Reception
    
    private func handleNostrMessage(_ notification: Notification) {
        guard let event = notification.object as? NostrEvent else { return }
        
        Task {
            do {
                // Try to decrypt as a group message
                if let groupId = extractGroupId(from: event) {
                    try await processGroupMessage(event, groupId: groupId)
                }
            } catch {
                print("Failed to process Nostr message: \(error)")
            }
        }
    }
    
    private func handleGroupMessage(_ notification: Notification) {
        // Handle specific group message notifications
        if let userInfo = notification.userInfo,
           let groupId = userInfo["groupId"] as? String,
           let _ = userInfo["content"] as? String {
            
            Task {
                // Process the group message
                await updateUnreadCount(for: groupId)
            }
        }
    }
    
    private func processGroupMessage(_ event: NostrEvent, groupId: String) async throws {
        guard let groupSharedKey = try? await getGroupSharedKey(for: groupId) else {
            throw MessageError.groupKeyNotFound
        }
        
        // Decrypt the message
        let satsatMessage = try nip44Encryption.decryptSatsatGroupMessage(
            event.content,
            groupSharedKey: groupSharedKey
        )
        
        // Convert to GroupMessage
        let message = GroupMessage(
            id: event.id,
            groupId: groupId,
            senderId: event.pubkey,
            senderName: try await getSenderDisplayName(pubkey: event.pubkey),
            content: satsatMessage.content,
            messageType: .text,
            timestamp: Date(timeIntervalSince1970: TimeInterval(event.createdAt))
        )
        
        // Store message
        try await storeMessage(message)
        
        // Update UI if not from current user
        let currentUserPubkey = try await getCurrentUserPubkey()
        if event.pubkey != currentUserPubkey {
            await MainActor.run {
                if self.groupMessages[groupId] == nil {
                    self.groupMessages[groupId] = []
                }
                
                // Avoid duplicates
                if !self.groupMessages[groupId]!.contains(where: { $0.id == message.id }) {
                    self.groupMessages[groupId]?.append(message)
                    self.updateUnreadCount(for: groupId)
                }
            }
        }
    }
    
    // MARK: - Message Storage
    
    private func storeMessage(_ message: GroupMessage) async throws {
        let context = coreDataManager.viewContext
        
        // Encrypt message data
        let encryptedData = try encryptionManager.encryptUserPrivateData(
            message,
            context: .userMessages,
            identifier: message.id
        )
        
        // Store in Core Data
        let messageData = EncryptedUserData(context: context)
        messageData.userId = currentUserId
        messageData.dataType = "group_messages"
        messageData.identifier = message.id
        messageData.encryptedData = try JSONEncoder().encode(encryptedData)
        messageData.lastModified = Date()
        messageData.version = 1
        messageData.groupId = message.groupId
        
        try context.save()
        
        // Clean up old messages if we exceed the limit
        try await cleanupOldMessages(for: message.groupId)
    }
    
    private func cleanupOldMessages(for groupId: String) async throws {
        let context = coreDataManager.viewContext
        
        let messages = try EncryptedUserData.fetchUserData(
            userId: currentUserId,
            dataType: "group_messages",
            context: context
        ).filter { $0.groupId == groupId }
        
        if messages.count > maxMessagesPerGroup {
            // Sort by date and delete oldest
            let sortedMessages = messages.sorted { $0.lastModified < $1.lastModified }
            let messagesToDelete = sortedMessages.prefix(messages.count - maxMessagesPerGroup)
            
            for message in messagesToDelete {
                context.delete(message)
            }
            
            try context.save()
        }
    }
    
    // MARK: - Broadcasting
    
    private func broadcastMessage(_ message: GroupMessage, encryptedContent: String) async throws {
        // Create Nostr event for group message
        let messageEvent = GroupMessageEvent(
            groupId: message.groupId,
            messageId: message.id,
            encryptedContent: encryptedContent,
            messageType: message.messageType.rawValue,
            timestamp: message.timestamp
        )
        
        let eventData = try JSONEncoder().encode(messageEvent)
        let eventString = String(data: eventData, encoding: .utf8)!
        
        let nostrEvent = try NostrEvent.createCustomEvent(
            kind: 1006, // Custom: Group message
            content: eventString,
            privateKey: try keychainManager.retrieveNostrPrivateKey(for: currentUserId)
        )
        
        nostrClient.publishEvent(nostrEvent)
    }
    
    // MARK: - Utility Methods
    
    private func updateUnreadCount(for groupId: String) {
        if unreadCounts[groupId] == nil {
            unreadCounts[groupId] = 0
        }
        unreadCounts[groupId]! += 1
    }
    
    func markAsRead(groupId: String) {
        unreadCounts[groupId] = 0
    }
    
    private func extractGroupId(from event: NostrEvent) -> String? {
        // Look for group ID in tags
        for tag in event.tags {
            if tag.count >= 2 && tag[0] == "g" {
                return tag[1]
            }
        }
        return nil
    }
    
    private func getGroupSharedKey(for groupId: String) async throws -> String {
        // For MVP, derive from group ID
        // In production, this would be securely shared during group creation
        return "shared_key_for_group_\(groupId)".sha256Hash
    }
    
    private func getCurrentUserDisplayName() async throws -> String {
        let context = coreDataManager.viewContext
        if let userProfile = try UserProfile.fetchCurrentUser(userId: currentUserId, context: context) {
            return userProfile.displayName
        }
        return "Unknown User"
    }
    
    private func getCurrentUserPubkey() async throws -> String {
        let context = coreDataManager.viewContext
        if let userProfile = try UserProfile.fetchCurrentUser(userId: currentUserId, context: context) {
            return userProfile.nostrPubkey
        }
        throw MessageError.userNotFound
    }
    
    private func getSenderDisplayName(pubkey: String) async throws -> String {
        // Look up sender's display name from group members or contacts
        // For MVP, return truncated pubkey
        return "User \(pubkey.prefix(8))"
    }
    
    // MARK: - Message Management
    
    func deleteMessage(_ messageId: String, from groupId: String) async throws {
        let context = coreDataManager.viewContext
        
        // Remove from Core Data
        let messages = try EncryptedUserData.fetchUserData(
            userId: currentUserId,
            dataType: "group_messages",
            context: context
        ).filter { $0.identifier == messageId }
        
        for message in messages {
            context.delete(message)
        }
        
        try context.save()
        
        // Remove from local cache
        await MainActor.run {
            self.groupMessages[groupId]?.removeAll { $0.id == messageId }
        }
    }
    
    func getMessageHistory(for groupId: String, before date: Date, limit: Int = 50) async throws -> [GroupMessage] {
        let context = coreDataManager.viewContext
        
        let encryptedMessages = try EncryptedUserData.fetchUserData(
            userId: currentUserId,
            dataType: "group_messages",
            context: context
        ).filter { 
            $0.groupId == groupId && $0.lastModified < date
        }.sorted { 
            $0.lastModified > $1.lastModified 
        }.prefix(limit)
        
        var messages: [GroupMessage] = []
        
        for encryptedMessage in encryptedMessages {
            do {
                let encryptedDataStruct = try JSONDecoder().decode(EncryptedData.self, from: encryptedMessage.encryptedData)
                let message: GroupMessage = try encryptionManager.decryptUserPrivateData(
                    encryptedDataStruct,
                    type: GroupMessage.self,
                    context: .userMessages,
                    identifier: encryptedMessage.identifier
                )
                messages.append(message)
            } catch {
                print("Failed to decrypt message \(encryptedMessage.identifier): \(error)")
            }
        }
        
        return messages.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Data Models

struct GroupMessage: Identifiable, Codable {
    let id: String
    let groupId: String
    let senderId: String
    let senderName: String
    let content: String
    let messageType: MessageType
    let timestamp: Date
    var isEdited: Bool = false
    var editedAt: Date?
    var reactions: [MessageReaction] = []
    
    var isFromCurrentUser: Bool {
        return senderId == "default_user" // TODO: Get current user ID dynamically
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

enum MessageType: String, Codable {
    case text = "text"
    case image = "image"
    case file = "file"
    case psbt = "psbt"
    case goalUpdate = "goalUpdate"
    case memberJoined = "memberJoined"
    case memberLeft = "memberLeft"
    case system = "system"
    
    var icon: String {
        switch self {
        case .text: return "💬"
        case .image: return "🖼️"
        case .file: return "📎"
        case .psbt: return "🔐"
        case .goalUpdate: return "🎯"
        case .memberJoined: return "👋"
        case .memberLeft: return "👋"
        case .system: return "⚙️"
        }
    }
}

enum SystemMessageType: String, Codable {
    case groupCreated = "group_created"
    case goalReached = "goal_reached"
    case transactionCompleted = "transaction_completed"
    case memberAdded = "member_added"
    case memberRemoved = "member_removed"
    case settingsChanged = "settings_changed"
}

struct MessageReaction: Codable {
    let userId: String
    let reaction: String
    let timestamp: Date
}

struct GroupMessageEvent: Codable {
    let groupId: String
    let messageId: String
    let encryptedContent: String
    let messageType: String
    let timestamp: Date
}

// MARK: - Error Types

enum MessageError: Error, LocalizedError {
    case groupKeyNotFound
    case userNotFound
    case encryptionFailed
    case broadcastFailed
    case messageNotFound
    
    var errorDescription: String? {
        switch self {
        case .groupKeyNotFound:
            return "Group encryption key not found"
        case .userNotFound:
            return "User not found"
        case .encryptionFailed:
            return "Message encryption failed"
        case .broadcastFailed:
            return "Failed to broadcast message"
        case .messageNotFound:
            return "Message not found"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let nostrMessageReceived = Notification.Name("nostrMessageReceived")
    static let groupMessageReceived = Notification.Name("groupMessageReceived")
}

// MARK: - String Extensions

extension String {
    var sha256Hash: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}