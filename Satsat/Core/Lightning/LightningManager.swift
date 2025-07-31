// LightningManager.swift
// Lightning Network integration for instant Bitcoin deposits to Satsat groups

import SwiftUI
import Combine

// MARK: - Lightning Manager

@MainActor
class LightningManager: ObservableObject {
    static let shared = LightningManager()
    
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var balance: UInt64 = 0 // Lightning balance in sats
    @Published var activeInvoices: [LightningInvoice] = []
    @Published var paymentHistory: [LightningPayment] = []
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let maxInvoiceAmount: UInt64 = 21_000_000 // 0.21 BTC max per invoice
    
    private init() {
        setupLightningNode()
        loadInvoiceHistory()
    }
    
    // MARK: - Lightning Node Setup
    
    private func setupLightningNode() {
        // No Lightning node setup - perfect zero-custody compliance
        // Users must connect their own Lightning wallets via NWC or use onchain Bitcoin
        print("✅ Zero-custody Lightning mode: Users connect own wallets or use onchain Bitcoin")
    }
    
    private func connectToNWCNode() {
        // No Voltage connection - perfect zero-custody compliance
        // Users must connect their own Lightning wallets via NWC or use onchain Bitcoin
        isLoading = true
        
        Task {
            await MainActor.run {
                isConnected = false
                isLoading = false
                print("✅ Zero-custody Lightning mode: Users connect own wallets or use onchain Bitcoin")
            }
        }
    }
    
    
    private func fallbackToDemoMode() {
        // Fallback to demo mode for development/testing
        isConnected = true
        balance = 150_000
        print("🔄 Running in Lightning demo mode")
    }
    
    // MARK: - Invoice Generation
    
