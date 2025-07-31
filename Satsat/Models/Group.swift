// Group.swift
// Data models for Satsat savings groups

import Foundation
import SwiftUI
import Combine

// MARK: - Group Data Model

class SavingsGroup: ObservableObject, Identifiable, Codable {
    let id: String
    @Published var displayName: String
    @Published var goal: GroupGoal
    @Published var members: [GroupMember]
    @Published var multisigConfig: MultisigConfig
    @Published var currentBalance: UInt64
    @Published var isActive: Bool
    @Published var createdAt: Date
    @Published var lastActivity: Date
    
    // UI State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var connectionStatus: GroupConnectionStatus = .connecting
    
    // Coding keys for persistence
    private enum CodingKeys: String, CodingKey {
        case id, displayName, goal, members, multisigConfig
        case currentBalance, isActive, createdAt, lastActivity
    }
    
    init(
        id: String = UUID().uuidString,
        displayName: String,
        goal: GroupGoal,
        members: [GroupMember],
        multisigConfig: MultisigConfig
    ) {
        self.id = id
        self.displayName = displayName
        self.goal = goal
        self.members = members
        self.multisigConfig = multisigConfig
        self.currentBalance = 0
        self.isActive = true
        self.createdAt = Date()
        self.lastActivity = Date()
    }
    
    // MARK: - Codable Implementation
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        goal = try container.decode(GroupGoal.self, forKey: .goal)
        members = try container.decode([GroupMember].self, forKey: .members)
        multisigConfig = try container.decode(MultisigConfig.self, forKey: .multisigConfig)
        currentBalance = try container.decode(UInt64.self, forKey: .currentBalance)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastActivity = try container.decode(Date.self, forKey: .lastActivity)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(goal, forKey: .goal)
        try container.encode(members, forKey: .members)
        try container.encode(multisigConfig, forKey: .multisigConfig)
        try container.encode(currentBalance, forKey: .currentBalance)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastActivity, forKey: .lastActivity)
    }
    
    // MARK: - Computed Properties
    
    var progressPercentage: Double {
        guard goal.targetAmountSats > 0 else { return 0 }
        return min(Double(currentBalance) / Double(goal.targetAmountSats), 1.0)
    }
    
    var progressColor: Color {
        switch progressPercentage {
        case 0..<0.25: return .red
        case 0.25..<0.5: return .orange
        case 0.5..<0.75: return .yellow
        case 0.75..<1.0: return .blue
        default: return .green
        }
    }
    
    var activeMembers: [GroupMember] {
        return members.filter { $0.isActive }
    }
    
    var remainingAmount: UInt64 {
        return goal.targetAmountSats > currentBalance 
            ? goal.targetAmountSats - currentBalance 
            : 0
    }
    
    var isGoalReached: Bool {
        return currentBalance >= goal.targetAmountSats
    }
    
    var memberCount: Int {
        return activeMembers.count
    }
    
    var requiredSignatures: Int {
        return multisigConfig.threshold
    }
    
    // MARK: - Member Management
    
    func addMember(_ member: GroupMember) {
        members.append(member)
        lastActivity = Date()
    }
    
    func removeMember(withId memberId: String) {
        members.removeAll { $0.id == memberId }
        lastActivity = Date()
    }
    
    func updateMemberStatus(memberId: String, isActive: Bool) {
        if let index = members.firstIndex(where: { $0.id == memberId }) {
            members[index].isActive = isActive
            lastActivity = Date()
        }
    }
    
    func getMember(byId memberId: String) -> GroupMember? {
        return members.first { $0.id == memberId }
    }
    
    // MARK: - Balance Management
    
    func updateBalance(_ newBalance: UInt64) {
        currentBalance = newBalance
        lastActivity = Date()
        
        // Check if goal was just reached
        if isGoalReached && newBalance >= goal.targetAmountSats {
            // Goal reached! Could trigger notification here
        }
    }
    
    func addContribution(from memberId: String, amount: UInt64) {
        if let index = members.firstIndex(where: { $0.id == memberId }) {
            members[index].contributionAmount += amount
        }
        updateBalance(currentBalance + amount)
    }
    
    // MARK: - Goal Management
    
    func updateGoal(_ newGoal: GroupGoal) {
        goal = newGoal
        lastActivity = Date()
    }
    
    func canModifyGoal(by memberId: String) -> Bool {
        // Only creator or majority can modify goal
        guard let member = getMember(byId: memberId) else { return false }
        return member.role == .creator || member.role == .admin
    }
}

