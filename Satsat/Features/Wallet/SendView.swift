// SendView.swift
// Bitcoin send interface with PSBT creation for Satsat groups

import SwiftUI

// MARK: - Send View

struct SendView: View {
    @EnvironmentObject var groupManager: GroupManager
    @EnvironmentObject var psbtManager: PSBTManager
    @Environment(\.dismiss) var dismiss
    
    let group: SavingsGroup
    
    @State private var recipientAddress = ""
    @State private var amountSats = ""
    @State private var purpose: TransactionPurpose = .goalWithdrawal
    @State private var notes = ""
    @State private var customFeeRate = ""
    @State private var selectedFeeSpeed: FeeSpeed = .medium
    @State private var showingConfirmation = false
    @State private var showingQRScanner = false
    @State private var isCreatingTransaction = false
    @State private var showingAdvancedOptions = false
    @State private var useCustomFee = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: SatsatDesignSystem.Spacing.lg) {
                    // Header with balance
                    balanceSection
                    
                    // Recipient section
                    recipientSection
                    
                    // Amount section
                    amountSection
                    
                    // Purpose section
                    purposeSection
                    
                    // Fee selection
                    feeSection
                    
                    // Advanced options
                    if showingAdvancedOptions {
                        advancedOptionsSection
                    }
                    
                    // Notes
                    notesSection
                    
                    // Action buttons
                    actionButtonsSection
                    
                    Spacer(minLength: SatsatDesignSystem.Spacing.xl)
                }
                .padding(SatsatDesignSystem.Spacing.md)
            }
            .background(SatsatDesignSystem.Colors.backgroundPrimary)
            .navigationTitle("Send Bitcoin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(showingAdvancedOptions ? "Simple" : "Advanced") {
                        withAnimation {
                            showingAdvancedOptions.toggle()
                        }
                        HapticFeedback.light()
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingQRScanner) {
            QRScannerView { scannedText in
                processScannedAddress(scannedText)
            }
        }
        .alert("Create Transaction?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                createTransaction()
            }
        } message: {
            Text("This will create a transaction requiring \(group.requiredSignatures) signatures from group members.")
        }
    }
    
    // MARK: - View Sections
    
    private var balanceSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack(spacing: SatsatDesignSystem.Spacing.sm) {
                SatsatAvatar(
                    name: group.displayName,
                    color: "#FF9500",
                    size: 32
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.displayName)
                        .font(SatsatDesignSystem.Typography.headline)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Text("\(group.multisigConfig.displayName) Wallet")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            Divider()
                .background(SatsatDesignSystem.Colors.backgroundTertiary)
            
            VStack(spacing: 8) {
                Text("Available Balance")
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                
                BitcoinAmountView(
                    amount: group.currentBalance,
                    style: .large,
                    alignment: .center
                )
                
                if !group.isGoalReached {
                    SatsatStatusBadge(text: "Goal in Progress", style: .warning)
                }
            }
        }
        .satsatCard()
    }
    
    private var recipientSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack {
                Text("Send To")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button("Scan QR") {
                    showingQRScanner = true
                    HapticFeedback.light()
                }
                .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                .font(SatsatDesignSystem.Typography.caption)
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                TextField("Bitcoin address or Lightning invoice", text: $recipientAddress)
                    .textFieldStyle(SatsatTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                if let addressType = detectAddressType(recipientAddress) {
                    HStack {
                        Image(systemName: addressType.icon)
                            .foregroundColor(addressType.color)
                        
                        Text(addressType.description)
                            .font(SatsatDesignSystem.Typography.caption)
                            .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                        
                        Spacer()
                        
                        SatsatStatusBadge(text: addressType.isValid ? "Valid" : "Invalid", style: addressType.isValid ? .success : .error)
                    }
                }
            }
        }
        .satsatCard()
    }
    
    private var amountSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack {
                Text("Amount")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                if let sats = UInt64(amountSats), sats > 0 {
                    BitcoinAmountView(amount: sats, style: .small)
                }
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                TextField("Amount in satoshis", text: $amountSats)
                    .textFieldStyle(SatsatTextFieldStyle())
                    .keyboardType(.numberPad)
                
                // Quick amount buttons
                HStack(spacing: SatsatDesignSystem.Spacing.sm) {
                    ForEach(quickAmounts, id: \.self) { amount in
                        Button(amount.label) {
                            amountSats = String(amount.sats)
                            HapticFeedback.light()
                        }
                        .font(SatsatDesignSystem.Typography.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(SatsatDesignSystem.Colors.backgroundSecondary)
                        )
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    }
                    
                    Spacer()
                }
                
                // Validation
                if let sats = UInt64(amountSats), sats > group.currentBalance {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(SatsatDesignSystem.Colors.error)
                        
                        Text("Amount exceeds available balance")
                            .font(SatsatDesignSystem.Typography.caption)
                            .foregroundColor(SatsatDesignSystem.Colors.error)
                        
                        Spacer()
                    }
                }
            }
        }
        .satsatCard()
    }
    
    private var purposeSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack {
                Text("Transaction Purpose")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                ForEach(TransactionPurpose.allCases, id: \.self) { purposeOption in
                    PurposeSelectionButton(
                        purpose: purposeOption,
                        isSelected: purpose == purposeOption,
                        group: group
                    ) {
                        purpose = purposeOption
                        HapticFeedback.light()
                    }
                }
            }
        }
        .satsatCard()
    }
    
    private var feeSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack {
                Text("Network Fee")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text(estimatedFeeText)
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                // Fee speed selector
                HStack(spacing: SatsatDesignSystem.Spacing.sm) {
                    ForEach(FeeSpeed.allCases, id: \.self) { speed in
                        FeeSpeedButton(
                            speed: speed,
                            isSelected: selectedFeeSpeed == speed && !useCustomFee
                        ) {
                            selectedFeeSpeed = speed
                            useCustomFee = false
                            HapticFeedback.light()
                        }
                    }
                }
                
                // Custom fee toggle
                Toggle("Custom Fee Rate", isOn: $useCustomFee)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    .toggleStyle(SatsatToggleStyle())
                
                if useCustomFee {
                    TextField("Fee rate (sat/vB)", text: $customFeeRate)
                        .textFieldStyle(SatsatTextFieldStyle())
                        .keyboardType(.numberPad)
                }
            }
        }
        .satsatCard()
    }
    
    private var advancedOptionsSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack {
                Text("Advanced Options")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.md) {
                // UTXO selection (placeholder)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coin Selection")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Text("Automatic selection of unspent outputs")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    SatsatStatusBadge(text: "Auto", style: .info)
                }
                
                // RBF toggle
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Replace-by-Fee (RBF)", isOn: .constant(true))
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                        .toggleStyle(SatsatToggleStyle())
                        .disabled(true)
                    
                    Text("Allows fee bumping if transaction is delayed")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
            }
        }
        .satsatCard()
    }
    
    private var notesSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack {
                Text("Notes (Optional)")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            TextField("Add a note for group members...", text: $notes, axis: .vertical)
                .textFieldStyle(SatsatTextFieldStyle())
                .lineLimit(3...6)
        }
        .satsatCard()
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            Button("Create Transaction") {
                showingConfirmation = true
                HapticFeedback.medium()
            }
            .satsatPrimaryButton(isLoading: isCreatingTransaction)
            .disabled(!isValidTransaction || isCreatingTransaction)
            
            if !group.isGoalReached {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(SatsatDesignSystem.Colors.warning)
                        
                        Text("Group goal not yet reached")
                            .font(SatsatDesignSystem.Typography.caption)
                            .foregroundColor(SatsatDesignSystem.Colors.warning)
                        
                        Spacer()
                    }
                    
                    Text("You can still send Bitcoin, but consider reaching your savings goal first.")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(SatsatDesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                        .fill(SatsatDesignSystem.Colors.warning.opacity(0.1))
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isValidTransaction: Bool {
        guard !recipientAddress.isEmpty,
              let sats = UInt64(amountSats),
              sats > 0,
              sats <= group.currentBalance,
              detectAddressType(recipientAddress)?.isValid == true else {
            return false
        }
        return true
    }
    
    private var estimatedFeeText: String {
        let baseFee = useCustomFee 
            ? (Int(customFeeRate) ?? 0) 
            : selectedFeeSpeed.feeRate
        
        let estimatedSats = baseFee * 140 // Rough estimate for multisig transaction
        return "≈\(estimatedSats) sats"
    }
    
    private var quickAmounts: [QuickAmount] {
        let tenPercent = group.currentBalance / 10
        let twentyFivePercent = group.currentBalance / 4
        let fiftyPercent = group.currentBalance / 2
        
        return [
            QuickAmount(label: "10%", sats: tenPercent),
            QuickAmount(label: "25%", sats: twentyFivePercent),
            QuickAmount(label: "50%", sats: fiftyPercent)
        ].filter { $0.sats > 0 }
    }
    
    // MARK: - Actions
    
    private func createTransaction() {
        guard let amountSats = UInt64(amountSats) else { return }
        
        isCreatingTransaction = true
        
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
                    isCreatingTransaction = false
                    dismiss()
                }
                
                HapticFeedback.success()
                
            } catch {
                await MainActor.run {
                    isCreatingTransaction = false
                    // Handle error
                }
                
                HapticFeedback.error()
            }
        }
    }
    
    private func processScannedAddress(_ scannedText: String) {
        recipientAddress = scannedText
        HapticFeedback.success()
    }
    
    private func detectAddressType(_ address: String) -> AddressInfo? {
        guard !address.isEmpty else { return nil }
        
        if address.lowercased().hasPrefix("bc1") {
            return AddressInfo(type: "Bech32", description: "Native SegWit address", isValid: true, icon: "lock.shield", color: SatsatDesignSystem.Colors.success)
        } else if address.hasPrefix("1") {
            return AddressInfo(type: "Legacy", description: "Legacy Bitcoin address", isValid: true, icon: "bitcoinsign.circle", color: SatsatDesignSystem.Colors.warning)
        } else if address.hasPrefix("3") {
            return AddressInfo(type: "P2SH", description: "Pay-to-Script-Hash address", isValid: true, icon: "lock.rectangle", color: SatsatDesignSystem.Colors.info)
        } else if address.lowercased().hasPrefix("lnbc") {
            return AddressInfo(type: "Lightning", description: "Lightning Network invoice", isValid: true, icon: "bolt.fill", color: SatsatDesignSystem.Colors.lightning)
        } else {
            return AddressInfo(type: "Unknown", description: "Invalid address format", isValid: false, icon: "exclamationmark.triangle", color: SatsatDesignSystem.Colors.error)
        }
    }
}

