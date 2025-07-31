// NotificationService.swift
// Advanced push notification system for Satsat group coordination

import SwiftUI
import UserNotifications
import Combine

// MARK: - Notification Service

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var pendingNotifications: [SatsatNotification] = []
    @Published var notificationHistory: [SatsatNotification] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkAuthorizationStatus()
        setupNotificationObservers()
    }
    
    // MARK: - Authorization
    
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - PSBT Notifications
    
    func scheduleSigningNotification(for psbt: GroupPSBT, groupName: String) async {
        guard isAuthorized else { return }
        
        let notification = SatsatNotification(
            type: .psbtSigning,
            title: "🔐 Signature Required",
            body: "Your group \"\(groupName)\" needs your signature for a \(psbt.amount.formattedSats) transaction",
            data: ["psbtId": psbt.id, "groupId": psbt.groupId],
            urgency: .high
        )
        
        await scheduleNotification(notification)
    }
    
    func scheduleSignatureCollectedNotification(for psbt: GroupPSBT, signerName: String, groupName: String) async {
        let notification = SatsatNotification(
            type: .signatureCollected,
            title: "✅ Signature Collected",
            body: "\(signerName) signed the transaction in \"\(groupName)\" (\(psbt.signatures.count)/\(psbt.requiredSignatures))",
            data: ["psbtId": psbt.id, "groupId": psbt.groupId],
            urgency: .medium
        )
        
        await scheduleNotification(notification)
    }
    
    func scheduleTransactionReadyNotification(for psbt: GroupPSBT, groupName: String) async {
        let notification = SatsatNotification(
            type: .transactionReady,
            title: "🚀 Ready to Broadcast",
            body: "Transaction in \"\(groupName)\" has all required signatures and is ready to broadcast",
            data: ["psbtId": psbt.id, "groupId": psbt.groupId],
            urgency: .high
        )
        
        await scheduleNotification(notification)
    }
    
    func scheduleTransactionConfirmedNotification(for psbt: GroupPSBT, groupName: String) async {
        let notification = SatsatNotification(
            type: .transactionConfirmed,
            title: "🎉 Transaction Confirmed",
            body: "\(psbt.amount.formattedSats) transaction in \"\(groupName)\" has been confirmed on the Bitcoin network",
            data: ["psbtId": psbt.id, "groupId": psbt.groupId, "txId": psbt.transactionId ?? ""],
            urgency: .medium
        )
        
        await scheduleNotification(notification)
    }
    
    // MARK: - Goal Notifications
    
    func scheduleGoalMilestoneNotification(group: SavingsGroup, milestone: GoalMilestone) async {
        let notification = SatsatNotification(
            type: .goalMilestone,
            title: milestone.title,
            body: milestone.message(for: group),
            data: ["groupId": group.id, "milestone": milestone.rawValue],
            urgency: milestone.urgency
        )
        
        await scheduleNotification(notification)
    }
    
    func scheduleGoalReachedNotification(group: SavingsGroup) async {
        let notification = SatsatNotification(
            type: .goalReached,
            title: "🎯 Goal Achieved!",
            body: "Congratulations! Your group \"\(group.displayName)\" has reached its \(group.goal.targetAmountSats.formattedSats) savings goal!",
            data: ["groupId": group.id],
            urgency: .high
        )
        
        await scheduleNotification(notification)
    }
    
    func scheduleContributionNotification(group: SavingsGroup, contributor: String, amount: UInt64) async {
        let notification = SatsatNotification(
            type: .newContribution,
            title: "💰 New Contribution",
            body: "\(contributor) added \(amount.formattedSats) to \"\(group.displayName)\"",
            data: ["groupId": group.id, "contributor": contributor, "amount": String(amount)],
            urgency: .low
        )
        
        await scheduleNotification(notification)
    }
    
    // MARK: - Group Management Notifications
    
    func scheduleGroupInviteNotification(groupName: String, inviterName: String) async {
        let notification = SatsatNotification(
            type: .groupInvite,
            title: "📨 Group Invitation",
            body: "\(inviterName) invited you to join the savings group \"\(groupName)\"",
            data: ["inviter": inviterName, "groupName": groupName],
            urgency: .medium
        )
        
        await scheduleNotification(notification)
    }
    
    func scheduleMemberJoinedNotification(groupName: String, memberName: String) async {
        let notification = SatsatNotification(
            type: .memberJoined,
            title: "👥 New Member",
            body: "\(memberName) joined your savings group \"\(groupName)\"",
            data: ["groupName": groupName, "memberName": memberName],
            urgency: .low
        )
        
        await scheduleNotification(notification)
    }
    
    // MARK: - Security Notifications
    
    func scheduleSecurityAlertNotification(type: SecurityAlertType, groupName: String) async {
        let notification = SatsatNotification(
            type: .securityAlert,
            title: type.title,
            body: type.message(for: groupName),
            data: ["alertType": type.rawValue, "groupName": groupName],
            urgency: .critical
        )
        
        await scheduleNotification(notification)
    }
    
    // MARK: - Core Notification Scheduling
    
    private func scheduleNotification(_ notification: SatsatNotification) async {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = notification.urgency.sound
        content.badge = 1
        content.userInfo = notification.data
        content.categoryIdentifier = notification.type.categoryIdentifier
        
        // Add custom actions based on notification type
        content.categoryIdentifier = notification.type.categoryIdentifier
        
        // Schedule immediately or with delay based on urgency
        let trigger: UNNotificationTrigger?
        
        switch notification.urgency {
        case .critical, .high:
            trigger = nil // Immediate
        case .medium:
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        case .low:
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        }
        
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            await MainActor.run {
                pendingNotifications.append(notification)
            }
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }
    
    // MARK: - Notification Categories and Actions
    
    func setupNotificationCategories() {
        let psbtCategory = createPSBTCategory()
        let goalCategory = createGoalCategory()
        let securityCategory = createSecurityCategory()
        
        UNUserNotificationCenter.current().setNotificationCategories([
            psbtCategory,
            goalCategory,
            securityCategory
        ])
    }
    
    private func createPSBTCategory() -> UNNotificationCategory {
        let reviewAction = UNNotificationAction(
            identifier: "REVIEW_PSBT",
            title: "Review & Sign",
            options: [.foreground]
        )
        
        let ignoreAction = UNNotificationAction(
            identifier: "IGNORE_PSBT",
            title: "Later",
            options: []
        )
        
        return UNNotificationCategory(
            identifier: "PSBT_SIGNING",
            actions: [reviewAction, ignoreAction],
            intentIdentifiers: []
        )
    }
    
    private func createGoalCategory() -> UNNotificationCategory {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_GOAL",
            title: "View Progress",
            options: [.foreground]
        )
        
        return UNNotificationCategory(
            identifier: "GOAL_UPDATE",
            actions: [viewAction],
            intentIdentifiers: []
        )
    }
    
    private func createSecurityCategory() -> UNNotificationCategory {
        let checkAction = UNNotificationAction(
            identifier: "CHECK_SECURITY",
            title: "Check Now",
            options: [.foreground]
        )
        
        return UNNotificationCategory(
            identifier: "SECURITY_ALERT",
            actions: [checkAction],
            intentIdentifiers: []
        )
    }
    
    // MARK: - Notification Management
    
    func clearNotification(_ notificationId: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        
        pendingNotifications.removeAll { $0.id == notificationId }
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        pendingNotifications.removeAll()
    }
    
    func getBadgeCount() async -> Int {
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        return delivered.count
    }
    
    func setBadgeCount(_ count: Int) {
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }
    
    // MARK: - Background Monitoring
    
    private func setupNotificationObservers() {
        // Listen for app state changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.updateBadgeCount()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateBadgeCount() async {
        let count = await getBadgeCount()
        await MainActor.run {
            setBadgeCount(count)
        }
    }
}

