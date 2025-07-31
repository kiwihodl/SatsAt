// LightningDepositView.swift
// Lightning Network deposit interface for instant Bitcoin contributions

import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Lightning Deposit View

struct LightningDepositView: View {
    @EnvironmentObject var lightningManager: LightningManager
    @EnvironmentObject var groupManager: GroupManager
    @Environment(\.dismiss) var dismiss
    
    let group: SavingsGroup
    
    @State private var selectedAmount: UInt64 = 0
    @State private var customAmount = ""
    @State private var generatedInvoice: LightningInvoice?
    @State private var qrCodeImage: UIImage?
    @State private var isGeneratingInvoice = false
    @State private var showingInvoiceDetail = false
    @State private var selectedTab: DepositTab = .quickAmounts
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Tab selector
                tabSelectorSection
                
                // Content based on selected tab
                ScrollView {
                    VStack(spacing: SatsatDesignSystem.Spacing.lg) {
                        switch selectedTab {
                        case .quickAmounts:
                            quickAmountsSection
                        case .custom:
                            customAmountSection
                        case .invoice:
                            invoiceSection
                        }
                        
                        Spacer(minLength: SatsatDesignSystem.Spacing.xl)
                    }
                    .padding(SatsatDesignSystem.Spacing.md)
                }
                
