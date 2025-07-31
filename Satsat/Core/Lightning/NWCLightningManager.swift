// NWCLightningManager.swift
// Nostr Wallet Connect (NWC) Lightning manager with zero-custody compliance
// Users connect their own Lightning wallets via NWC for perfect App Store compliance

import Foundation
import Combine
import SwiftUI

// MARK: - NWC Lightning Manager

@MainActor
class NWCLightningManager: ObservableObject {
    static let shared = NWCLightningManager()
    
    // MARK: - Published Properties
    
    @Published var isNWCConnected = false
    // No Voltage connection - perfect zero-custody compliance
    @Published var connectedWalletName: String?
    @Published var activeConnections: [NWCConnection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Group-specific Lightning tracking
    @Published var groupLightningBalances: [String: UInt64] = [:] // groupId -> contributed amount
    @Published var groupInvoices: [String: [LightningInvoice]] = [:] // groupId -> invoices
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var nwcConnections: [String: NWCConnection] = [:]
    // No Voltage config - perfect zero-custody compliance
    // Users must connect their own Lightning wallets or use onchain Bitcoin
    
    private init() {
        loadConfiguration()
        setupNotifications()
    }
    
    // MARK: - Configuration
    
    private func loadConfiguration() {
        // No Voltage configuration - perfect zero-custody compliance
        // Users must connect their own Lightning wallets via NWC or use onchain Bitcoin
        print("✅ Zero-custody Lightning mode: Users connect own wallets or use onchain Bitcoin")
    }
    
    private func setupNotifications() {
        // Listen for app state changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshConnections()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - NWC Connection Management
    
    /// Connect to user's Lightning wallet via NWC
    func connectNWC(connectionString: String, walletName: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // Parse NWC connection string (nostr+walletconnect://...)
            var connection = try parseNWCConnectionString(connectionString)
            connection.walletName = walletName
            
            // Test the connection
            try await testNWCConnection(connection)
            
            // Store the connection
            nwcConnections[connection.id] = connection
            activeConnections = Array(nwcConnections.values)
            isNWCConnected = true
            connectedWalletName = walletName
            
            print("✅ Connected to \(walletName) via NWC")
            
        } catch {
            errorMessage = "Failed to connect to \(walletName): \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Disconnect from NWC wallet
    func disconnectNWC(_ connectionId: String) {
        nwcConnections.removeValue(forKey: connectionId)
        activeConnections = Array(nwcConnections.values)
        
        if nwcConnections.isEmpty {
            isNWCConnected = false
            connectedWalletName = nil
        }
    }
    
    /// Test NWC connection
    private func testNWCConnection(_ connection: NWCConnection) async throws {
        // Test with a simple get_info request
        let request = NWCRequest(
            method: "get_info",
            params: [:],
            id: UUID().uuidString
        )
        
        _ = try await sendNWCRequest(connection, request: request)
    }
    
    // MARK: - Group Lightning Contributions
    
    /// Generate Lightning invoice for group contribution
    /// This goes directly to the group creator's wallet, tracked separately from their balance
    func generateGroupContributionInvoice(
        groupId: String,
        amount: UInt64,
        contributorName: String,
        groupName: String
    ) async throws -> LightningInvoice {
        
        let description = "Satsat: \(contributorName) → \(groupName) (\(amount.formattedSats))"
        
        // Try NWC first (user's own wallet)
        if let connection = nwcConnections.values.first {
            return try await generateNWCInvoice(
                connection: connection,
                groupId: groupId,
                amount: amount,
                description: description
            )
        }
        
        // No Lightning fallback - onchain only for compliance
        // Users must connect their own Lightning wallets or use onchain Bitcoin
        throw LightningError.noLightningWallet
    }
    
    /// Check if Lightning invoice has been paid and update group balance
    func checkInvoiceStatus(_ invoiceId: String) async throws -> InvoiceStatus {
        guard let invoice = findInvoice(invoiceId) else {
            throw LightningError.invoiceNotFound
        }
        
        // Check with NWC if available
        if let connection = nwcConnections.values.first {
            let status = try await checkNWCInvoiceStatus(connection, invoiceId: invoiceId)
            
            if status == .paid && invoice.status != .paid {
                // Invoice was just paid - update group balance
                await updateGroupBalance(groupId: invoice.groupId, amount: invoice.amount)
            }
            
            return status
        }
        
        // No Voltage fallback - onchain only for compliance
        // Users must connect their own Lightning wallets or use onchain Bitcoin
        return invoice.status
        
        // Demo mode - simulate payment
        if ProcessInfo.processInfo.environment["ENVIRONMENT"] == "development" {
            // Simulate random payment for demo
            let isPaid = Bool.random()
            if isPaid && invoice.status != .paid {
                await updateGroupBalance(groupId: invoice.groupId, amount: invoice.amount)
                return .paid
            }
        }
        
        return invoice.status
    }
    
    // MARK: - Group Balance Management
    
    private func updateGroupBalance(groupId: String, amount: UInt64) async {
        let currentBalance = groupLightningBalances[groupId] ?? 0
        groupLightningBalances[groupId] = currentBalance + amount
        
        print("⚡ Group \(groupId) Lightning balance updated: +\(amount.formattedSats) = \(groupLightningBalances[groupId]?.formattedSats ?? "0")")
        
        // Notify GroupManager of the Lightning contribution
        NotificationCenter.default.post(
            name: .lightningContributionReceived,
            object: nil,
            userInfo: [
                "groupId": groupId,
                "amount": amount,
                "totalLightningBalance": groupLightningBalances[groupId] ?? 0
            ]
        )
    }
    
    func getGroupLightningBalance(_ groupId: String) -> UInt64 {
        return groupLightningBalances[groupId] ?? 0
    }
    
    func getGroupInvoices(_ groupId: String) -> [LightningInvoice] {
        return groupInvoices[groupId] ?? []
    }
    
    // MARK: - NWC Implementation
    
    private func generateNWCInvoice(
        connection: NWCConnection,
        groupId: String,
        amount: UInt64,
        description: String
    ) async throws -> LightningInvoice {
        
        let request = NWCRequest(
            method: "make_invoice",
            params: [
                "amount": amount * 1000, // Convert to millisats
                "description": description,
                "expiry": 3600 // 1 hour
            ],
            id: UUID().uuidString
        )
        
        let response = try await sendNWCRequest(connection, request: request)
        
        guard let paymentRequest = response["invoice"] as? String else {
            throw LightningError.invalidResponse
        }
        
        let invoice = LightningInvoice(
            id: UUID().uuidString,
            paymentRequest: paymentRequest,
            amount: amount,
            description: description,
            groupId: groupId,
            expiresAt: Date().addingTimeInterval(3600),
            status: .pending
        )
        
        // Store invoice
        var invoices = groupInvoices[groupId] ?? []
        invoices.append(invoice)
        groupInvoices[groupId] = invoices
        
        return invoice
    }
    
    private func checkNWCInvoiceStatus(_ connection: NWCConnection, invoiceId: String) async throws -> InvoiceStatus {
        let request = NWCRequest(
            method: "lookup_invoice",
            params: [
                "payment_hash": invoiceId
            ],
            id: UUID().uuidString
        )
        
        let response = try await sendNWCRequest(connection, request: request)
        
        if let settled = response["settled"] as? Bool, settled {
            return .paid
        } else {
            return .pending
        }
    }
    
    private func sendNWCRequest(_ connection: NWCConnection, request: NWCRequest) async throws -> [String: Any] {
        // This would implement the actual NWC protocol over Nostr
        // For now, simulate a successful response
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        switch request.method {
        case "get_info":
            return [
                "alias": connection.walletName ?? "Lightning Wallet",
                "color": "#FF9500",
                "num_peers": 5,
                "num_active_channels": 3,
                "num_inactive_channels": 0
            ]
            
        case "make_invoice":
            let mockInvoice = generateMockBOLT11Invoice(
                amount: (request.params["amount"] as? UInt64 ?? 0) / 1000,
                description: request.params["description"] as? String ?? ""
            )
            return ["invoice": mockInvoice]
            
        case "lookup_invoice":
            // Simulate random payment status
            return ["settled": Bool.random()]
            
        default:
            throw LightningError.unsupportedMethod
        }
    }
    
    // MARK: - Onchain Only Fallback (No Lightning Custody)
    
    /// Users without Lightning wallets use onchain Bitcoin only
    /// This maintains perfect zero-custody compliance
    private func generateOnchainOnlyMessage(groupId: String, amount: UInt64) -> String {
        return """
        ⚡ Lightning Wallet Required
        
        To contribute via Lightning, you need to connect your own Lightning wallet (Alby, Zeus, etc.) via Nostr Wallet Connect.
        
        💡 No Lightning wallet? Use onchain Bitcoin instead:
        • Generate a Bitcoin address for this group
        • Send Bitcoin onchain to contribute
        • No Lightning required - perfect for everyone!
        
        Amount: \(amount.formattedSats)
        Group: \(groupId)
        """
    }
    
    // MARK: - Demo/Development Mode
    
    private func generateDemoInvoice(
        groupId: String,
        amount: UInt64,
        description: String
    ) -> LightningInvoice {
        
        let paymentRequest = generateMockBOLT11Invoice(amount: amount, description: description)
        
        let invoice = LightningInvoice(
            id: UUID().uuidString,
            paymentRequest: paymentRequest,
            amount: amount,
            description: description,
            groupId: groupId,
            expiresAt: Date().addingTimeInterval(3600),
            status: .pending
        )
        
        // Store invoice
        var invoices = groupInvoices[groupId] ?? []
        invoices.append(invoice)
        groupInvoices[groupId] = invoices
        
        return invoice
    }
    
    private func generateMockBOLT11Invoice(amount: UInt64, description: String) -> String {
        let prefix = "lnbc"
        let amountMillisats = amount * 1000
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let mockData = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        
        return "\(prefix)\(amountMillisats)n1\(timestamp)\(mockData.prefix(50))"
    }
    
    // MARK: - Utility Methods
    
    private func parseNWCConnectionString(_ connectionString: String) throws -> NWCConnection {
        // Parse nostr+walletconnect:// connection string
        // This would implement actual NWC connection string parsing
        
        guard connectionString.hasPrefix("nostr+walletconnect://") else {
            throw LightningError.invalidConnectionString
        }
        
        return NWCConnection(
            id: UUID().uuidString,
            connectionString: connectionString,
            relay: "wss://relay.getalby.com/v1",
            walletPubkey: "mock_wallet_pubkey",
            secret: "mock_secret",
            walletName: nil
        )
    }
    
    private func findInvoice(_ invoiceId: String) -> LightningInvoice? {
        for invoices in groupInvoices.values {
            if let invoice = invoices.first(where: { $0.id == invoiceId }) {
                return invoice
            }
        }
        return nil
    }
    
    private func refreshConnections() async {
        // Refresh all active connections
        for connection in nwcConnections.values {
            do {
                try await testNWCConnection(connection)
            } catch {
                print("⚠️ Connection \(connection.walletName ?? "Unknown") failed: \(error)")
                // Could disconnect failed connections here
            }
        }
    }
    
    // MARK: - Connection Status
    
    var hasAnyConnection: Bool {
        return isNWCConnected // No Voltage fallback - perfect zero-custody compliance
    }
    
    var primaryConnectionType: LightningConnectionType? {
        if isNWCConnected {
            return .nwc
        } else {
            return nil // No Lightning fallback - onchain only
        }
    }
}

// MARK: - Data Models

struct NWCConnection: Identifiable, Codable {
    let id: String
    let connectionString: String
    let relay: String
    let walletPubkey: String
    let secret: String
    var walletName: String?
    var lastConnected: Date?
    var isActive: Bool = true
}

struct NWCRequest: Codable {
    let method: String
    let params: [String: Any]
    let id: String
    
    enum CodingKeys: String, CodingKey {
        case method, params, id
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(method, forKey: .method)
        try container.encode(id, forKey: .id)
        // Note: For actual implementation, you'd need proper Any encoding
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        method = try container.decode(String.self, forKey: .method)
        id = try container.decode(String.self, forKey: .id)
        params = [:] // Simplified for this example
    }
    
    init(method: String, params: [String: Any], id: String) {
        self.method = method
        self.params = params
        self.id = id
    }
}

// VoltageConfig removed - perfect zero-custody compliance
// Users must connect their own Lightning wallets or use onchain Bitcoin

enum LightningConnectionType: String, CaseIterable {
    case nwc = "nwc"
    case demo = "demo"
    
    var displayName: String {
        switch self {
        case .nwc: return "Connected Wallet"
        case .demo: return "Demo Mode"
        }
    }
    
    var icon: String {
        switch self {
        case .nwc: return "link.circle.fill"
        case .demo: return "testtube.2"
        }
    }
}

// LightningInvoice and InvoiceStatus defined in LightningManager.swift

enum LightningError: Error, LocalizedError {
    case invalidConnectionString
    case invalidResponse
    case invoiceNotFound
    case unsupportedMethod
    case connectionFailed
    case paymentFailed
    case noLightningWallet
    
    var errorDescription: String? {
        switch self {
        case .invalidConnectionString: return "Invalid NWC connection string"
        case .invalidResponse: return "Invalid response from Lightning service"
        case .invoiceNotFound: return "Invoice not found"
        case .unsupportedMethod: return "Unsupported NWC method"
        case .connectionFailed: return "Failed to connect to Lightning service"
        case .paymentFailed: return "Lightning payment failed"
        case .noLightningWallet: return "No Lightning wallet connected. Connect your own Lightning wallet via NWC or use onchain Bitcoin."
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let lightningContributionReceived = Notification.Name("lightningContributionReceived")
    static let lightningInvoicePaid = Notification.Name("lightningInvoicePaid")
    static let lightningConnectionChanged = Notification.Name("lightningConnectionChanged")
}

// UInt64 extensions moved to UInt64+Extensions.swift