    func generateInvoice(
        amount: UInt64,
        description: String,
        groupId: String,
        expiryMinutes: Int = 60
    ) async throws -> LightningInvoice {
        
        guard isConnected else {
            throw LightningError.noLightningWallet
        }
        
        guard amount > 0 && amount <= maxInvoiceAmount else {
            throw LightningError.invalidResponse
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Simulate invoice generation
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            let invoice = LightningInvoice(
                id: "inv_\(UUID().uuidString.prefix(8))",
                paymentRequest: generatePaymentRequest(amount: amount),
                amount: amount,
                description: description,
                groupId: groupId,
                expiresAt: Date().addingTimeInterval(TimeInterval(expiryMinutes * 60)),
                status: .pending
            )
            
            await MainActor.run {
                activeInvoices.append(invoice)
                isLoading = false
            }
            
            // Start monitoring for payment
            startPaymentMonitoring(for: invoice)
            
            return invoice
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    private func generatePaymentRequest(amount: UInt64) -> String {
        // Generate a mock Lightning payment request (BOLT 11 invoice)
        // Format: lnbc[amount][multiplier][timestamp][checksum]
        let prefix = "lnbc"
        let amountMillisats = amount * 1000
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let mockData = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(50))
        
        return "\(prefix)\(amountMillisats)u\(timestamp)\(mockData)"
    }
    
    // MARK: - Payment Monitoring
    
    private func startPaymentMonitoring(for invoice: LightningInvoice) {
        Task {
            // Simulate payment detection after random delay (10-30 seconds for demo)
            let randomDelay = Double.random(in: 10...30)
            try await Task.sleep(nanoseconds: UInt64(randomDelay * 1_000_000_000))
            
            await handleInvoicePaid(invoice)
        }
    }
    
    private func handleInvoicePaid(_ invoice: LightningInvoice) async {
        guard let index = activeInvoices.firstIndex(where: { $0.id == invoice.id }) else { return }
        
        // Update invoice status
        activeInvoices[index].status = .paid
        activeInvoices[index].paidAt = Date()
        
        // Create payment record
        let payment = LightningPayment(
            id: "pay_\(UUID().uuidString.prefix(8))",
            invoiceId: invoice.id,
            amount: invoice.amount,
            description: invoice.description,
            groupId: invoice.groupId,
            direction: .incoming,
            status: .completed,
            completedAt: Date()
        )
        
        paymentHistory.append(payment)
        
        // Update balance
        balance += invoice.amount
        
        // Trigger on-chain deposit to group multisig
        await processGroupDeposit(payment)
        
        // Send notification
        await sendPaymentNotification(payment)
    }
    
    // MARK: - Group Integration
    
    private func processGroupDeposit(_ payment: LightningPayment) async {
        // In production, this would:
        // 1. Wait for Lightning payment confirmation
        // 2. Create on-chain transaction to group multisig
        // 3. Update group balance
        
        print("Processing Lightning deposit of \(payment.amount) sats to group \(payment.groupId)")
        
        // Simulate on-chain deposit delay
        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        // Notify group manager about new deposit
        NotificationCenter.default.post(
            name: .lightningContributionReceived,
            object: nil,
            userInfo: [
                "groupId": payment.groupId,
                "amount": payment.amount,
                "paymentId": payment.id
            ]
        )
    }
    
    // MARK: - LNURL Support
    
    func generateLNURL(for groupId: String, amount: UInt64? = nil) async throws -> LNURL {
        guard isConnected else {
            throw LightningError.noLightningWallet
        }
        
        // Generate LNURL-pay compatible URL
        let baseUrl = "https://satsat.app/lnurl" // Would be actual service URL
        let callback = "\(baseUrl)/callback"
        let metadata = "[[\"text/plain\",\"Satsat Group Deposit\"]]"
        
        let lnurl = LNURL(
            id: "lnurl_\(UUID().uuidString.prefix(8))",
            callback: callback,
            metadata: metadata,
            minSendable: 1000, // 1 sat minimum
            maxSendable: maxInvoiceAmount,
            groupId: groupId,
            tag: "payRequest"
        )
        
        return lnurl
    }
    
    // MARK: - Payment Sending (for withdrawals)
    
    func sendPayment(
        invoice: String,
        amount: UInt64? = nil
    ) async throws -> LightningPayment {
        
        guard isConnected else {
            throw LightningError.noLightningWallet
        }
        
        guard balance >= (amount ?? 0) else {
            throw LightningError.paymentFailed
        }
        
        isLoading = true
        
        do {
            // Validate and decode invoice
            let decodedInvoice = try decodeInvoice(invoice)
            let paymentAmount = amount ?? decodedInvoice.amount
            
            // Simulate payment
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            let payment = LightningPayment(
                id: "pay_\(UUID().uuidString.prefix(8))",
                invoiceId: decodedInvoice.id,
                amount: paymentAmount,
                description: decodedInvoice.description,
                groupId: nil, // Outgoing payment
                direction: .outgoing,
                status: .completed,
                completedAt: Date()
            )
            
            await MainActor.run {
                paymentHistory.append(payment)
                balance -= paymentAmount
                isLoading = false
            }
            
            return payment
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    private func decodeInvoice(_ invoice: String) throws -> DecodedInvoice {
        // Simplified invoice decoding for demo
        // In production, would use proper BOLT 11 decoder
        
        guard invoice.hasPrefix("lnbc") else {
            throw LightningError.invoiceNotFound
        }
        
        return DecodedInvoice(
            id: "decoded_\(UUID().uuidString.prefix(8))",
            amount: 10000, // Mock amount
            description: "Lightning Payment",
            paymentHash: "mock_payment_hash"
        )
    }
    
    // MARK: - Channel Management
    
    func getChannelInfo() async -> [ChannelInfo] {
        // Mock channel data for UI
        return [
            ChannelInfo(
                id: "channel_1",
                peerId: "peer_satoshi",
                capacity: 1_000_000,
                localBalance: 600_000,
                remoteBalance: 400_000,
                isActive: true
            ),
            ChannelInfo(
                id: "channel_2",
                peerId: "peer_lightning",
                capacity: 500_000,
                localBalance: 200_000,
                remoteBalance: 300_000,
                isActive: true
            )
        ]
    }
    
    // MARK: - Invoice Management
    
    func cancelInvoice(_ invoiceId: String) async throws {
        guard let index = activeInvoices.firstIndex(where: { $0.id == invoiceId }) else {
            throw LightningError.invoiceNotFound
        }
        
        activeInvoices[index].status = .cancelled
    }
    
    func getInvoiceStatus(_ invoiceId: String) -> InvoiceStatus? {
        return activeInvoices.first(where: { $0.id == invoiceId })?.status
    }
    
    // MARK: - Utility Methods
    
    func formatPaymentRequest(_ paymentRequest: String) -> String {
        // Format for display (show first/last chars)
        if paymentRequest.count > 20 {
            let start = paymentRequest.prefix(10)
            let end = paymentRequest.suffix(10)
            return "\(start)...\(end)"
        }
        return paymentRequest
    }
    
    private func sendPaymentNotification(_ payment: LightningPayment) async {
        // Integration with NotificationService
        print("Sending notification for Lightning payment: \(payment.amount) sats")
    }
    
    private func loadInvoiceHistory() {
        // Load persisted invoice history
        // For demo, start with empty state
    }
    
    // MARK: - Connection Management
    
    func reconnect() async {
        isConnected = false
        isLoading = true
        
        // Simulate reconnection
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        isConnected = true
        isLoading = false
    }
    
    func disconnect() {
        isConnected = false
        balance = 0
        activeInvoices.removeAll()
    }
}

// MARK: - Data Models

struct LightningInvoice: Identifiable, Codable {
    let id: String
    let paymentRequest: String
    let amount: UInt64
    let description: String
    let groupId: String
    let createdAt = Date()
    let expiresAt: Date
    var status: InvoiceStatus
    var paidAt: Date?
    
    var isExpired: Bool {
        return Date() > expiresAt && status == .pending
    }
    
    var timeRemaining: TimeInterval {
        return max(0, expiresAt.timeIntervalSinceNow)
    }
}

struct LightningPayment: Identifiable, Codable {
    let id: String
    let invoiceId: String
    let amount: UInt64
    let description: String
    let groupId: String?
    let direction: PaymentDirection
    var status: PaymentStatus
    let createdAt = Date()
    var completedAt: Date?
}

struct LNURL: Identifiable, Codable {
    let id: String
    let callback: String
    let metadata: String
    let minSendable: UInt64
    let maxSendable: UInt64
    let groupId: String
    let tag: String
    
    var encodedLNURL: String {
        // In production, would properly encode with bech32
        return "lnurl1dp68gurn8ghj7mrww4exctnzd9nhxatw9eu8j730d3h82unvwqhkvmm3v9nr6ut9xccxznrpwkl"
    }
}

struct DecodedInvoice {
    let id: String
    let amount: UInt64
    let description: String
    let paymentHash: String
}

struct ChannelInfo: Identifiable {
    let id: String
    let peerId: String
    let capacity: UInt64
    let localBalance: UInt64
    let remoteBalance: UInt64
    let isActive: Bool
    
    var utilizationPercentage: Double {
        return Double(localBalance) / Double(capacity)
    }
}

enum InvoiceStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case paid = "paid"
    case expired = "expired"
    case cancelled = "cancelled"
    
    var color: Color {
        switch self {
        case .pending: return SatsatDesignSystem.Colors.warning
        case .paid: return SatsatDesignSystem.Colors.success
        case .expired: return SatsatDesignSystem.Colors.textSecondary
        case .cancelled: return SatsatDesignSystem.Colors.error
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .paid: return "checkmark.circle.fill"
        case .expired: return "exclamationmark.triangle"
        case .cancelled: return "xmark.circle"
        }
    }
}

enum PaymentDirection: String, Codable {
    case incoming = "incoming"
    case outgoing = "outgoing"
    
    var icon: String {
        switch self {
        case .incoming: return "arrow.down.circle.fill"
        case .outgoing: return "arrow.up.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .incoming: return SatsatDesignSystem.Colors.success
        case .outgoing: return SatsatDesignSystem.Colors.satsatOrange
        }
    }
}

enum PaymentStatus: String, Codable {
    case pending = "pending"
    case completed = "completed"
    case failed = "failed"
    
    var color: Color {
        switch self {
        case .pending: return SatsatDesignSystem.Colors.warning
        case .completed: return SatsatDesignSystem.Colors.success
        case .failed: return SatsatDesignSystem.Colors.error
        }
    }
}

// LightningError enum defined in NWCLightningManager.swift

// Notification names defined in NWCLightningManager.swift

// MARK: - Zero-Custody Lightning Models

// No Voltage integration - perfect zero-custody compliance
// Users must connect their own Lightning wallets via NWC or use onchain Bitcoin

// MARK: - Demo Lightning Extensions

extension LightningManager {
    func generateDemoInvoice(amount: UInt64, description: String) async throws -> String {
        // Demo mode for development only
        return generateMockBOLT11Invoice(amount: amount, description: description)
    }
    
    private func generateMockBOLT11Invoice(amount: UInt64, description: String) -> String {
        // Generate a realistic-looking BOLT 11 invoice for demo
        let prefix = "lnbc"
        let amountMillisats = amount * 1000
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let mockData = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        
        return "\(prefix)\(amountMillisats)n1\(timestamp)\(mockData.prefix(50))"
    }
    
    func checkDemoInvoiceStatus(_ paymentHash: String) async throws -> InvoiceStatus {
        // Demo mode - simulate random status changes
        let statuses: [InvoiceStatus] = [.pending, .paid]
        return statuses.randomElement() ?? .pending
    }
    
    func getDemoBalance() async throws -> UInt64 {
        // Demo mode - return mock balance
        return 150_000
    }
}

// MARK: - Sample Data

#if DEBUG
extension LightningInvoice {
    static let sampleInvoice = LightningInvoice(
        id: "inv_12345",
        paymentRequest: "lnbc50000n1pjkl2k3pp5abc123def456...",
        amount: 50000,
        description: "Vacation Fund Deposit",
        groupId: "group_vacation",
        expiresAt: Date().addingTimeInterval(3600),
        status: .pending
    )
}

extension LightningPayment {
    static let samplePayment = LightningPayment(
        id: "pay_67890",
        invoiceId: "inv_12345",
        amount: 50000,
        description: "Vacation Fund Deposit",
        groupId: "group_vacation",
        direction: .incoming,
        status: .completed,
        completedAt: Date().addingTimeInterval(-1800)
    )
}
#endif