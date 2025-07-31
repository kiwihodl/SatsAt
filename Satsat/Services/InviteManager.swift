// InviteManager.swift
// Group invitation and discovery system for Satsat

import Foundation
import Combine
import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Invite Manager Service

@MainActor
class InviteManager: ObservableObject {
    static let shared = InviteManager()
    
    @Published var activeInvites: [GroupInvite] = []
    @Published var pendingInvites: [PendingInvite] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let groupManager = GroupManager.shared
    private let nostrClient = NostrClient.shared
    private let encryptionManager = SatsatEncryptionManager.shared
    private let keychainManager = KeychainManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var currentUserId: String {
        return UserDefaults.standard.string(forKey: "currentUserId") ?? "default_user"
    }
    
    private init() {
        setupInviteObservers()
    }
    
    // MARK: - Setup
    
    private func setupInviteObservers() {
        // Listen for invite-related Nostr events
        NotificationCenter.default.publisher(for: .groupInviteReceived)
            .sink { [weak self] notification in
                self?.handleInviteReceived(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .inviteResponseReceived)
            .sink { [weak self] notification in
                self?.handleInviteResponse(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Invite Creation
    
    /// Create a shareable invite for a group
    func createInvite(for groupId: String, maxUses: Int = 10, expirationHours: Int = 168) async throws -> GroupInvite {
        // Verify user has permission to create invites
        guard let group = groupManager.activeGroups.first(where: { $0.id == groupId }),
              let currentMember = group.getMember(byId: currentUserId),
              currentMember.role.canInviteMembers else {
            throw InviteError.insufficientPermissions
        }
        
        // Create invite data
        let invite = GroupInvite(
            id: UUID().uuidString,
            groupId: groupId,
            groupName: group.displayName,
            createdBy: currentUserId,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .hour, value: expirationHours, to: Date()) ?? Date(),
            maxUses: maxUses,
            currentUses: 0,
            isActive: true
        )
        
        // Store invite locally
        try await storeInvite(invite)
        
        // Broadcast invite creation to group members
        try await broadcastInviteCreation(invite)
        
        await MainActor.run {
            self.activeInvites.append(invite)
        }
        
        return invite
    }
    
    /// Generate QR code for invite sharing
    func generateInviteQRCode(for invite: GroupInvite) -> UIImage? {
        let inviteURL = generateInviteURL(invite)
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(inviteURL.utf8)
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return nil
    }
    
    /// Generate shareable invite URL
    func generateInviteURL(_ invite: GroupInvite) -> String {
        let baseURL = "satsat://invite"
        let inviteData = InviteURLData(
            inviteId: invite.id,
            groupId: invite.groupId,
            groupName: invite.groupName,
            createdBy: invite.createdBy,
            expiresAt: invite.expiresAt
        )
        
        guard let jsonData = try? JSONEncoder().encode(inviteData),
              let base64Data = jsonData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return "\(baseURL)?error=encoding_failed"
        }
        
        return "\(baseURL)?data=\(base64Data)"
    }
    
    // MARK: - Invite Processing
    
    /// Process an invite URL when received
    func processInviteURL(_ url: String) async throws -> PendingInvite {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems,
              let dataParam = queryItems.first(where: { $0.name == "data" })?.value else {
            throw InviteError.invalidInviteURL
        }
        
        guard let decodedData = Data(base64Encoded: dataParam.removingPercentEncoding ?? ""),
              let inviteData = try? JSONDecoder().decode(InviteURLData.self, from: decodedData) else {
            throw InviteError.invalidInviteData
        }
        
        // Verify invite is still valid
        guard inviteData.expiresAt > Date() else {
            throw InviteError.inviteExpired
        }
        
        // Check if user is already a member
        if groupManager.activeGroups.contains(where: { $0.id == inviteData.groupId }) {
            throw InviteError.alreadyMember
        }
        
        // Create pending invite
        let pendingInvite = PendingInvite(
            id: UUID().uuidString,
            inviteId: inviteData.inviteId,
            groupId: inviteData.groupId,
            groupName: inviteData.groupName,
            invitedBy: inviteData.createdBy,
            receivedAt: Date(),
            status: .pending
        )
        
        await MainActor.run {
            self.pendingInvites.append(pendingInvite)
        }
        
        return pendingInvite
    }
    
    /// Accept a pending invite
    func acceptInvite(_ pendingInvite: PendingInvite) async throws {
        // Mark invite as accepted
        if let index = pendingInvites.firstIndex(where: { $0.id == pendingInvite.id }) {
            pendingInvites[index].status = .accepted
        }
        
        // Send join request via Nostr
        try await sendJoinRequest(pendingInvite)
        
        // Wait for group creator to approve (simplified for MVP)
        // In production, this would involve real-time approval workflow
        try await simulateJoinApproval(pendingInvite)
    }
    
    /// Decline a pending invite
    func declineInvite(_ pendingInvite: PendingInvite) {
        pendingInvites.removeAll { $0.id == pendingInvite.id }
    }
    
    // MARK: - Join Request Processing
    
    private func sendJoinRequest(_ pendingInvite: PendingInvite) async throws {
        let joinRequest = JoinRequestEvent(
            inviteId: pendingInvite.inviteId,
            groupId: pendingInvite.groupId,
            requesterId: currentUserId,
            requesterPubkey: try await getCurrentUserPubkey(),
            requesterName: try await getCurrentUserDisplayName(),
            timestamp: Date()
        )
        
        let eventData = try JSONEncoder().encode(joinRequest)
        let eventString = String(data: eventData, encoding: .utf8)!
        
        let nostrEvent = try NostrEvent.createCustomEvent(
            kind: 1007, // Custom: Join request
            content: eventString,
            privateKey: try keychainManager.retrieveNostrPrivateKey(for: currentUserId)
        )
        
        nostrClient.publishEvent(nostrEvent)
    }
    
    private func simulateJoinApproval(_ pendingInvite: PendingInvite) async throws {
        // Simplified approval for MVP - in production this would be real-time
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
        
        // Create a mock group for the user to join
        let newGroup = SavingsGroup.sampleGroup
        newGroup.displayName = pendingInvite.groupName
        
        await MainActor.run {
            self.groupManager.activeGroups.append(newGroup)
            
            // Remove from pending invites
            self.pendingInvites.removeAll { $0.id == pendingInvite.id }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleInviteReceived(_ notification: Notification) {
        guard let event = notification.object as? NostrEvent else { return }
        
        Task {
            do {
                let inviteData = try JSONDecoder().decode(InviteReceivedEvent.self, from: event.content.data(using: .utf8)!)
                
                let pendingInvite = PendingInvite(
                    id: UUID().uuidString,
                    inviteId: inviteData.inviteId,
                    groupId: inviteData.groupId,
                    groupName: inviteData.groupName,
                    invitedBy: inviteData.inviterPubkey,
                    receivedAt: Date(),
                    status: .pending
                )
                
                await MainActor.run {
                    self.pendingInvites.append(pendingInvite)
                }
                
            } catch {
                print("Failed to process invite: \(error)")
            }
        }
    }
    
    private func handleInviteResponse(_ notification: Notification) {
        // Handle responses to sent invites
        if let userInfo = notification.userInfo,
           let inviteId = userInfo["inviteId"] as? String,
           let response = userInfo["response"] as? String {
            
            // Update invite status based on response
            print("Invite \(inviteId) response: \(response)")
        }
    }
    
    // MARK: - Storage
    
    private func storeInvite(_ invite: GroupInvite) async throws {
        // Store invite in encrypted storage
        let inviteData = try JSONEncoder().encode(invite)
        
        _ = try encryptionManager.encryptUserPrivateData(
            invite,
            context: .userPrivateData,
            identifier: invite.id
        )
        
        // For MVP, just store in memory
    }
    
    private func broadcastInviteCreation(_ invite: GroupInvite) async throws {
        let inviteEvent = InviteCreatedEvent(
            inviteId: invite.id,
            groupId: invite.groupId,
            groupName: invite.groupName,
            createdBy: invite.createdBy,
            expiresAt: invite.expiresAt,
            maxUses: invite.maxUses
        )
        
        let eventData = try JSONEncoder().encode(inviteEvent)
        let eventString = String(data: eventData, encoding: .utf8)!
        
        let nostrEvent = try NostrEvent.createCustomEvent(
            kind: 1008, // Custom: Invite created
            content: eventString,
            privateKey: try keychainManager.retrieveNostrPrivateKey(for: currentUserId)
        )
        
        nostrClient.publishEvent(nostrEvent)
    }
    
    // MARK: - Utility Methods
    
    func revokeInvite(_ inviteId: String) async throws {
        // Mark invite as inactive
        if let index = activeInvites.firstIndex(where: { $0.id == inviteId }) {
            activeInvites[index].isActive = false
            
            // Broadcast revocation
            try await broadcastInviteRevocation(inviteId)
        }
    }
    
    private func broadcastInviteRevocation(_ inviteId: String) async throws {
        let revocationEvent = InviteRevokedEvent(
            inviteId: inviteId,
            revokedBy: currentUserId,
            revokedAt: Date()
        )
        
        let eventData = try JSONEncoder().encode(revocationEvent)
        let eventString = String(data: eventData, encoding: .utf8)!
        
        let nostrEvent = try NostrEvent.createCustomEvent(
            kind: 1009, // Custom: Invite revoked
            content: eventString,
            privateKey: try keychainManager.retrieveNostrPrivateKey(for: currentUserId)
        )
        
        nostrClient.publishEvent(nostrEvent)
    }
    
    private func getCurrentUserPubkey() async throws -> String {
        // Get current user's Nostr public key
        return "mock_pubkey_\(currentUserId)" // Simplified for MVP
    }
    
    private func getCurrentUserDisplayName() async throws -> String {
        // Get current user's display name
        return "User \(currentUserId)" // Simplified for MVP
    }
}

// MARK: - Data Models

struct GroupInvite: Identifiable, Codable {
    let id: String
    let groupId: String
    let groupName: String
    let createdBy: String
    let createdAt: Date
    let expiresAt: Date
    let maxUses: Int
    var currentUses: Int
    var isActive: Bool
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var isAtMaxUses: Bool {
        return currentUses >= maxUses
    }
    
    var isValid: Bool {
        return isActive && !isExpired && !isAtMaxUses
    }
    
    var timeRemaining: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        
        let timeInterval = expiresAt.timeIntervalSince(Date())
        if timeInterval > 0 {
            return formatter.string(from: timeInterval) ?? "Expired"
        } else {
            return "Expired"
        }
    }
}

struct PendingInvite: Identifiable, Codable {
    let id: String
    let inviteId: String
    let groupId: String
    let groupName: String
    let invitedBy: String
    let receivedAt: Date
    var status: InviteStatus
}

enum InviteStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case expired = "expired"
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .accepted: return .green
        case .declined: return .red
        case .expired: return .gray
        }
    }
    