// MARK: - Group Member Model

struct GroupMember: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String
    var nostrPubkey: String
    var xpub: String?
    var role: MemberRole
    var contributionAmount: UInt64
    var isActive: Bool
    var joinedAt: Date
    var lastSeen: Date
    var avatarColor: String
    
    init(
        id: String = UUID().uuidString,
        displayName: String,
        nostrPubkey: String,
        xpub: String? = nil,
        role: MemberRole = .member
    ) {
        self.id = id
        self.displayName = displayName
        self.nostrPubkey = nostrPubkey
        self.xpub = xpub
        self.role = role
        self.contributionAmount = 0
        self.isActive = true
        self.joinedAt = Date()
        self.lastSeen = Date()
        self.avatarColor = Self.generateAvatarColor()
    }
    
    var contributionPercentage: Double {
        // This would be calculated based on total group contributions
        return 0.0 // TODO: Implement based on group total
    }
    
    var isOnline: Bool {
        return Date().timeIntervalSince(lastSeen) < 300 // 5 minutes
    }
    
    private static func generateAvatarColor() -> String {
        let colors = ["#FF9500", "#007AFF", "#34C759", "#FF3B30", "#AF52DE", "#FF9F0A", "#5AC8FA"]
        return colors.randomElement() ?? "#FF9500"
    }
}

enum MemberRole: String, Codable, CaseIterable {
    case creator = "creator"
    case admin = "admin"
    case member = "member"
    case observer = "observer"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var canCreateTransactions: Bool {
        switch self {
        case .creator, .admin, .member: return true
        case .observer: return false
        }
    }
    
    var canInviteMembers: Bool {
        switch self {
        case .creator, .admin: return true
        case .member, .observer: return false
        }
    }
}

// MARK: - Group Goal Model

struct GroupGoal: Codable, Hashable {
    var title: String
    var description: String
    var targetAmountSats: UInt64
    var targetAmountUsd: Double?
    var targetDate: Date?
    var whitelistedAddress: String?
    var category: GoalCategory
    var isRigid: Bool // Cannot be easily changed once set
    
    init(
        title: String,
        description: String,
        targetAmountSats: UInt64,
        targetAmountUsd: Double? = nil,
        targetDate: Date? = nil,
        whitelistedAddress: String? = nil,
        category: GoalCategory = .general,
        isRigid: Bool = true
    ) {
        self.title = title
        self.description = description
        self.targetAmountSats = targetAmountSats
        self.targetAmountUsd = targetAmountUsd
        self.targetDate = targetDate
        self.whitelistedAddress = whitelistedAddress
        self.category = category
        self.isRigid = isRigid
    }
    
    var formattedTarget: String {
        return "\(targetAmountSats.formattedSats)"
    }
    
    var hasDeadline: Bool {
        return targetDate != nil
    }
    
    var isExpired: Bool {
        guard let targetDate = targetDate else { return false }
        return Date() > targetDate
    }
    
    var daysRemaining: Int? {
        guard let targetDate = targetDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: targetDate)
        return components.day
    }
}

enum GoalCategory: String, Codable, CaseIterable {
    case travel = "travel"
    case emergency = "emergency"
    case investment = "investment"
    case education = "education"
    case general = "general"
    case house = "house"
    case car = "car"
    case gadget = "gadget"
    
