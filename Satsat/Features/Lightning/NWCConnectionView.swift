// NWCConnectionView.swift
// User interface for connecting Lightning wallets via Nostr Wallet Connect (NWC)

import SwiftUI
import Combine

// MARK: - NWC Connection View

struct NWCConnectionView: View {
    @EnvironmentObject var nwcLightningManager: NWCLightningManager
    @Environment(\.dismiss) var dismiss
    
    @State private var connectionString = ""
    @State private var walletName = ""
    @State private var isConnecting = false
    @State private var showingQRScanner = false
    @State private var showingInstructions = false
    @State private var selectedWallet: SupportedWallet?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: SatsatDesignSystem.Spacing.xl) {
                    // Header
                    headerSection
                    
                    // Connection status
                    if nwcLightningManager.isNWCConnected {
                        connectedStatusSection
                    } else {
                        connectionFormSection
                    }
                    
                    // Supported wallets
                    supportedWalletsSection
                    
                    // Instructions
                    instructionsSection
                    
                    Spacer(minLength: SatsatDesignSystem.Spacing.xl)
                }
                .padding(SatsatDesignSystem.Spacing.lg)
            }
            .background(SatsatDesignSystem.Colors.backgroundPrimary)
            .navigationTitle("Connect Lightning Wallet")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Help") {
                        showingInstructions = true
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingQRScanner) {
            CameraQRScannerView { scannedString in
                if scannedString.hasPrefix("nostr+walletconnect://") {
                    connectionString = scannedString
                    showingQRScanner = false
                    HapticFeedback.success()
                } else {
                    HapticFeedback.error()
                }
            }
        }
        .sheet(isPresented: $showingInstructions) {
            NWCInstructionsView()
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(SatsatDesignSystem.Colors.lightning)
            
            Text("Connect Your Lightning Wallet")
                .font(SatsatDesignSystem.Typography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("Use Nostr Wallet Connect (NWC) to securely connect your existing Lightning wallet. Your keys stay in your wallet - Satsat never has custody. No Lightning wallet? Use onchain Bitcoin instead!")
                .font(SatsatDesignSystem.Typography.body)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var connectedStatusSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(SatsatDesignSystem.Colors.success)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wallet Connected")
                        .font(SatsatDesignSystem.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Text(nwcLightningManager.connectedWalletName ?? "Lightning Wallet")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.md) {
                ForEach(nwcLightningManager.activeConnections) { connection in
                    ConnectionRow(connection: connection) {
                        nwcLightningManager.disconnectNWC(connection.id)
                        HapticFeedback.light()
                    }
                }
            }
        }
        .padding(SatsatDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                .fill(SatsatDesignSystem.Colors.success.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                        .stroke(SatsatDesignSystem.Colors.success.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var connectionFormSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            // Wallet name input
            VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.sm) {
                Text("Wallet Name")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                TextField("e.g., My Alby Wallet", text: $walletName)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
            }
            
            // Connection string input
            VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.sm) {
                Text("NWC Connection String")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                HStack {
                    TextField("nostr+walletconnect://...", text: $connectionString)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button(action: {
                        showingQRScanner = true
                        HapticFeedback.light()
                    }) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title3)
                            .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                    }
                    .padding(.leading, SatsatDesignSystem.Spacing.sm)
                }
            }
            
            // Connect button
            Button("Connect Wallet") {
                connectWallet()
            }
            .satsatPrimaryButton(isLoading: isConnecting)
            .disabled(connectionString.isEmpty || walletName.isEmpty || isConnecting)
            
            // Alternative connection methods
            VStack(spacing: SatsatDesignSystem.Spacing.md) {
                Text("Or scan QR code from your wallet")
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                
                Button("Scan QR Code") {
                    showingQRScanner = true
                    HapticFeedback.light()
                }
                .satsatSecondaryButton()
            }
        }
        .padding(SatsatDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                .fill(SatsatDesignSystem.Colors.backgroundCard)
        )
    }
    
    private var supportedWalletsSection: some View {
        VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.lg) {
            Text("Supported Lightning Wallets")
                .font(SatsatDesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: SatsatDesignSystem.Spacing.md) {
                ForEach(SupportedWallet.allCases, id: \.self) { wallet in
                    WalletCard(wallet: wallet) {
                        selectedWallet = wallet
                        // Could open wallet-specific instructions
                    }
                }
            }
        }
    }
    
    private var instructionsSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(SatsatDesignSystem.Colors.info)
                
                Text("How It Works")
                    .font(SatsatDesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.sm) {
                NWCInstructionStep(
                    number: 1,
                    text: "Open your Lightning wallet (Alby, Zeus, etc.)"
                )
                
                NWCInstructionStep(
                    number: 2,
                    text: "Look for 'Nostr Wallet Connect' or 'NWC' settings"
                )
                
                NWCInstructionStep(
                    number: 3,
                    text: "Copy the connection string or show QR code"
                )
                
                NWCInstructionStep(
                    number: 4,
                    text: "Paste or scan the connection in Satsat"
                )
                
                NWCInstructionStep(
                    number: 5,
                    text: "No Lightning wallet? Use onchain Bitcoin instead!"
                )
            }
        }
        .padding(SatsatDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                .fill(SatsatDesignSystem.Colors.info.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                        .stroke(SatsatDesignSystem.Colors.info.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Actions
    
    private func connectWallet() {
        guard !connectionString.isEmpty && !walletName.isEmpty else { return }
        
        isConnecting = true
        
        Task {
            do {
                try await nwcLightningManager.connectNWC(
                    connectionString: connectionString,
                    walletName: walletName
                )
                
                await MainActor.run {
                    isConnecting = false
                    HapticFeedback.success()
                }
                
            } catch {
                await MainActor.run {
                    isConnecting = false
                    HapticFeedback.error()
                    // Could show error alert here
                }
            }
        }
    }
}

// MARK: - Supporting Components

struct ConnectionRow: View {
    let connection: NWCConnection
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack(spacing: SatsatDesignSystem.Spacing.md) {
            Image(systemName: "link.circle.fill")
                .font(.title3)
                .foregroundColor(SatsatDesignSystem.Colors.lightning)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(connection.walletName ?? "Lightning Wallet")
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                if let lastConnected = connection.lastConnected {
                    Text("Connected \(lastConnected.formatted(date: .abbreviated, time: .shortened))")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            Button("Disconnect") {
                onDisconnect()
            }
            .font(SatsatDesignSystem.Typography.caption)
            .foregroundColor(SatsatDesignSystem.Colors.error)
        }
        .padding(SatsatDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                .fill(SatsatDesignSystem.Colors.backgroundSecondary)
        )
    }
}

struct WalletCard: View {
    let wallet: SupportedWallet
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                Image(systemName: wallet.icon)
                    .font(.title2)
                    .foregroundColor(wallet.color)
                
                Text(wallet.name)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(wallet.description)
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(SatsatDesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                    .fill(SatsatDesignSystem.Colors.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                            .stroke(wallet.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct NWCInstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: SatsatDesignSystem.Spacing.md) {
            Text("\(number)")
                .font(SatsatDesignSystem.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(SatsatDesignSystem.Colors.info)
                )
            
            Text(text)
                .font(SatsatDesignSystem.Typography.subheadline)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            
            Spacer()
        }
    }
}

// MARK: - Supported Wallets

enum SupportedWallet: String, CaseIterable {
    case alby = "alby"
    case zeus = "zeus"
    case mutiny = "mutiny"
    case phoenixd = "phoenixd"
    case lnbits = "lnbits"
    // No voltage case - perfect zero-custody compliance
    
    var name: String {
        switch self {
        case .alby: return "Alby"
        case .zeus: return "Zeus"
        case .mutiny: return "Mutiny"
        case .phoenixd: return "phoenixd"
        case .lnbits: return "LNbits"
        // case .voltage: return "Voltage" // Removed for zero-custody compliance
        }
    }
    
    var description: String {
        switch self {
        case .alby: return "Browser extension & mobile"
        case .zeus: return "Mobile Lightning node"
        case .mutiny: return "Self-custodial web wallet"
        case .phoenixd: return "Self-hosted Lightning"
        case .lnbits: return "Open source Lightning"
        // case .voltage: return "Hosted Lightning node" // Removed for zero-custody compliance
        }
    }
    
    var icon: String {
        switch self {
        case .alby: return "globe.badge.chevron.backward"
        case .zeus: return "iphone"
        case .mutiny: return "network"
        case .phoenixd: return "server.rack"
        // case .voltage: return "server.rack" // Removed for zero-custody compliance
        case .lnbits: return "square.grid.2x2"
        // case .voltage: return "bolt.circle" // Removed for zero-custody compliance
        }
    }
    
    var color: Color {
        switch self {
        case .alby: return .orange
        case .zeus: return .blue
        case .mutiny: return .purple
        case .phoenixd: return .green
        case .lnbits: return .yellow
        // case .voltage: return .red // Removed for zero-custody compliance
        }
    }
}

// MARK: - NWC Instructions View

struct NWCInstructionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.lg) {
                    Text("Nostr Wallet Connect (NWC)")
                        .font(SatsatDesignSystem.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    instructionsSection(
                        title: "What is NWC?",
                        content: "Nostr Wallet Connect allows apps to securely request Lightning payments from your wallet without giving up custody of your Bitcoin."
                    )
                    
                    instructionsSection(
                        title: "How it works",
                        content: "Your wallet generates a special connection string that allows Satsat to request invoices. You approve each request in your wallet."
                    )
                    
                    instructionsSection(
                        title: "Security",
                        content: "Your private keys never leave your wallet. Satsat can only request invoices - you control all payments. No Lightning wallet? Use onchain Bitcoin - no custody, no control, perfect compliance!"
                    )
                    
                    instructionsSection(
                        title: "Alby Setup",
                        content: "1. Open Alby extension\n2. Go to Settings > Connections\n3. Click 'Add Connection'\n4. Select 'Nostr Wallet Connect'\n5. Copy the connection string"
                    )
                    
                    instructionsSection(
                        title: "Zeus Setup",
                        content: "1. Open Zeus app\n2. Go to Settings > Lightning > NWC\n3. Create new connection\n4. Set app permissions\n5. Share QR code or connection string"
                    )
                }
                .padding(SatsatDesignSystem.Spacing.lg)
            }
            .background(SatsatDesignSystem.Colors.backgroundPrimary)
            .navigationTitle("NWC Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func instructionsSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.sm) {
            Text(title)
                .font(SatsatDesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
            
            Text(content)
                .font(SatsatDesignSystem.Typography.body)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NWCConnectionView()
        .environmentObject(NWCLightningManager.shared)
}