                // Action buttons
                actionButtonsSection
            }
            .background(SatsatDesignSystem.Colors.backgroundPrimary)
            .navigationTitle("Lightning Deposit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Info") {
                        // Show Lightning info
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingInvoiceDetail) {
            if let invoice = generatedInvoice {
                LightningInvoiceDetailView(invoice: invoice, qrImage: qrCodeImage)
                    .environmentObject(lightningManager)
            }
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            // Group info
            HStack(spacing: SatsatDesignSystem.Spacing.sm) {
                SatsatAvatar(
                    name: group.displayName,
                    color: "#FFD700",
                    size: 40
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.displayName)
                        .font(SatsatDesignSystem.Typography.title3)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Text("Lightning Deposit")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundColor(SatsatDesignSystem.Colors.lightning)
            }
            
            // Lightning benefits
            HStack(spacing: SatsatDesignSystem.Spacing.lg) {
                BenefitItem(icon: "bolt", title: "Instant", description: "Immediate deposits")
                BenefitItem(icon: "dollarsign.circle", title: "Low Fees", description: "Minimal costs")
                BenefitItem(icon: "lock.shield", title: "Secure", description: "Same security")
            }
        }
        .satsatCard()
    }
    
    private var tabSelectorSection: some View {
        HStack(spacing: 0) {
            ForEach(DepositTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                    HapticFeedback.light()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        
                        Text(tab.title)
                            .font(SatsatDesignSystem.Typography.caption)
                    }
                    .foregroundColor(selectedTab == tab ? SatsatDesignSystem.Colors.lightning : SatsatDesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SatsatDesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                            .fill(selectedTab == tab ? SatsatDesignSystem.Colors.lightning.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(SatsatDesignSystem.Spacing.sm)
        .background(SatsatDesignSystem.Colors.backgroundCard)
        .cornerRadius(SatsatDesignSystem.Radius.large)
        .padding(.horizontal, SatsatDesignSystem.Spacing.md)
    }
    
    private var quickAmountsSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            // Quick amount grid
            quickAmountGrid
            
            // Progress context
            progressContextCard
            
            // Recent Lightning activity
            recentActivityCard
        }
    }
    
    private var quickAmountGrid: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Text("Quick Amounts")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: SatsatDesignSystem.Spacing.md) {
                ForEach(quickAmounts, id: \.amount) { quickAmount in
                    QuickAmountButton(
                        amount: quickAmount,
                        isSelected: selectedAmount == quickAmount.amount,
                        group: group
                    ) {
                        selectedAmount = quickAmount.amount
                        HapticFeedback.medium()
                    }
                }
            }
        }
        .satsatCard()
    }
    
    private var customAmountSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            // Custom amount input
            customAmountCard
            
            // Amount preview
            if let amount = customAmount.parsedAsBitcoin, amount > 0 {
                amountPreviewCard(amount: amount)
            }
            
            // Lightning limits info
            lightningLimitsCard
        }
    }
    
    private var customAmountCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Text("Custom Amount")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                TextField("Enter amount in satoshis", text: $customAmount)
                    .textFieldStyle(LightningTextFieldStyle())
                    .keyboardType(.numberPad)
                    .onChange(of: customAmount) { newValue in
                        if let amount = newValue.parsedAsBitcoin {
                            selectedAmount = amount
                        }
                    }
                
                // Quick amount shortcuts
                HStack(spacing: SatsatDesignSystem.Spacing.sm) {
                    ForEach(quickDepositAmounts, id: \.self) { amount in
                        Button(amount.label) {
                            customAmount = String(amount.sats)
                            selectedAmount = amount.sats
                            HapticFeedback.light()
                        }
                        .font(SatsatDesignSystem.Typography.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(SatsatDesignSystem.Colors.backgroundSecondary)
                        )
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    }
                    
                    Spacer()
                }
            }
        }
        .satsatCard()
    }
    
    private var invoiceSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            if let invoice = generatedInvoice {
                // Generated invoice display
                generatedInvoiceCard(invoice: invoice)
            } else {
                // Invoice generation placeholder
                invoiceGenerationCard
            }
            
            // Active invoices
            activeInvoicesCard
        }
    }
    
    private func amountPreviewCard(amount: UInt64) -> some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Text("Deposit Preview")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.md) {
                HStack {
                    Text("Amount:")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    BitcoinAmountView(amount: amount, style: .medium)
                }
                
                HStack {
                    Text("Lightning Fee:")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("~1-10 sats")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.success)
                }
                
                HStack {
                    Text("Settlement:")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("Instant")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(SatsatDesignSystem.Colors.lightning)
                }
            }
        }
        .satsatCard()
    }
    
    private var progressContextCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Text("Your Progress")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("\(Int(group.progressPercentage * 100))%")
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(group.progressColor)
            }
            
            SatsatProgressBar(progress: group.progressPercentage, height: 8)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Text(group.currentBalance.formattedSats)
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
    
    private var recentActivityCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(SatsatDesignSystem.Colors.lightning)
                
                Text("Recent Lightning Activity")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            if lightningManager.paymentHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.horizontal")
                        .font(.title)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Text("No Lightning activity yet")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                .padding(.vertical, SatsatDesignSystem.Spacing.lg)
            } else {
                VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                    ForEach(lightningManager.paymentHistory.prefix(3), id: \.id) { payment in
                        LightningPaymentRow(payment: payment)
                    }
                }
            }
        }
        .satsatCard()
    }
    
    private var lightningLimitsCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(SatsatDesignSystem.Colors.info)
                
                Text("Lightning Limits")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.sm) {
                LimitInfoRow(label: "Minimum", value: "1 sat", icon: "arrow.down")
                LimitInfoRow(label: "Maximum", value: "0.21 BTC", icon: "arrow.up")
                LimitInfoRow(label: "Fee Range", value: "1-10 sats", icon: "dollarsign.circle")
                LimitInfoRow(label: "Settlement", value: "Instant", icon: "bolt.fill")
            }
        }
        .satsatCard()
    }
    
    private func generatedInvoiceCard(invoice: LightningInvoice) -> some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Text("Lightning Invoice")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                SatsatStatusBadge(text: invoice.status.rawValue.capitalized, style: .info)
            }
            
            // QR Code
            if let qrImage = qrCodeImage {
                VStack(spacing: 16) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .background(Color.white)
                        .cornerRadius(SatsatDesignSystem.Radius.medium)
                    
                    Text("Scan with Lightning wallet")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
            }
            
            // Invoice details
            VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                HStack {
                    Text("Amount:")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text(invoice.amount.formattedSats)
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(SatsatDesignSystem.Colors.lightning)
                }
                
                HStack {
                    Text("Expires:")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text(timeRemainingText(for: invoice))
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(invoice.timeRemaining > 300 ? SatsatDesignSystem.Colors.textPrimary : SatsatDesignSystem.Colors.warning)
                }
            }
        }
        .satsatCard()
    }
    
    private var invoiceGenerationCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            VStack(spacing: 16) {
                Image(systemName: "qrcode")
                    .font(.system(size: 60))
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                
                Text("Generate Lightning Invoice")
                    .font(SatsatDesignSystem.Typography.title3)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Text("Choose an amount and create a Lightning invoice for instant deposits")
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, SatsatDesignSystem.Spacing.lg)
        }
        .satsatCard()
    }
    
    private var activeInvoicesCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Text("Active Invoices")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("\(lightningManager.activeInvoices.count)")
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
            
            if lightningManager.activeInvoices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.title)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Text("No active invoices")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                .padding(.vertical, SatsatDesignSystem.Spacing.lg)
            } else {
                VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                    ForEach(lightningManager.activeInvoices.prefix(3), id: \.id) { invoice in
                        LightningInvoiceRow(invoice: invoice) {
                            generatedInvoice = invoice
                            selectedTab = .invoice
                        }
                    }
                }
            }
        }
        .satsatCard()
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            if generatedInvoice == nil && selectedAmount > 0 {
                Button("Generate Lightning Invoice") {
                    generateInvoice()
                    HapticFeedback.success()
                }
                .satsatPrimaryButton(isLoading: isGeneratingInvoice)
                .padding(.horizontal)
            }
            
            if let invoice = generatedInvoice {
                HStack(spacing: SatsatDesignSystem.Spacing.md) {
                    Button("Share Invoice") {
                        showingInvoiceDetail = true
                    }
                    .satsatPrimaryButton()
                    
                    Button("New Invoice") {
                        generatedInvoice = nil
                        qrCodeImage = nil
                        selectedTab = .quickAmounts
                    }
                    .satsatSecondaryButton()
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, SatsatDesignSystem.Spacing.lg)
        .background(
            Rectangle()
                .fill(SatsatDesignSystem.Colors.backgroundPrimary)
                .shadow(color: SatsatDesignSystem.Shadows.medium, radius: 8, x: 0, y: -2)
        )
    }
    
    // MARK: - Computed Properties
    
    private var quickAmounts: [QuickDepositAmount] {
        let remaining = group.remainingAmount
        
        return [
            QuickDepositAmount(amount: 10000, label: "10k sats", description: "Small contribution"),
            QuickDepositAmount(amount: 25000, label: "25k sats", description: "Medium contribution"),
            QuickDepositAmount(amount: 50000, label: "50k sats", description: "Large contribution"),
            QuickDepositAmount(amount: min(100000, remaining), label: remaining <= 100000 ? "Finish Goal" : "100k sats", description: remaining <= 100000 ? "Complete the goal!" : "Extra large")
        ]
    }
    
    // MARK: - Actions
    
    private func generateInvoice() {
        guard selectedAmount > 0 else { return }
        
        isGeneratingInvoice = true
        
        Task {
            do {
                let invoice = try await lightningManager.generateInvoice(
                    amount: selectedAmount,
                    description: "Deposit to \(group.displayName)",
                    groupId: group.id
                )
                
                let qrImage = generateQRCode(for: invoice.paymentRequest)
                
                await MainActor.run {
                    self.generatedInvoice = invoice
                    self.qrCodeImage = qrImage
                    self.selectedTab = .invoice
                    self.isGeneratingInvoice = false
                }
                
            } catch {
                await MainActor.run {
                    self.isGeneratingInvoice = false
                    // Handle error
                }
            }
        }
    }
    
    private var quickDepositAmounts: [QuickAmount] {
        return [
            QuickAmount(label: "10k sats", sats: 10000),
            QuickAmount(label: "25k sats", sats: 25000),
            QuickAmount(label: "50k sats", sats: 50000),
            QuickAmount(label: "100k sats", sats: 100000)
        ]
    }
    
    private func generateQRCode(for text: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(text.utf8)
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
    
    private func timeRemainingText(for invoice: LightningInvoice) -> String {
        let remaining = invoice.timeRemaining
        
        if remaining <= 0 {
            return "Expired"
        } else if remaining < 3600 {
            return "\(Int(remaining / 60))m remaining"
        } else {
            return "\(Int(remaining / 3600))h remaining"
        }
    }
}

