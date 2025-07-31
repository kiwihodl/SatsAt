// ReceiveView.swift
// Bitcoin receive interface with QR codes for Satsat groups

import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Receive View

struct ReceiveView: View {
    @EnvironmentObject var groupManager: GroupManager
    @EnvironmentObject var lightningManager: LightningManager
    @Environment(\.dismiss) var dismiss
    
    let group: SavingsGroup
    @State private var selectedAddressType: AddressType = .multisig
    @State private var generatedAddress: String = ""
    @State private var qrCodeImage: UIImage?
    @State private var isLoading = false
    @State private var showingShareSheet = false
    @State private var copyFeedback = false
    @State private var showingLightningDeposit = false
    @State private var showingExternalServices = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: SatsatDesignSystem.Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Educational disclaimer about external services (App Store compliance)
                    ExternalServicesView.educationalReceiveMessage()
                    
                    // QR Code
                    qrCodeSection
                    
                    // Address Display
                    addressSection
                    
                    // Address Type Selector
                    addressTypeSection
                    
                    // Action Buttons
                    actionButtonsSection
                    
                    // Instructions
                    instructionsSection
                    
                    Spacer(minLength: SatsatDesignSystem.Spacing.xl)
                }
                .padding(SatsatDesignSystem.Spacing.md)
            }
            .background(SatsatDesignSystem.Colors.backgroundPrimary)
            .navigationTitle("Receive Bitcoin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        showingShareSheet = true
                        HapticFeedback.light()
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                    .disabled(generatedAddress.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            generateAddress()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [shareText])
        }
        .sheet(isPresented: $showingLightningDeposit) {
            LightningDepositView(group: group)
                .environmentObject(lightningManager)
                .environmentObject(groupManager)
        }
        .sheet(isPresented: $showingExternalServices) {
            ExternalServicesView()
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            // Group info
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
                
                SatsatStatusBadge(text: "Secure", style: .success)
            }
            
            // Current balance
            VStack(spacing: 4) {
                Text("Current Balance")
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                
                BitcoinAmountView(
                    amount: group.currentBalance,
                    style: .medium,
                    alignment: .center
                )
            }
        }
        .satsatCard()
    }
    
    private var qrCodeSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            if isLoading {
                VStack(spacing: SatsatDesignSystem.Spacing.md) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: SatsatDesignSystem.Colors.satsatOrange))
                        .scaleEffect(1.5)
                    
                    Text("Generating secure address...")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                .frame(width: 200, height: 200)
                .background(
                    RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                        .fill(SatsatDesignSystem.Colors.backgroundSecondary)
                )
            } else if let qrImage = qrCodeImage {
                VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .background(Color.white)
                        .cornerRadius(SatsatDesignSystem.Radius.large)
                        .shadow(color: SatsatDesignSystem.Shadows.medium, radius: 8)
                    
                    Text("Scan QR Code to Send Bitcoin")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: SatsatDesignSystem.Spacing.md) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 60))
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Text("QR Code Unavailable")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                .frame(width: 200, height: 200)
                .background(
                    RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                        .fill(SatsatDesignSystem.Colors.backgroundSecondary)
                )
            }
        }
    }
    
    private var addressSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack {
                Text("Bitcoin Address")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                if copyFeedback {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(SatsatDesignSystem.Colors.success)
                        Text("Copied")
                            .font(SatsatDesignSystem.Typography.caption)
                            .foregroundColor(SatsatDesignSystem.Colors.success)
                    }
                }
            }
            
            Button(action: copyAddress) {
                HStack {
                    Text(generatedAddress.isEmpty ? "Generating address..." : generatedAddress)
                        .font(SatsatDesignSystem.Typography.monospaceBody)
                        .foregroundColor(generatedAddress.isEmpty ? SatsatDesignSystem.Colors.textSecondary : SatsatDesignSystem.Colors.textPrimary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                }
                .padding(SatsatDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                        .fill(SatsatDesignSystem.Colors.backgroundSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                                .stroke(SatsatDesignSystem.Colors.backgroundTertiary, lineWidth: 1)
                        )
                )
            }
            .disabled(generatedAddress.isEmpty)
        }
        .satsatCard()
    }
    
    private var addressTypeSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack {
                Text("Address Type")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                AddressTypeButton(
                    type: .multisig,
                    isSelected: selectedAddressType == .multisig,
                    group: group
                ) {
                    selectedAddressType = .multisig
                    generateAddress()
                }
                
                AddressTypeButton(
                    type: .lightning,
                    isSelected: selectedAddressType == .lightning,
                    group: group
                ) {
                    selectedAddressType = .lightning
                    generateAddress()
                }
            }
        }
        .satsatCard()
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            Button("Copy Address") {
                copyAddress()
            }
            .satsatPrimaryButton()
            .disabled(generatedAddress.isEmpty)
            
            VStack(spacing: SatsatDesignSystem.Spacing.md) {
                HStack(spacing: SatsatDesignSystem.Spacing.md) {
                    Button("Share QR Code") {
                        showingShareSheet = true
                        HapticFeedback.light()
                    }
                    .satsatSecondaryButton()
                    .disabled(generatedAddress.isEmpty)
                    
                    Button("Lightning Deposit") {
                        showingLightningDeposit = true
                        HapticFeedback.medium()
                    }
                    .satsatSecondaryButton()
                    .foregroundColor(SatsatDesignSystem.Colors.lightning)
                }
                
                Button("Find Bitcoin Services") {
                    showingExternalServices = true
                    HapticFeedback.medium()
                }
                .satsatSecondaryButton()
                .foregroundColor(SatsatDesignSystem.Colors.info)
            }
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.sm) {
            Text("How to Receive Bitcoin")
                .font(SatsatDesignSystem.Typography.headline)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.sm) {
                InstructionRow(
                    number: "1",
                    title: "Share the Address",
                    description: "Send the Bitcoin address or QR code to the person sending you Bitcoin"
                )
                
                InstructionRow(
                    number: "2",
                    title: "Wait for Confirmation",
                    description: "Bitcoin transactions typically take 10-60 minutes to confirm on the network"
                )
                
                InstructionRow(
                    number: "3",
                    title: "Funds Added to Group",
                    description: "Once confirmed, the Bitcoin will be added to your group's shared wallet"
                )
            }
        }
        .satsatCard()
    }
    
    // MARK: - Actions
    
    private func generateAddress() {
        isLoading = true
        
        Task {
            do {
                // Simulate address generation
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                let address = try await generateBitcoinAddress(type: selectedAddressType)
                let qrImage = generateQRCode(for: address)
                
                await MainActor.run {
                    self.generatedAddress = address
                    self.qrCodeImage = qrImage
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    // Handle error
                }
            }
        }
    }
    
    private func generateBitcoinAddress(type: AddressType) async throws -> String {
        switch type {
        case .multisig:
            // Generate multisig address for the group
            return "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh" // Mock address
        case .lightning:
            // Generate Lightning invoice
            return "lnbc1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq" // Mock invoice
        }
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
    
    private func copyAddress() {
        UIPasteboard.general.string = generatedAddress
        HapticFeedback.success()
        
        withAnimation {
            copyFeedback = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copyFeedback = false
            }
        }
    }
    
    private var shareText: String {
        return "Send Bitcoin to this address:\n\n\(generatedAddress)"
    }
}