    var displayName: String {
        return rawValue.capitalized
    }
}

struct InviteURLData: Codable {
    let inviteId: String
    let groupId: String
    let groupName: String
    let createdBy: String
    let expiresAt: Date
}

// MARK: - Event Models

struct InviteCreatedEvent: Codable {
    let inviteId: String
    let groupId: String
    let groupName: String
    let createdBy: String
    let expiresAt: Date
    let maxUses: Int
}

struct InviteReceivedEvent: Codable {
    let inviteId: String
    let groupId: String
    let groupName: String
    let inviterPubkey: String
    let receivedAt: Date
}

struct JoinRequestEvent: Codable {
    let inviteId: String
    let groupId: String
    let requesterId: String
    let requesterPubkey: String
    let requesterName: String
    let timestamp: Date
}

struct InviteRevokedEvent: Codable {
    let inviteId: String
    let revokedBy: String
    let revokedAt: Date
}

// MARK: - Error Types

enum InviteError: Error, LocalizedError {
    case insufficientPermissions
    case invalidInviteURL
    case invalidInviteData
    case inviteExpired
    case alreadyMember
    case groupNotFound
    case inviteNotFound
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return "You don't have permission to create invites for this group"
        case .invalidInviteURL:
            return "Invalid invite link"
        case .invalidInviteData:
            return "Invalid invite data"
        case .inviteExpired:
            return "This invite has expired"
        case .alreadyMember:
            return "You're already a member of this group"
        case .groupNotFound:
            return "Group not found"
        case .inviteNotFound:
            return "Invite not found"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let inviteResponseReceived = Notification.Name("inviteResponseReceived")
}