// MARK: - Supporting Enums and Types

enum DepositTab: String, CaseIterable {
    case quickAmounts = "Quick"
    case custom = "Custom"
    case invoice = "Invoice"
    
    var title: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .quickAmounts: return "grid.circle"
        case .custom: return "textformat.123"
        case .invoice: return "qrcode"
        }
    }
}

struct QuickDepositAmount {
    let amount: UInt64
    let label: String
    let description: String
}

// MARK: - Supporting Components

struct BenefitItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(SatsatDesignSystem.Colors.lightning)
            
            Text(title)
                .font(SatsatDesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickAmountButton: View {
    let amount: QuickDepositAmount
    let isSelected: Bool
    let group: SavingsGroup
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                Text(amount.label)
                    .font(SatsatDesignSystem.Typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : SatsatDesignSystem.Colors.textPrimary)
                
                Text(amount.description)
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : SatsatDesignSystem.Colors.textSecondary)
                
                // Progress impact preview
                let newProgress = (Double(group.currentBalance + amount.amount) / Double(group.goal.targetAmountSats))
                Text("+\(Int((newProgress - group.progressPercentage) * 100))%")
                    .font(SatsatDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? SatsatDesignSystem.Colors.lightning : SatsatDesignSystem.Colors.success)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SatsatDesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                    .fill(isSelected ? SatsatDesignSystem.Colors.lightning : SatsatDesignSystem.Colors.backgroundSecondary)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleOnPress()
    }
}