// MARK: - Supporting Components

enum AddressType {
    case multisig, lightning
    
    var title: String {
        switch self {
        case .multisig: return "Multisig Address"
        case .lightning: return "Lightning Invoice"
        }
    }
    
    var description: String {
        switch self {
        case .multisig: return "On-chain Bitcoin address for your group wallet"
        case .lightning: return "Instant payments with lower fees"
        }
    }
    
    var icon: String {
        switch self {
        case .multisig: return "lock.shield"
        case .lightning: return "bolt.fill"
        }
    }
    
    var isAvailable: Bool {
        switch self {
        case .multisig: return true
        case .lightning: return false // Coming soon
        }
    }
}

struct AddressTypeButton: View {
    let type: AddressType
    let isSelected: Bool
    let group: SavingsGroup
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: SatsatDesignSystem.Spacing.md) {
                // Icon
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(type.isAvailable ? SatsatDesignSystem.Colors.satsatOrange : SatsatDesignSystem.Colors.textSecondary)
                    .frame(width: 32)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(type.title)
                            .font(SatsatDesignSystem.Typography.headline)
                            .foregroundColor(type.isAvailable ? SatsatDesignSystem.Colors.textPrimary : SatsatDesignSystem.Colors.textSecondary)
                        
                        if !type.isAvailable {
                            SatsatStatusBadge(text: "Soon", style: .neutral)
                        }
                        
                        Spacer()
                        
                        if isSelected && type.isAvailable {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(SatsatDesignSystem.Colors.success)
                        }
                    }
                    
                    Text(type.description)
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(SatsatDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                    .fill(SatsatDesignSystem.Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                            .stroke(
                                isSelected && type.isAvailable 
                                    ? SatsatDesignSystem.Colors.satsatOrange 
                                    : Color.clear, 
                                lineWidth: 2
                            )
                    )
            )
        }
        .disabled(!type.isAvailable)
        .buttonStyle(PlainButtonStyle())
    }
}

struct InstructionRow: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: SatsatDesignSystem.Spacing.md) {
            // Number circle
            Text(number)
                .font(SatsatDesignSystem.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(SatsatDesignSystem.Colors.satsatOrange)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ReceiveView(group: SavingsGroup.sampleGroup)
        .environmentObject(GroupManager.shared)
}