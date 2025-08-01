//
//  ContentView.swift
//  Satsat
//
//  Created by Kiwi_ on 7/31/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var coreDataManager: CoreDataManager
    @EnvironmentObject var nostrClient: NostrClient
    @EnvironmentObject var biometricAuth: BiometricAuthManager
    @EnvironmentObject var groupManager: GroupManager
    @EnvironmentObject var psbtManager: PSBTManager
    
    @State private var selectedTab = 0
    @State private var showingGroupCreation = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Groups Dashboard
            DashboardView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Groups")
                }
                .tag(0)
            
            // Settings
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(1)
        }
        .accentColor(.orange)
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var nostrClient: NostrClient
    @EnvironmentObject var groupManager: GroupManager
    @EnvironmentObject var psbtManager: PSBTManager
    @State private var showingCreateGroup = false
    @State private var showingGroupDetail = false
    @State private var selectedGroup: SavingsGroup?
    @State private var showingWalletDetail = false
    @State private var selectedWallet: SavingsGroup?
    @State private var walletSearchText = ""
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical) {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Your Savings Groups")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Build Bitcoin wealth with trusted friends")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Connection status
                    ConnectionStatusCard()
                    
                    // Pending signatures alert
                    if !psbtManager.pendingSignatures.isEmpty {
                        PendingSignaturesCard()
                    }
                    
                    // Create group button
                    Button(action: { showingCreateGroup = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create New Group")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                    
                    // Manage Groups header
                    if !groupManager.activeGroups.isEmpty {
                        Text("Manage Groups")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Wallet search and cards section
                    if !groupManager.activeGroups.isEmpty {
                        walletCardsSection
                    }
                    
                    // Groups list or placeholder
                    if groupManager.activeGroups.isEmpty && !groupManager.isLoading {
                        // Placeholder content
                        VStack(spacing: 16) {
                            Image(systemName: "person.2.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.gray)
                            
                            Text("No Groups Yet")
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Text("Create your first savings group or join one using an invite link from a friend.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                    } else {
                        // Removed duplicate groups list - wallets are now accessible via cards above
                    }
                    
                    if groupManager.isLoading {
                        ProgressView("Loading groups...")
                            .padding()
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .background(SatsatDesignSystem.Colors.backgroundSecondary)
            .navigationBarHidden(true)
            .refreshable {
                groupManager.loadGroups()
            }
        }
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupView()
                .environmentObject(groupManager)
        }
        .sheet(item: $selectedGroup) { group in
            GroupDetailView(group: group)
                .environmentObject(groupManager)
                .environmentObject(psbtManager)
        }
        .sheet(item: $selectedWallet) { wallet in
            WalletDetailView(group: wallet)
                .environmentObject(groupManager)
                .environmentObject(psbtManager)
        }
        .onAppear {
            if groupManager.activeGroups.isEmpty {
                groupManager.loadGroups()
            }
        }
    }
    
    // MARK: - Wallet Cards Section
    
    private var walletCardsSection: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search wallets...", text: $walletSearchText)
                    .padding()
                    .background(SatsatDesignSystem.Colors.backgroundSecondary)
                    .foregroundColor(.white)
                    .accentColor(.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white, lineWidth: 1)
                    )
                    .onAppear {
                        // Set placeholder color to white
                        UITextField.appearance().attributedPlaceholder = NSAttributedString(
                            string: "Search wallets...",
                            attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.6)]
                        )
                    }
            }
            .padding(.horizontal)
            
            // Filtered wallets
            let filteredWallets = groupManager.activeGroups.filter { group in
                walletSearchText.isEmpty || group.displayName.localizedCaseInsensitiveContains(walletSearchText)
            }
            
            if !filteredWallets.isEmpty {
                if filteredWallets.count == 1 {
                    // Center single wallet
                    HStack {
                        Spacer()
                        WalletCard(group: filteredWallets[0])
                            .frame(width: 280, height: 160)
                            .onTapGesture {
                                selectedWallet = filteredWallets[0]
                                showingWalletDetail = true
                                HapticFeedback.medium()
                            }
                        Spacer()
                    }
                    .padding(.horizontal)
                } else {
                    // Horizontal scroll for multiple wallets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(filteredWallets) { wallet in
                                WalletCard(group: wallet)
                                    .frame(width: 280, height: 160)
                                    .onTapGesture {
                                        selectedWallet = wallet
                                        showingWalletDetail = true
                                        HapticFeedback.medium()
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            } else if !walletSearchText.isEmpty {
                Text("No wallets found")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

// MARK: - Connection Status Card

struct ConnectionStatusCard: View {
    @EnvironmentObject var nostrClient: NostrClient
    
    var body: some View {
        HStack {
            Image(systemName: nostrClient.isConnected ? "wifi" : "wifi.slash")
                .foregroundColor(nostrClient.isConnected ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Network Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(nostrClient.networkHealth.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(nostrClient.networkHealth.color)
            }
            
            Spacer()
            
            if nostrClient.isConnected {
                Text("\(nostrClient.activeRelays.count) relays")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Wallet Card

struct WalletCard: View {
    let group: SavingsGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if group.members.count == 1 {
                        Text("Single Signature")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(group.multisigConfig.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(group.currentBalance) sats")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Goal: \(group.goal.targetAmountSats) sats")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: Double(group.currentBalance), total: Double(group.goal.targetAmountSats))
                    .tint(.orange)
                
                HStack {
                    Text("\(Int((Double(group.currentBalance) / Double(group.goal.targetAmountSats)) * 100))% complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(group.members.count) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(SatsatDesignSystem.Colors.backgroundPrimary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#FF9500"), lineWidth: 1)
        )
    }
}

// MARK: - Wallet Detail View

struct WalletDetailView: View {
    @EnvironmentObject var groupManager: GroupManager
    @EnvironmentObject var psbtManager: PSBTManager
    @Environment(\.dismiss) var dismiss
    // TODO: Implement wallet manager
    
    let group: SavingsGroup
    @State private var showingReceive = false
    @State private var showingSend = false
    @State private var showingXPubImport = false
    
    private var canTransact: Bool {
        if group.members.count == 1 {
            // Single sig: need user's key
            return group.members.first?.xpub != nil && !group.members.first!.xpub!.isEmpty
        } else {
            // Multisig: need all members' keys and wallet created
            return group.members.allSatisfy { $0.xpub != nil && !$0.xpub!.isEmpty }
        }
    }
    
    private var canSend: Bool {
        // Send requires both key import AND non-zero balance
        return canTransact && group.currentBalance > 0
    }
        
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Wallet Overview
                    walletOverviewSection
                    
                    // Manage Keys Section
                    manageKeysSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Recent Transactions
                    recentTransactionsSection
                    
                    // Messages Section (only for multi-person groups)
                    if group.members.count > 1 {
                        messagesSection
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle(group.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back", action: { dismiss() })
                        .foregroundColor(.orange)
                }
            }
            .onAppear {
                // TODO: Implement wallet sync
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("groupDataUpdated"))) { notification in
                if let groupId = notification.object as? String, groupId == group.id {
                    // Force UI refresh by refreshing the GroupManager which will update the view
                    print("🔄 Received group data update notification for \(groupId)")
                    DispatchQueue.main.async {
                        groupManager.objectWillChange.send()
                        print("✅ Wallet view refreshed via GroupManager update")
                    }
                }
            }
        }
        .sheet(isPresented: $showingReceive) {
            ReceiveView(group: group)
                .environmentObject(groupManager)
        }
        .sheet(isPresented: $showingSend) {
            SendView(group: group)
                .environmentObject(groupManager)
                .environmentObject(psbtManager)
        }
        .sheet(isPresented: $showingXPubImport) {
            if let currentMember = group.members.first {
                XPubImportView(group: group)
                    .environmentObject(groupManager)
            } else {
                Text("Error: No members in group")
            }
        }
    }
    
    private var walletOverviewSection: some View {
        VStack(spacing: 16) {
            balanceSection
            progressSection
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var balanceSection: some View {
        VStack(spacing: 8) {
            Text("Balance")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(group.currentBalance) sats")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Goal: \(group.goal.targetAmountSats) sats")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(Int((Double(group.currentBalance) / Double(group.goal.targetAmountSats)) * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            ProgressView(value: Double(group.currentBalance), total: Double(group.goal.targetAmountSats))
                .tint(.orange)
                .scaleEffect(y: 2)
        }
    }
    
    private var manageKeysSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Manage Keys")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if group.members.count == 1 {
                // Single sig key management
                singleSigKeySection
            } else {
                // Multisig key management
                multisigKeySection
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var singleSigKeySection: some View {
        VStack(spacing: 12) {
            if let member = group.members.first, member.xpub != nil && !member.xpub!.isEmpty {
                // Key uploaded
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Single-sig key uploaded")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                }
            } else {
                // Need to upload key
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Upload your hardware wallet key")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                Button("Import Key") {
                    showingXPubImport = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
    }
    
    private var multisigKeySection: some View {
        VStack(spacing: 12) {
            ForEach(group.members, id: \.id) { member in
                HStack {
                    Circle()
                        .fill(member.xpub != nil && !member.xpub!.isEmpty ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)
                    
                    Text(member.displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if member.xpub != nil && !member.xpub!.isEmpty {
                        Text("Key uploaded")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Needs key")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if !canTransact {
                Button("Import Your Key") {
                    showingXPubImport = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else {
                Button("Generate Multisig Wallet") {
                    // TODO: Implement multisig wallet generation
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            // Balance scanning indicator
            // TODO: Implement wallet syncing indicator
            
            HStack(spacing: 16) {
                Button(action: { showingReceive = true }) {
                    VStack {
                        Image(systemName: "qrcode")
                            .font(.title2)
                        Text("Receive")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canTransact ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .foregroundColor(canTransact ? .green : .gray)
                    .cornerRadius(12)
                }
                .disabled(!canTransact)
                
                Button(action: { showingSend = true }) {
                    VStack {
                        Image(systemName: "paperplane")
                            .font(.title2)
                        Text("Send")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSend ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
                    .foregroundColor(canSend ? .orange : .gray)
                    .cornerRadius(12)
                }
                .disabled(!canSend)
            }
        }
    }
    
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transactions")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("No transactions yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Group Messages")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Recent group messages will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}


// MARK: - Placeholder Views

struct WalletView: View {
    @EnvironmentObject var groupManager: GroupManager
    @EnvironmentObject var psbtManager: PSBTManager
    @State private var selectedGroup: SavingsGroup?
    @State private var showingReceiveView = false
    @State private var showingSendView = false
    @State private var showingTransactionHistory = false
    @State private var showingPSBTSigning = false
    @State private var selectedPSBT: GroupPSBT?
    
    var body: some View {
        NavigationView {
            if groupManager.activeGroups.isEmpty {
                VStack(spacing: SatsatDesignSystem.Spacing.lg) {
                    Image(systemName: "bitcoinsign.circle")
                        .font(.system(size: 80))
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Text("No Wallet Available")
                        .font(SatsatDesignSystem.Typography.title2)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Text("Create or join a savings group to access your Bitcoin wallet.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Button("View Groups") {
                        // Switch to groups tab
                    }
                    .satsatPrimaryButton()
                    .padding(.horizontal)
                }
                .padding()
                .navigationTitle("Wallet")
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: SatsatDesignSystem.Spacing.lg) {
                        // Group selector if multiple groups
                        if groupManager.activeGroups.count > 1 {
                            groupSelectorSection
                        }
                        
                        if let group = selectedGroup ?? groupManager.activeGroups.first {
                            // Wallet overview
                            walletOverviewSection(for: group)
                            
                            // Quick actions
                            quickActionsSection(for: group)
                            
                            // Recent transactions
                            recentTransactionsSection(for: group)
                            
                            // Group progress
                            groupProgressSection(for: group)
                        }
                        
                        Spacer(minLength: SatsatDesignSystem.Spacing.xl)
                    }
                    .padding(SatsatDesignSystem.Spacing.md)
                }
                .background(SatsatDesignSystem.Colors.backgroundSecondary)
                .navigationTitle("Wallet")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Transaction History") {
                                showingTransactionHistory = true
                            }
                            
                            Button("Export Wallet") {
                                // Export functionality
                            }
                            
                            Button("Wallet Settings") {
                                // Settings
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingReceiveView) {
            if let group = selectedGroup ?? groupManager.activeGroups.first {
                ReceiveView(group: group)
                    .environmentObject(groupManager)
            }
        }
        .sheet(isPresented: $showingSendView) {
            if let group = selectedGroup ?? groupManager.activeGroups.first {
                SendView(group: group)
                    .environmentObject(groupManager)
                    .environmentObject(psbtManager)
            }
        }
        .sheet(isPresented: $showingTransactionHistory) {
            if let group = selectedGroup ?? groupManager.activeGroups.first {
                TransactionHistoryView(group: group)
                    .environmentObject(psbtManager)
            }
        }
        .sheet(isPresented: $showingPSBTSigning) {
            if let psbt = selectedPSBT {
                PSBTSigningView(psbt: psbt)
                    .environmentObject(psbtManager)
                    .environmentObject(groupManager)
            }
        }
        .onAppear {
            if selectedGroup == nil && !groupManager.activeGroups.isEmpty {
                selectedGroup = groupManager.activeGroups.first
            }
        }
    }
    
    // MARK: - View Sections
    
    private var groupSelectorSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack {
                Text("Select Wallet")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SatsatDesignSystem.Spacing.sm) {
                    ForEach(groupManager.activeGroups) { group in
                        WalletSelectorButton(
                            group: group,
                            isSelected: selectedGroup?.id == group.id
                        ) {
                            selectedGroup = group
                            HapticFeedback.light()
                        }
                    }
                }
                .padding(.horizontal, SatsatDesignSystem.Spacing.md)
            }
        }
        .satsatCard()
    }
    
    private func walletOverviewSection(for group: SavingsGroup) -> some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            // Group header
            HStack(spacing: SatsatDesignSystem.Spacing.sm) {
                SatsatAvatar(
                    name: group.displayName,
                    color: "#FF9500",
                    size: 40
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.displayName)
                        .font(SatsatDesignSystem.Typography.title3)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Text("\(group.multisigConfig.displayName) • \(group.activeMembers.count) members")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                if group.isGoalReached {
                    SatsatStatusBadge(text: "Goal Reached", style: .success)
                }
            }
            
            Divider()
                .background(SatsatDesignSystem.Colors.backgroundTertiary)
            
            // Progress Circle (Satsat style)
            HStack(spacing: SatsatDesignSystem.Spacing.lg) {
                // Progress Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: min(group.goalProgress, 1.0))
                        .stroke(.blue, lineWidth: 8)
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: group.goalProgress)
                    
                    Text("\(Int(group.goalProgress * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                }
                
                // Balance info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Balance")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    BitcoinAmountView(
                        amount: group.currentBalance,
                        style: .medium,
                        alignment: .leading
                    )
                    
                    Text("Goal: \(group.goal.targetAmountSats) sats")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            Divider()
                .background(SatsatDesignSystem.Colors.backgroundTertiary)
            
            // Manage Keys Section
            VStack {
                Text("Manage Keys")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .satsatCard()
    }
    
    private func quickActionsSection(for group: SavingsGroup) -> some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack {
                Text("Quick Actions")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            HStack(spacing: SatsatDesignSystem.Spacing.md) {
                // Receive button
                Button(action: {
                    showingReceiveView = true
                    HapticFeedback.medium()
                }) {
                    VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title)
                            .foregroundColor(SatsatDesignSystem.Colors.success)
                        
                        Text("Receive")
                            .font(SatsatDesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SatsatDesignSystem.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                            .fill(SatsatDesignSystem.Colors.backgroundSecondary)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Send button
                Button(action: {
                    showingSendView = true
                    HapticFeedback.medium()
                }) {
                    VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                        
                        Text("Send")
                            .font(SatsatDesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SatsatDesignSystem.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                            .fill(SatsatDesignSystem.Colors.backgroundSecondary)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .satsatCard()
    }
    
    private func recentTransactionsSection(for group: SavingsGroup) -> some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack {
                Text("Recent Transactions")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button("View All") {
                    showingTransactionHistory = true
                }
                .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                .font(SatsatDesignSystem.Typography.caption)
            }
            
            // Transaction list (mock data for now)
            VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                if psbtManager.activePSBTs.filter({ $0.groupId == group.id }).isEmpty {
                    VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                        Image(systemName: "doc.text")
                            .font(.title2)
                            .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                        
                        Text("No recent transactions")
                            .font(SatsatDesignSystem.Typography.caption)
                            .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, SatsatDesignSystem.Spacing.lg)
                } else {
                    ForEach(psbtManager.activePSBTs.filter { $0.groupId == group.id }.prefix(3), id: \.id) { psbt in
                        TransactionRow(psbt: psbt)
                            .onTapGesture {
                                selectedPSBT = psbt
                                showingPSBTSigning = true
                                HapticFeedback.light()
                            }
                    }
                }
            }
        }
        .satsatCard()
    }
    
    private func groupProgressSection(for group: SavingsGroup) -> some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack {
                Text("Savings Progress")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("\(Int(group.progressPercentage * 100))%")
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(group.progressColor)
            }
            
            SatsatProgressBar(progress: group.progressPercentage, height: 12)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Goal")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Text(group.goal.targetAmountSats.formattedSats)
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Text(group.remainingAmount.formattedSats)
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                }
            }
        }
        .satsatCard()
    }
}

// MARK: - Supporting Components

struct WalletSelectorButton: View {
    let group: SavingsGroup
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                SatsatAvatar(
                    name: group.displayName,
                    color: "#FF9500",
                    size: 32
                )
                
                Text(group.displayName)
                    .font(SatsatDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, SatsatDesignSystem.Spacing.sm)
            .padding(.vertical, SatsatDesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                    .fill(isSelected ? SatsatDesignSystem.Colors.satsatOrange.opacity(0.2) : SatsatDesignSystem.Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                            .stroke(isSelected ? SatsatDesignSystem.Colors.satsatOrange : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TransactionRow: View {
    let psbt: GroupPSBT
    
    var body: some View {
        HStack(spacing: SatsatDesignSystem.Spacing.md) {
            // Transaction icon
            Image(systemName: transactionIcon)
                .font(.title3)
                .foregroundColor(transactionColor)
                .frame(width: 32)
            
            // Transaction details
            VStack(alignment: .leading, spacing: 2) {
                Text(psbt.purpose.displayName)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Text(psbt.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Amount and status
            VStack(alignment: .trailing, spacing: 2) {
                Text(psbt.amount.formattedSats)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                SatsatStatusBadge(text: psbt.status.rawValue.capitalized, style: statusStyle)
            }
        }
        .padding(.vertical, SatsatDesignSystem.Spacing.sm)
    }
    
    private var transactionIcon: String {
        switch psbt.status {
        case .pendingSignatures, .readyToBroadcast:
            return "signature"
        case .broadcasted, .confirmed:
            return "arrow.up.circle.fill"
        case .failed, .cancelled:
            return "exclamationmark.triangle"
        }
    }
    
    private var transactionColor: Color {
        switch psbt.status {
        case .pendingSignatures, .readyToBroadcast:
            return SatsatDesignSystem.Colors.warning
        case .broadcasted, .confirmed:
            return SatsatDesignSystem.Colors.success
        case .failed, .cancelled:
            return SatsatDesignSystem.Colors.error
        }
    }
    
    private var statusStyle: SatsatStatusBadge.BadgeStyle {
        switch psbt.status {
        case .pendingSignatures, .readyToBroadcast:
            return .warning
        case .broadcasted, .confirmed:
            return .success
        case .failed, .cancelled:
            return .error
        }
    }
}

// MARK: - Transaction History View (Placeholder)

struct TransactionHistoryView: View {
    let group: SavingsGroup
    @EnvironmentObject var psbtManager: PSBTManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(psbtManager.activePSBTs.filter { $0.groupId == group.id }, id: \.id) { psbt in
                    TransactionRow(psbt: psbt)
                        .listRowBackground(SatsatDesignSystem.Colors.backgroundCard)
                }
            }
            .background(SatsatDesignSystem.Colors.backgroundSecondary)
            .navigationTitle("Transaction History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct MessagesView: View {
    @EnvironmentObject var groupManager: GroupManager
    @EnvironmentObject var messageManager: MessageManager
    @State private var selectedGroup: SavingsGroup?
    @State private var showingGroupSelection = false
    
    var body: some View {
        NavigationView {
            if groupManager.activeGroups.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "message.badge")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("No Group Messages")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Create or join a savings group to start messaging with your friends.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button("View Groups") {
                        // Switch to groups tab
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding()
                .navigationTitle("Messages")
            } else {
                VStack(spacing: 0) {
                    // Group selector
                    GroupSelectorBar()
                    
                    if let selectedGroup = selectedGroup {
                        GroupChatView(group: selectedGroup)
                            .environmentObject(messageManager)
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Select a Group")
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Text("Choose a savings group to view messages and coordinate with your friends.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                .navigationTitle("Messages")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Groups") {
                            showingGroupSelection = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingGroupSelection) {
            GroupSelectionSheet(selectedGroup: $selectedGroup)
                .environmentObject(groupManager)
        }
        .onAppear {
            if selectedGroup == nil && !groupManager.activeGroups.isEmpty {
                selectedGroup = groupManager.activeGroups.first
            }
        }
    }
}

// MARK: - Group Selector Bar

struct GroupSelectorBar: View {
    @EnvironmentObject var groupManager: GroupManager
    @EnvironmentObject var messageManager: MessageManager
    @State private var selectedGroupId: String?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(groupManager.activeGroups) { group in
                    GroupSelectorButton(
                        group: group,
                        isSelected: selectedGroupId == group.id,
                        unreadCount: messageManager.unreadCounts[group.id] ?? 0
                    ) {
                        selectedGroupId = group.id
                        messageManager.markAsRead(groupId: group.id)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .onAppear {
            if selectedGroupId == nil && !groupManager.activeGroups.isEmpty {
                selectedGroupId = groupManager.activeGroups.first?.id
            }
        }
    }
}

struct GroupSelectorButton: View {
    let group: SavingsGroup
    let isSelected: Bool
    let unreadCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Group avatar
                Circle()
                    .fill(group.goal.category.emoji.isEmpty ? Color.orange : Color.clear)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(group.goal.category.emoji.isEmpty ?
                             String(group.displayName.prefix(1)).uppercased() :
                             group.goal.category.emoji)
                            .font(.headline)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text("\(group.activeMembers.count) members")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.orange.opacity(0.2) : Color.clear)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsView: View {
    @EnvironmentObject var biometricAuth: BiometricAuthManager
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text("User")
                                .fontWeight(.medium)
                            Text("Tap to edit profile")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(SatsatDesignSystem.Colors.backgroundSecondary)
                } header: {
                    Text("Profile")
                }
                
                Section {
                    HStack {
                        Image(systemName: biometricAuth.biometricType == .faceID ? "faceid" : "touchid")
                            .foregroundColor(.green)
                        Text("Biometric Security")
                        Spacer()
                        Text(biometricAuth.isAvailable ? "Enabled" : "Unavailable")
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(SatsatDesignSystem.Colors.backgroundSecondary)
                    
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.blue)
                        Text("Auto-Lock")
                        Spacer()
                        Text("5 minutes")
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(SatsatDesignSystem.Colors.backgroundSecondary)
                } header: {
                    Text("Security")
                }
                
                Section {
                    Text("Satsat v1.0.0")
                        .foregroundColor(.white)
                        .listRowBackground(SatsatDesignSystem.Colors.backgroundSecondary)
                } header: {
                    Text("About")
                }
            }
            .listStyle(PlainListStyle())
            .background(SatsatDesignSystem.Colors.backgroundSecondary)
            .navigationTitle("Settings")
        }
        .background(SatsatDesignSystem.Colors.backgroundSecondary)
    }
}

enum WalletType: String, CaseIterable {
    case singleSig = "Single Signature"
    case multiSig = "Multi Signature"
}

struct CreateGroupView: View {
    @EnvironmentObject var groupManager: GroupManager
    @Environment(\.dismiss) var dismiss
    
    @State private var groupName = ""
    @State private var goalTitle = ""
    @State private var goalDescription = ""
    @State private var goalAmount = ""
    @State private var goalCategory: GoalCategory = .general
    @State private var selectedThreshold = 1
    @State private var maxMembers = 1
    @State private var walletType: WalletType = .singleSig
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Enter group name", text: $groupName)
                    
                    TextField("Goal amount (sats)", text: $goalAmount)
                        .keyboardType(.numberPad)
                        .onChange(of: goalAmount) { newValue in
                            // Filter out non-numeric characters
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                goalAmount = filtered
                            }
                            
                            // Add comma formatting
                            if let number = Int(filtered), number > 0 {
                                let formatter = NumberFormatter()
                                formatter.numberStyle = .decimal
                                if let formatted = formatter.string(from: NSNumber(value: number)) {
                                    if formatted != goalAmount {
                                        goalAmount = formatted
                                    }
                                }
                            }
                        }
                    
                    Picker("Category", selection: $goalCategory) {
                        ForEach(GoalCategory.allCases, id: \.self) { category in
                            Text("\(category.emoji) \(category.displayName)")
                        }
                    }
                } header: {
                    Text("Group & Goal Details")
                }
                
                Section {
                    Picker("Wallet Type", selection: $walletType) {
                        ForEach(WalletType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .onChange(of: walletType) { newType in
                        switch newType {
                        case .singleSig:
                            maxMembers = 1
                            selectedThreshold = 1
                        case .multiSig:
                            maxMembers = 3
                            selectedThreshold = 2
                        }
                    }
                    
                    if walletType == .multiSig {
                        Picker("Required signatures", selection: $selectedThreshold) {
                            ForEach(2...max(2, maxMembers), id: \.self) { threshold in
                                Text("\(threshold) of \(maxMembers)")
                            }
                        }
                        .onChange(of: maxMembers) { newValue in
                            let safeMaxMembers = max(2, newValue)
                            if selectedThreshold < 2 {
                                selectedThreshold = 2
                            }
                            if selectedThreshold > safeMaxMembers {
                                selectedThreshold = safeMaxMembers
                            }
                        }
                        
                        Stepper("Max members: \(maxMembers)", value: $maxMembers, in: 3...9)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if walletType == .singleSig {
                            Text("Security Level: Individual Control")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text("You have complete control over this single-signature wallet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Security Level: \(MultisigConfig(threshold: selectedThreshold, totalSigners: maxMembers).securityLevel.description)")
                                .font(.caption)
                                .foregroundColor(MultisigConfig(threshold: selectedThreshold, totalSigners: maxMembers).securityLevel.color)
                            
                            Text("This means \(selectedThreshold) out of \(maxMembers) members must approve every transaction.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                } header: {
                    Text("Security Configuration")
                }
                
                Section {
                    Button("Create Group") {
                        createGroup()
                    }
                    .disabled(groupName.isEmpty || goalAmount.isEmpty || isCreating)
                    
                    if walletType == .singleSig {
                        Text("Note: Single-signature wallet will be ready for key import after creation.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Note: Multisig wallet will be created once \(selectedThreshold) members have joined and uploaded keys.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if isCreating {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Creating group...")
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text("After creation, you can invite friends using a secure link. All transactions will require \(selectedThreshold) signatures.")
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
            }
        }
        .alert("Error Creating Group", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createGroup() {
        // Prevent multiple rapid button presses
        guard !isCreating else { return }
        
        // Parse amount removing commas
        let cleanedAmount = goalAmount.replacingOccurrences(of: ",", with: "")
        guard let goalAmountSats = UInt64(cleanedAmount) else {
            errorMessage = "Please enter a valid goal amount"
            showingError = true
            return
        }
        
        isCreating = true
        
        let goal = GroupGoal(
            title: groupName,
            description: "Group savings goal",
            targetAmountSats: goalAmountSats,
            category: goalCategory
        )
        
        Task {
            do {
                print("🔍 Creating group with:")
                print("  - Name: '\(groupName)'")
                print("  - Goal title: '\(goal.title)'")
                print("  - Goal description: '\(goal.description)'")
                print("  - Target amount: \(goal.targetAmountSats)")
                print("  - Category: \(goal.category)")
                
                let _ = try await groupManager.createGroup(
                    name: groupName,
                    goal: goal,
                    threshold: selectedThreshold,
                    maxMembers: maxMembers
                )
                
                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isCreating = false
                    print("❌ Group creation failed with error: \(error)")
                    print("❌ Error type: \(type(of: error))")
                    print("❌ Error localized description: \(error.localizedDescription)")
                    if let nsError = error as? NSError {
                        print("❌ NSError domain: \(nsError.domain)")
                        print("❌ NSError code: \(nsError.code)")
                        print("❌ NSError userInfo: \(nsError.userInfo)")
                    }
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// Extension for placeholder text
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - New UI Components

struct PendingSignaturesCard: View {
    @EnvironmentObject var psbtManager: PSBTManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "signature")
                    .foregroundColor(.orange)
                Text("Signatures Required")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(psbtManager.pendingSignatures.count)")
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            Text("You have transactions waiting for your signature.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Review & Sign") {
                // TODO: Show PSBT signing view
            }
            .font(.caption)
            .foregroundColor(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct GroupCard: View {
    let group: SavingsGroup
    @State private var animateProgress = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.md) {
            // Header with avatars
            HStack(spacing: SatsatDesignSystem.Spacing.sm) {
                // Group icon/emoji
                Circle()
                    .fill(SatsatDesignSystem.Colors.satsatOrange.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(group.goal.category.emoji.isEmpty ?
                             String(group.displayName.prefix(1)).uppercased() :
                             group.goal.category.emoji)
                            .font(SatsatDesignSystem.Typography.headline)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.displayName)
                        .font(SatsatDesignSystem.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Text("\(group.activeMembers.count) members • \(group.multisigConfig.displayName)")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Status badge
                if group.isGoalReached {
                    SatsatStatusBadge(text: "Complete", style: .success)
                        .pulse(scale: 1.05, opacity: 0.9, duration: 2.0)
                }
            }
            
            // Balance section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Balance")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    BitcoinAmountView(amount: group.currentBalance, style: .medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Goal")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Text(group.goal.targetAmountSats.formattedSats)
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                }
            }
            
            // Enhanced progress section
            VStack(spacing: 8) {
                HStack {
                    Text(group.goal.title)
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    AnimatedNumberView(
                        value: group.progressPercentage * 100,
                        format: "%.0f%%",
                        duration: 1.0
                    )
                    .font(SatsatDesignSystem.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(group.progressColor)
                }
                
                SatsatProgressBar(
                    progress: animateProgress ? group.progressPercentage : 0,
                    height: 10,
                    showPercentage: false
                )
                .animation(SatsatAnimations.progressBar.delay(0.3), value: animateProgress)
            }
            
            // Action hint
            HStack {
                Image(systemName: "hand.tap")
                    .font(.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                
                Text("Tap to view details")
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
            }
        }
        .satsatCard()
        .onAppear {
            // Trigger progress animation after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animateProgress = true
            }
        }
    }
}

struct GroupDetailView: View {
    @ObservedObject var group: SavingsGroup
    @EnvironmentObject var groupManager: GroupManager
    @EnvironmentObject var psbtManager: PSBTManager
    @Environment(\.dismiss) var dismiss
    @State private var showingCreateTransaction = false
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical) {
                VStack(spacing: 24) {
                    // Group header
                    VStack(spacing: 16) {
                        Text(group.displayName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        // Balance and goal
                        VStack(spacing: 8) {
                            Text(group.currentBalance.formattedSats)
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            
                            Text("of \(group.goal.targetAmountSats.formattedSats) goal")
                                .foregroundColor(.secondary)
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 16)
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(group.progressColor)
                                    .frame(width: geometry.size.width * group.progressPercentage, height: 16)
                            }
                        }
                        .frame(height: 16)
                        
                        if group.isGoalReached {
                            Text("🎉 Congratulations! Goal reached!")
                                .font(.headline)
                                .foregroundColor(.green)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        Button("Receive") {
                            // TODO: Show receive address
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        
                        Button("Send") {
                            showingCreateTransaction = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(!group.isGoalReached) // Only allow sending when goal is reached
                    }
                    
                    // Members section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Members (\(group.activeMembers.count))")
                            .font(.headline)
                        
                        ForEach(group.activeMembers) { member in
                            MemberRow(member: member)
                        }
                    }
                    
                    // Goal details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Goal Details")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(group.goal.category.emoji) \(group.goal.title)")
                                .fontWeight(.medium)
                            
                            if !group.goal.description.isEmpty {
                                Text(group.goal.description)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh Balance") {
                            Task {
                                await groupManager.updateGroupBalance(group.id)
                            }
                        }
                        
                        Button("Group Settings") {
                            // TODO: Show group settings
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateTransaction) {
            CreateTransactionView(group: group)
                .environmentObject(psbtManager)
        }
    }
}

struct MemberRow: View {
    let member: GroupMember
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: member.avatarColor))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(member.displayName.prefix(1)).uppercased())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .fontWeight(.medium)
                
                HStack {
                    Text(member.role.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                    
                    if member.isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Online")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            if member.contributionAmount > 0 {
                Text(member.contributionAmount.formattedSats)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreateTransactionView: View {
    let group: SavingsGroup
    @EnvironmentObject var psbtManager: PSBTManager
    @Environment(\.dismiss) var dismiss
    
    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var purpose: TransactionPurpose = .goalWithdrawal
    @State private var notes = ""
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Bitcoin Address", text: $recipientAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    TextField("Amount (sats)", text: $amount)
                        .keyboardType(.numberPad)
                    
                    Picker("Purpose", selection: $purpose) {
                        ForEach(TransactionPurpose.allCases, id: \.self) { purpose in
                            Text("\(purpose.icon) \(purpose.displayName)")
                        }
                    }
                    
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    
                } header: {
                    Text("Transaction Details")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Balance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(group.currentBalance.formattedSats)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                } header: {
                    Text("Group Wallet")
                }
                
                Section {
                    Button("Create Transaction") {
                        showingConfirmation = true
                    }
                    .disabled(recipientAddress.isEmpty || amount.isEmpty)
                } footer: {
                    Text("This transaction will require \(group.requiredSignatures) signatures from group members.")
                }
            }
            .navigationTitle("Send Bitcoin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Create Transaction?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                createTransaction()
            }
        } message: {
            Text("This will create a transaction requiring signatures from \(group.requiredSignatures) group members.")
        }
    }
    
    private func createTransaction() {
        guard let amountSats = UInt64(amount) else { return }
        
        Task {
            do {
                let _ = try await psbtManager.createPSBT(
                    for: group.id,
                    to: recipientAddress,
                    amount: amountSats,
                    purpose: purpose,
                    notes: notes.isEmpty ? nil : notes
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to create transaction: \(error)")
            }
        }
    }
}

// Color extensions moved to SatsatDesignSystem.swift

// MARK: - Group Chat Interface

struct GroupChatView: View {
    let group: SavingsGroup
    @EnvironmentObject var messageManager: MessageManager
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var messages: [GroupMessage] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Message input
            MessageInputView(
                messageText: $messageText,
                isLoading: isLoading
            ) {
                sendMessage()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(group.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(group.activeMembers.count) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            loadMessages()
        }
        .onReceive(messageManager.$groupMessages) { groupMessages in
            if let groupMessages = groupMessages[group.id] {
                self.messages = groupMessages
            }
        }
    }
    
    private func loadMessages() {
        Task {
            await messageManager.loadMessages(for: group.id)
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                try await messageManager.sendMessage(messageText, to: group.id)
                
                await MainActor.run {
                    messageText = ""
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Handle error
                    print("Failed to send message: \(error)")
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: GroupMessage
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer(minLength: 50)
                
                VStack(alignment: .trailing, spacing: 4) {
                    messageContent
                    timeStamp
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        // Sender avatar
                        Circle()
                            .fill(Color.orange.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(message.senderName.prefix(1)).uppercased())
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            )
                        
                        messageContent
                    }
                    
                    HStack {
                        Text(message.senderName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        timeStamp
                    }
                    .padding(.leading, 40)
                }
                
                Spacer(minLength: 50)
            }
        }
    }
    
    private var messageContent: some View {
        VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            if message.messageType == .psbt {
                PSBTMessageContent(message: message)
            } else {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.isFromCurrentUser
                            ? Color.orange
                            : Color(.systemGray5)
                    )
                    .foregroundColor(
                        message.isFromCurrentUser
                            ? .white
                            : .primary
                    )
                    .cornerRadius(16)
            }
        }
    }
    
    private var timeStamp: some View {
        Text(message.formattedTime)
            .font(.caption2)
            .foregroundColor(.secondary)
    }
}

struct PSBTMessageContent: View {
    let message: GroupMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "signature")
                    .foregroundColor(.orange)
                Text("Transaction Signature Request")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Text("A transaction requires your signature")
                .font(.subheadline)
            
            Button("Review & Sign") {
                // Handle PSBT signing
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct MessageInputView: View {
    @Binding var messageText: String
    let isLoading: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Text input
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(1...5)
                .disabled(isLoading)
            
            // Send button
            Button(action: onSend) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
            }
            .foregroundColor(.orange)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct GroupSelectionSheet: View {
    @Binding var selectedGroup: SavingsGroup?
    @EnvironmentObject var groupManager: GroupManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(groupManager.activeGroups) { group in
                    Button(action: {
                        selectedGroup = group
                        dismiss()
                    }) {
                        HStack {
                            Circle()
                                .fill(Color.orange.opacity(0.7))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(group.goal.category.emoji.isEmpty ?
                                         String(group.displayName.prefix(1)).uppercased() :
                                         group.goal.category.emoji)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.displayName)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("\(group.activeMembers.count) members • \(group.goal.formattedTarget)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedGroup?.id == group.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CoreDataManager.shared)
        .environmentObject(NostrClient.shared)
        .environmentObject(BiometricAuthManager.shared)
        .environmentObject(GroupManager.shared)
        .environmentObject(PSBTManager.shared)
        .environmentObject(MessageManager.shared)
}