    var emoji: String {
        switch self {
        case .travel: return "✈️"
        case .emergency: return "🚨"
        case .investment: return "📈"
        case .education: return "🎓"
        case .general: return "💰"
        case .house: return "🏠"
        case .car: return "🚗"
        case .gadget: return "📱"
        }
    }
    
    var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Multisig Configuration

struct MultisigConfig: Codable, Hashable {
    let threshold: Int          // Required signatures (e.g., 2)
    let totalSigners: Int       // Total possible signers (e.g., 3)
    let scriptType: MultisigScriptType
    let derivationPath: String
    let network: BitcoinNetwork
    
    init(threshold: Int, totalSigners: Int, network: BitcoinNetwork = .testnet) {
        self.threshold = threshold
        self.totalSigners = totalSigners
        self.scriptType = .p2wsh // Default to P2WSH (native segwit)
        self.derivationPath = "m/48'/\(network == .mainnet ? 0 : 1)'/0'/2'" // BIP 48
        self.network = network
    }
    
    var displayName: String {
        return "\(threshold)-of-\(totalSigners) Multisig"
    }
    
    var isValid: Bool {
        return threshold > 0 && threshold <= totalSigners && totalSigners <= 15
    }
    
    var securityLevel: SecurityLevel {
        switch (threshold, totalSigners) {
        case (1, _): return .low
        case (2, 2), (2, 3): return .medium
        case (3, 3), (3, 4), (3, 5): return .high
        default: return .medium
        }
    }
}

enum MultisigScriptType: String, Codable {
    case p2sh = "p2sh"           // Legacy multisig
    case p2shSegwit = "p2sh-segwit" // Wrapped segwit
    case p2wsh = "p2wsh"         // Native segwit (preferred)
}

enum SecurityLevel {
    case low, medium, high
    
    var color: Color {
        switch self {
        case .low: return .red
        case .medium: return .orange
        case .high: return .green
        }
    }
    
    var description: String {
        switch self {
        case .low: return "Basic security"
        case .medium: return "Good security"
        case .high: return "High security"
        }
    }
}

// MARK: - Group Connection Status

enum GroupConnectionStatus {
    case connecting
    case connected
    case disconnected
    case syncing
    case error(String)
    
    var color: Color {
        switch self {
        case .connecting, .syncing: return .orange
        case .connected: return .green
        case .disconnected: return .gray
        case .error: return .red
        }
    }
    
    var description: String {
        switch self {
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .syncing: return "Syncing..."
        case .error(let message): return "Error: \(message)"
        }
    }
}

// MARK: - Extensions (UInt64 extensions moved to UInt64+Extensions.swift)

extension Double {
    var formattedUSD: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
}

// MARK: - Sample Data for Development

extension SavingsGroup {
    static let sampleGroup = SavingsGroup(
        displayName: "Road Trip 2024",
        goal: GroupGoal(
            title: "Epic Road Trip",
            description: "Save for our cross-country adventure",
            targetAmountSats: 2_000_000,
            targetAmountUsd: 1000.0,
            targetDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
            category: .travel
        ),
        members: [
            GroupMember(displayName: "Alice", nostrPubkey: "npub1alice", role: .creator),
            GroupMember(displayName: "Bob", nostrPubkey: "npub1bob", role: .member),
            GroupMember(displayName: "Charlie", nostrPubkey: "npub1charlie", role: .member)
        ],
        multisigConfig: MultisigConfig(threshold: 2, totalSigners: 3)
    )
}

extension GroupMember {
    static let sampleMembers = [
        GroupMember(displayName: "Alice", nostrPubkey: "npub1alice", role: .creator),
        GroupMember(displayName: "Bob", nostrPubkey: "npub1bob", role: .member),
        GroupMember(displayName: "Charlie", nostrPubkey: "npub1charlie", role: .member)
    ]
}