struct LightningPaymentRow: View {
    let payment: LightningPayment
    
    var body: some View {
        HStack(spacing: SatsatDesignSystem.Spacing.md) {
            Image(systemName: payment.direction.icon)
                .font(.title3)
                .foregroundColor(payment.direction.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.description)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                if let completedAt = payment.completedAt {
                    Text(completedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(payment.amount.formattedSats)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                SatsatStatusBadge(text: payment.status.rawValue.capitalized, style: .success)
            }
        }
        .padding(SatsatDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                .fill(SatsatDesignSystem.Colors.backgroundSecondary)
        )
    }
}

struct LightningInvoiceRow: View {
    let invoice: LightningInvoice
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: SatsatDesignSystem.Spacing.md) {
                Image(systemName: invoice.status.icon)
                    .font(.title3)
                    .foregroundColor(invoice.status.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(invoice.amount.formattedSats)
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Text(invoice.description)
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    SatsatStatusBadge(text: invoice.status.rawValue.capitalized, style: .info)
                    
                    if invoice.status == .pending {
                        Text("\(Int(invoice.timeRemaining / 60))m left")
                            .font(SatsatDesignSystem.Typography.caption)
                            .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    }
                }
            }
            .padding(SatsatDesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                    .fill(SatsatDesignSystem.Colors.backgroundSecondary)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LimitInfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: SatsatDesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(SatsatDesignSystem.Colors.lightning)
                .frame(width: 20)
            
            Text(label)
                .font(SatsatDesignSystem.Typography.subheadline)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(SatsatDesignSystem.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
        }
    }
}

struct LightningTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(SatsatDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                    .fill(SatsatDesignSystem.Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                            .stroke(SatsatDesignSystem.Colors.lightning.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
    }
}

// MARK: - Lightning Invoice Detail View (Placeholder)

struct LightningInvoiceDetailView: View {
    let invoice: LightningInvoice
    let qrImage: UIImage?
    @EnvironmentObject var lightningManager: LightningManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Lightning Invoice Detail")
                    .font(SatsatDesignSystem.Typography.title2)
                
                if let qrImage = qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300, height: 300)
                }
                
                Text(invoice.amount.formattedSats)
                    .font(SatsatDesignSystem.Typography.title3)
                
                Button("Close") { dismiss() }
                    .satsatPrimaryButton()
                    .padding()
            }
            .navigationTitle("Share Invoice")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview {
    LightningDepositView(group: SavingsGroup.sampleGroup)
        .environmentObject(LightningManager.shared)
        .environmentObject(GroupManager.shared)
}