// MARK: - Supporting Components and Types

struct AddressInfo {
    let type: String
    let description: String
    let isValid: Bool
    let icon: String
    let color: Color
}

struct QuickAmount: Hashable {
    let label: String
    let sats: UInt64
}

enum FeeSpeed: String, CaseIterable {
    case slow = "Slow"
    case medium = "Medium"
    case fast = "Fast"
    
    var feeRate: Int {
        switch self {
        case .slow: return 1
        case .medium: return 5
        case .fast: return 20
        }
    }
    
    var estimatedTime: String {
        switch self {
        case .slow: return "60+ min"
        case .medium: return "10-30 min"
        case .fast: return "<10 min"
        }
    }
    
    var color: Color {
        switch self {
        case .slow: return SatsatDesignSystem.Colors.success
        case .medium: return SatsatDesignSystem.Colors.warning
        case .fast: return SatsatDesignSystem.Colors.error
        }
    }
}

struct FeeSpeedButton: View {
    let speed: FeeSpeed
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(speed.rawValue)
                    .font(SatsatDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                
                Text(speed.estimatedTime)
                    .font(.caption2)
                
                Text("\(speed.feeRate) sat/vB")
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white : SatsatDesignSystem.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.small)
                    .fill(isSelected ? speed.color : SatsatDesignSystem.Colors.backgroundSecondary)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PurposeSelectionButton: View {
    let purpose: TransactionPurpose
    let isSelected: Bool
    let group: SavingsGroup
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: SatsatDesignSystem.Spacing.md) {
                Text(purpose.icon)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(purpose.displayName)
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Text(purposeDescription(for: purpose))
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(SatsatDesignSystem.Colors.success)
                }
            }
            .padding(SatsatDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                    .fill(SatsatDesignSystem.Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                            .stroke(
                                isSelected ? SatsatDesignSystem.Colors.satsatOrange : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func purposeDescription(for purpose: TransactionPurpose) -> String {
        switch purpose {
        case .goalWithdrawal:
            return group.isGoalReached ? "Congratulations! Your goal is reached." : "Goal not yet reached"
        case .emergencyWithdrawal:
            return "Urgent withdrawal with high priority"
        case .partialWithdrawal:
            return "Withdraw part of your savings"
        case .rebalancing:
            return "Move funds to another wallet"
        case .testing:
            return "Small test transaction"
        }
    }
}

// MARK: - Custom Text Field Style

struct SatsatTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(SatsatDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                    .fill(SatsatDesignSystem.Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                            .stroke(SatsatDesignSystem.Colors.backgroundTertiary, lineWidth: 1)
                    )
            )
            .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
    }
}

// MARK: - Custom Toggle Style

struct SatsatToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? SatsatDesignSystem.Colors.satsatOrange : SatsatDesignSystem.Colors.backgroundTertiary)
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                )
                .onTapGesture {
                    configuration.isOn.toggle()
                    HapticFeedback.light()
                }
        }
    }
}

// MARK: - QR Scanner

struct QRScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        CameraQRScannerView { scannedCode in
            onScan(scannedCode)
        }
    }
}

// MARK: - Preview

#Preview {
    SendView(group: SavingsGroup.sampleGroup)
        .environmentObject(GroupManager.shared)
        .environmentObject(PSBTManager.shared)
}