// MARK: - Data Models

struct SatsatNotification: Identifiable, Codable {
    let id = UUID().uuidString
    let type: NotificationType
    let title: String
    let body: String
    let data: [String: String]
    let urgency: NotificationUrgency
    let createdAt = Date()
}

enum NotificationType: String, Codable {
    case psbtSigning = "psbt_signing"
    case signatureCollected = "signature_collected"
    case transactionReady = "transaction_ready"
    case transactionConfirmed = "transaction_confirmed"
    case goalMilestone = "goal_milestone"
    case goalReached = "goal_reached"
    case newContribution = "new_contribution"
    case groupInvite = "group_invite"
    case memberJoined = "member_joined"
    case securityAlert = "security_alert"
    
    var categoryIdentifier: String {
        switch self {
        case .psbtSigning, .signatureCollected, .transactionReady, .transactionConfirmed:
            return "PSBT_SIGNING"
        case .goalMilestone, .goalReached, .newContribution:
            return "GOAL_UPDATE"
        case .groupInvite, .memberJoined:
            return "GROUP_UPDATE"
        case .securityAlert:
            return "SECURITY_ALERT"
        }
    }
}

enum NotificationUrgency: String, Codable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var sound: UNNotificationSound {
        switch self {
        case .critical:
            return .defaultCritical
        case .high:
            return .default
        case .medium:
            return .default
        case .low:
            return .default
        }
    }
}

enum GoalMilestone: String, CaseIterable {
    case quarter = "25_percent"
    case half = "50_percent"
    case threeQuarters = "75_percent"
    case ninety = "90_percent"
    
    var title: String {
        switch self {
        case .quarter: return "🎯 25% Complete!"
        case .half: return "🎯 Halfway There!"
        case .threeQuarters: return "🎯 75% Complete!"
        case .ninety: return "🎯 Almost There!"
        }
    }
    
    func message(for group: SavingsGroup) -> String {
        switch self {
        case .quarter:
            return "Your group \"\(group.displayName)\" has saved 25% toward your \(group.goal.targetAmountSats.formattedSats) goal!"
        case .half:
            return "Halfway to your goal! \"\(group.displayName)\" has saved \(group.currentBalance.formattedSats)"
        case .threeQuarters:
            return "You're so close! \"\(group.displayName)\" is 75% of the way to \(group.goal.targetAmountSats.formattedSats)"
        case .ninety:
            return "Final stretch! \"\(group.displayName)\" is 90% complete with only \(group.remainingAmount.formattedSats) to go!"
        }
    }
    
    var urgency: NotificationUrgency {
        switch self {
        case .quarter, .threeQuarters: return .medium
        case .half: return .high
        case .ninety: return .high
        }
    }
    
    var threshold: Double {
        switch self {
        case .quarter: return 0.25
        case .half: return 0.50
        case .threeQuarters: return 0.75
        case .ninety: return 0.90
        }
    }
}

enum SecurityAlertType: String, CaseIterable {
    case suspiciousActivity = "suspicious_activity"
    case multipleFailedSigns = "multiple_failed_signs"
    case unusualTransactionPattern = "unusual_transaction"
    case keyCompromise = "key_compromise"
    
    var title: String {
        switch self {
        case .suspiciousActivity: return "🚨 Suspicious Activity"
        case .multipleFailedSigns: return "⚠️ Multiple Failed Signs"
        case .unusualTransactionPattern: return "🔍 Unusual Transaction"
        case .keyCompromise: return "🚨 Security Alert"
        }
    }
    
    func message(for groupName: String) -> String {
        switch self {
        case .suspiciousActivity:
            return "Unusual activity detected in group \"\(groupName)\". Please review recent transactions."
        case .multipleFailedSigns:
            return "Multiple failed signature attempts detected in \"\(groupName)\". Check with group members."
        case .unusualTransactionPattern:
            return "An unusual transaction pattern was detected in \"\(groupName)\". Please verify this activity."
        case .keyCompromise:
            return "Potential security issue detected in \"\(groupName)\". Please check your keys immediately."
        }
    }
}

// MARK: - Integration Helpers

extension NotificationService {
    /// Called when a PSBT is created
    func handlePSBTCreated(_ psbt: GroupPSBT, groupName: String) async {
        await scheduleSigningNotification(for: psbt, groupName: groupName)
    }
    
    /// Called when a signature is added
    func handleSignatureAdded(_ psbt: GroupPSBT, signerName: String, groupName: String) async {
        await scheduleSignatureCollectedNotification(for: psbt, signerName: signerName, groupName: groupName)
        
        if psbt.isFullySigned {
            await scheduleTransactionReadyNotification(for: psbt, groupName: groupName)
        }
    }
    
    /// Called when transaction is confirmed
    func handleTransactionConfirmed(_ psbt: GroupPSBT, groupName: String) async {
        await scheduleTransactionConfirmedNotification(for: psbt, groupName: groupName)
    }
    
    /// Called when group balance changes
    func handleBalanceUpdate(_ group: SavingsGroup, contributor: String?, amount: UInt64) async {
        // Check for milestone achievements
        let newProgress = group.progressPercentage
        
        for milestone in GoalMilestone.allCases {
            if newProgress >= milestone.threshold {
                // Only notify if this is a new milestone
                await scheduleGoalMilestoneNotification(group: group, milestone: milestone)
            }
        }
        
        // Check if goal is reached
        if group.isGoalReached {
            await scheduleGoalReachedNotification(group: group)
        }
        
        // Notify about new contribution
        if let contributor = contributor, amount > 0 {
            await scheduleContributionNotification(group: group, contributor: contributor, amount: amount)
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension SatsatNotification {
    static let samplePSBTSigning = SatsatNotification(
        type: .psbtSigning,
        title: "🔐 Signature Required",
        body: "Your group \"Vacation Fund\" needs your signature for a 50,000 sats transaction",
        data: ["psbtId": "psbt_123", "groupId": "group_vacation"],
        urgency: .high
    )
    
    static let sampleGoalReached = SatsatNotification(
        type: .goalReached,
        title: "🎯 Goal Achieved!",
        body: "Congratulations! Your group \"Vacation Fund\" has reached its 0.1 BTC savings goal!",
        data: ["groupId": "group_vacation"],
        urgency: .high
    )
}
#endif