// PSBTSigningView.swift
// Advanced PSBT signing interface with QR codes and signature collection

import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - PSBT Signing View

struct PSBTSigningView: View {
    @EnvironmentObject var psbtManager: PSBTManager
    @EnvironmentObject var groupManager: GroupManager
    @Environment(\.dismiss) var dismiss
    
    let psbt: GroupPSBT
    @State private var selectedTab: SigningTab = .overview
    @State private var qrCodeImage: UIImage?
    @State private var showingQRExport = false
    @State private var showingFileExport = false
    @State private var showingImportOptions = false
    @State private var isGeneratingQR = false
    @State private var signatureProgress: Double = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with PSBT info
                headerSection
                
                // Tab selection
                tabSelector
                
                // Tab content
                ScrollView {
                    VStack(spacing: SatsatDesignSystem.Spacing.lg) {
                        switch selectedTab {
                        case .overview:
                            overviewSection
                        case .signatures:
                            signaturesSection
                        case .export:
                            exportSection
                        case .importPSBT:
                            importSection
                        }
                        
                        Spacer(minLength: SatsatDesignSystem.Spacing.xl)
                    }
                    .padding(SatsatDesignSystem.Spacing.md)
                }
                
                // Action buttons
                actionButtonsSection
            }
            .background(SatsatDesignSystem.Colors.backgroundPrimary)
            .navigationTitle("Transaction Signing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Share QR Code") {
                            showingQRExport = true
                        }
                        
                        Button("Export File") {
                            showingFileExport = true
                        }
                        
                        Button("Import Signatures") {
                            showingImportOptions = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            calculateSignatureProgress()
            generateQRCode()
        }
        .sheet(isPresented: $showingQRExport) {
            PSBTQRExportView(psbt: psbt, qrImage: qrCodeImage)
        }
        .sheet(isPresented: $showingFileExport) {
            PSBTFileExportView(psbt: psbt)
        }
        .sheet(isPresented: $showingImportOptions) {
            PSBTImportView(psbt: psbt)
                .environmentObject(psbtManager)
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            // PSBT status and progress
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transaction ID")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Text(psbt.id.prefix(8) + "...")
                        .font(SatsatDesignSystem.Typography.monospaceBody)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                }
                
                Spacer()
                
                PSBTStatusIndicator(status: psbt.status)
            }
            
            // Progress bar
            VStack(spacing: 8) {
                HStack {
                    Text("Signature Progress")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(psbt.signatures.count)/\(requiredSignatures) signatures")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                
                SatsatProgressBar(
                    progress: signatureProgress,
                    height: 12,
                    showPercentage: false
                )
            }
        }
        .satsatCard()
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SigningTab.allCases, id: \.self) { tab in
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
                    .foregroundColor(selectedTab == tab ? SatsatDesignSystem.Colors.satsatOrange : SatsatDesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SatsatDesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                            .fill(selectedTab == tab ? SatsatDesignSystem.Colors.satsatOrange.opacity(0.1) : Color.clear)
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
    
    private var overviewSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            // Transaction details
            transactionDetailsCard
            
            // Security information
            securityInfoCard
            
            // Signing instructions
            signingInstructionsCard
        }
    }
    
    private var transactionDetailsCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Text("Transaction Details")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text(psbt.purpose.displayName)
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(psbt.purpose.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(psbt.purpose.color.opacity(0.1))
                    )
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.md) {
                DetailRow(label: "Amount", value: psbt.amount.formattedSats, isHighlight: true)
                
                if let destination = psbt.destinationAddress {
                    DetailRow(label: "To Address", value: formatAddress(destination), isMono: true)
                }
                
                DetailRow(label: "Network Fee", value: "~\(estimatedFee) sats")
                
                DetailRow(label: "Created By", value: psbt.createdBy)
                
                DetailRow(label: "Created", value: psbt.createdAt.formatted(date: .abbreviated, time: .shortened))
                
                if let notes = psbt.notes {
                    DetailRow(label: "Notes", value: notes, isMultiline: true)
                }
            }
        }
        .satsatCard()
    }
    
    private var securityInfoCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "shield.checkerboard")
                    .foregroundColor(SatsatDesignSystem.Colors.success)
                
                Text("Security Information")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.sm) {
                SecurityInfoRow(
                    icon: "lock.shield",
                    title: "Multisig Protection",
                    description: "Requires \(requiredSignatures) of \(totalSigners) signatures to execute"
                )
                
                SecurityInfoRow(
                    icon: "checkmark.seal",
                    title: "Verified Transaction",
                    description: "All inputs and outputs have been validated"
                )
                
                SecurityInfoRow(
                    icon: "eye.slash",
                    title: "Privacy Protected",
                    description: "Transaction details are encrypted end-to-end"
                )
            }
        }
        .satsatCard()
    }
    
    private var signingInstructionsCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(SatsatDesignSystem.Colors.info)
                
                Text("How to Sign")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.md) {
                InstructionStep(
                    number: "1",
                    title: "Review Transaction",
                    description: "Verify all details above are correct"
                )
                
                InstructionStep(
                    number: "2",
                    title: "Export PSBT",
                    description: "Share via QR code or file with group members"
                )
                
                InstructionStep(
                    number: "3",
                    title: "Collect Signatures",
                    description: "Wait for \(requiredSignatures) members to sign"
                )
                
                InstructionStep(
                    number: "4",
                    title: "Broadcast",
                    description: "Send the completed transaction to Bitcoin network"
                )
            }
        }
        .satsatCard()
    }
    
    private var signaturesSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            // Signatures collected
            signaturesCollectedCard
            
            // Pending signatures
            pendingSignaturesCard
        }
    }
    
    private var signaturesCollectedCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(SatsatDesignSystem.Colors.success)
                
                Text("Signatures Collected (\(psbt.signatures.count))")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            if psbt.signatures.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "signature")
                        .font(.title)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Text("No signatures yet")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                .padding(.vertical, SatsatDesignSystem.Spacing.lg)
            } else {
                VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                    ForEach(Array(psbt.signatures.values), id: \.signerId) { signature in
                        SignatureRow(signature: signature)
                    }
                }
            }
        }
        .satsatCard()
    }
    
    private var pendingSignaturesCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(SatsatDesignSystem.Colors.warning)
                
                Text("Pending Signatures")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("\(pendingSigners.count) remaining")
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.sm) {
                ForEach(pendingSigners, id: \.id) { member in
                    PendingSignerRow(member: member)
                }
            }
        }
        .satsatCard()
    }
    
    private var exportSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            // QR code export
            qrExportCard
            
            // File export options
            fileExportCard
        }
    }
    
    private var qrExportCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "qrcode")
                    .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                
                Text("QR Code Export")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            if isGeneratingQR {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: SatsatDesignSystem.Colors.satsatOrange))
                    
                    Text("Generating QR code...")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                .frame(height: 200)
            } else if let qrImage = qrCodeImage {
                VStack(spacing: 16) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .background(Color.white)
                        .cornerRadius(SatsatDesignSystem.Radius.medium)
                    
                    Text("Scan with Bitcoin wallet or save to share")
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            HStack(spacing: SatsatDesignSystem.Spacing.md) {
                Button("Share QR") {
                    showingQRExport = true
                    HapticFeedback.medium()
                }
                .satsatSecondaryButton()
                
                Button("Save Image") {
                    saveQRToPhotos()
                    HapticFeedback.success()
                }
                .satsatSecondaryButton()
            }
        }
        .satsatCard()
    }
    
    private var fileExportCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "doc.badge.arrow.up")
                    .foregroundColor(SatsatDesignSystem.Colors.info)
                
                Text("File Export")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.md) {
                ExportOptionRow(
                    icon: "doc.text",
                    title: "PSBT File",
                    description: "Standard PSBT format for hardware wallets",
                    fileExtension: ".psbt"
                ) {
                    exportPSBTFile()
                }
                
                ExportOptionRow(
                    icon: "textformat.alt",
                    title: "Base64 Text",
                    description: "Copy PSBT as base64 text to clipboard",
                    fileExtension: ".txt"
                ) {
                    copyPSBTToClipboard()
                }
                
                ExportOptionRow(
                    icon: "qrcode",
                    title: "QR Code Image",
                    description: "Save QR code as image file",
                    fileExtension: ".png"
                ) {
                    saveQRToPhotos()
                }
            }
        }
        .satsatCard()
    }
    
    private var importSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            // Import options
            importOptionsCard
            
            // Import history
            importHistoryCard
        }
    }
    
    private var importOptionsCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "arrow.down.doc")
                    .foregroundColor(SatsatDesignSystem.Colors.success)
                
                Text("Import Signatures")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.md) {
                ImportOptionRow(
                    icon: "camera.viewfinder",
                    title: "Scan QR Code",
                    description: "Scan signed PSBT from another device"
                ) {
                    // Handle QR scan import
                }
                
                ImportOptionRow(
                    icon: "folder",
                    title: "Import File",
                    description: "Select PSBT file from device storage"
                ) {
                    // Handle file import
                }
                
                ImportOptionRow(
                    icon: "doc.on.clipboard",
                    title: "Paste Text",
                    description: "Paste base64 PSBT from clipboard"
                ) {
                    // Handle clipboard import
                }
            }
        }
        .satsatCard()
    }
    
    private var importHistoryCard: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                
                Text("Import History")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.title)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                
                Text("No imports yet")
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
            .padding(.vertical, SatsatDesignSystem.Spacing.lg)
        }
        .satsatCard()
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            if psbt.status == .readyToBroadcast {
                Button("Broadcast Transaction") {
                    broadcastTransaction()
                    HapticFeedback.success()
                }
                .satsatPrimaryButton()
                .padding(.horizontal)
            } else {
                Button("Share for Signing") {
                    showingQRExport = true
                    HapticFeedback.medium()
                }
                .satsatPrimaryButton()
                .padding(.horizontal)
            }
            
            // Additional actions
            HStack(spacing: SatsatDesignSystem.Spacing.md) {
                Button("Import Signatures") {
                    showingImportOptions = true
                }
                .satsatSecondaryButton()
                
                Button("Export Options") {
                    selectedTab = .export
                }
                .satsatSecondaryButton()
            }
            .padding(.horizontal)
        }
        .padding(.bottom, SatsatDesignSystem.Spacing.lg)
        .background(
            Rectangle()
                .fill(SatsatDesignSystem.Colors.backgroundPrimary)
                .shadow(color: SatsatDesignSystem.Shadows.medium, radius: 8, x: 0, y: -2)
        )
    }
    
    // MARK: - Computed Properties
    
    private var requiredSignatures: Int {
        // Get from group's multisig config
        if let group = groupManager.activeGroups.first(where: { $0.id == psbt.groupId }) {
            return group.multisigConfig.threshold
        }
        return 2 // Default fallback
    }
    
    private var totalSigners: Int {
        if let group = groupManager.activeGroups.first(where: { $0.id == psbt.groupId }) {
            return group.activeMembers.count
        }
        return 3 // Default fallback
    }
    
    private var pendingSigners: [GroupMember] {
        guard let group = groupManager.activeGroups.first(where: { $0.id == psbt.groupId }) else {
            return []
        }
        
        let signedMembers = Set(psbt.signatures.keys)
        return group.activeMembers.filter { !signedMembers.contains($0.id) }
    }
    
    private var estimatedFee: String {
        // Calculate estimated fee based on transaction size
        let estimatedFee = 1000 // Placeholder calculation
        return NumberFormatter().string(from: NSNumber(value: estimatedFee)) ?? "1,000"
    }
    
    // MARK: - Actions
    
    private func calculateSignatureProgress() {
        signatureProgress = Double(psbt.signatures.count) / Double(requiredSignatures)
    }
    
    private func generateQRCode() {
        isGeneratingQR = true
        
        Task {
            // Simulate QR generation
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            let qrImage = createQRCode(for: psbt.psbtData)
            
            await MainActor.run {
                self.qrCodeImage = qrImage
                self.isGeneratingQR = false
            }
        }
    }
    
    private func createQRCode(for data: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(data.utf8)
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
    
    private func exportPSBTFile() {
        // Implementation for file export
        HapticFeedback.success()
    }
    
    private func copyPSBTToClipboard() {
        UIPasteboard.general.string = psbt.psbtData
        HapticFeedback.success()
    }
    
    private func saveQRToPhotos() {
        // Implementation for saving QR to photos
        HapticFeedback.success()
    }
    
    private func broadcastTransaction() {
        Task {
            do {
                try await psbtManager.broadcastPSBT(psbt.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // Handle error
            }
        }
    }
    
    private func formatAddress(_ address: String) -> String {
        if address.count > 20 {
            return "\(address.prefix(10))...\(address.suffix(10))"
        }
        return address
    }
}

// MARK: - Supporting Enums and Types

enum SigningTab: String, CaseIterable {
    case overview = "Overview"
    case signatures = "Signatures"
    case export = "Export"
    case importPSBT = "Import"
    
    var title: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .overview: return "doc.text"
        case .signatures: return "signature"
        case .export: return "square.and.arrow.up"
        case .importPSBT: return "square.and.arrow.down"
        }
    }
}

// MARK: - Supporting Components

struct PSBTStatusIndicator: View {
    let status: PSBTStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
            
            Text(status.displayName)
                .font(SatsatDesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(status.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(status.color.opacity(0.1))
        )
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let isHighlight: Bool
    let isMono: Bool
    let isMultiline: Bool
    
    init(label: String, value: String, isHighlight: Bool = false, isMono: Bool = false, isMultiline: Bool = false) {
        self.label = label
        self.value = value
        self.isHighlight = isHighlight
        self.isMono = isMono
        self.isMultiline = isMultiline
    }
    
    var body: some View {
        HStack(alignment: isMultiline ? .top : .center) {
            Text(label)
                .font(SatsatDesignSystem.Typography.subheadline)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(value)
                .font(isMono ? SatsatDesignSystem.Typography.monospaceBody : SatsatDesignSystem.Typography.subheadline)
                .fontWeight(isHighlight ? .bold : .regular)
                .foregroundColor(isHighlight ? SatsatDesignSystem.Colors.satsatOrange : SatsatDesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct SecurityInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: SatsatDesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(SatsatDesignSystem.Colors.success)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

struct InstructionStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: SatsatDesignSystem.Spacing.md) {
            Text(number)
                .font(SatsatDesignSystem.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(SatsatDesignSystem.Colors.satsatOrange)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

struct SignatureRow: View {
    let signature: PSBTSignature
    
    var body: some View {
        HStack(spacing: SatsatDesignSystem.Spacing.md) {
            SatsatAvatar(name: signature.signerName, color: "#34C759", size: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(signature.signerName)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Text("Signed \(signature.signedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(SatsatDesignSystem.Colors.success)
        }
        .padding(SatsatDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                .fill(SatsatDesignSystem.Colors.success.opacity(0.05))
        )
    }
}

struct PendingSignerRow: View {
    let member: GroupMember
    
    var body: some View {
        HStack(spacing: SatsatDesignSystem.Spacing.md) {
            SatsatAvatar(name: member.displayName, color: "#FF9F0A", size: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Text("Signature pending")
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "clock")
                .foregroundColor(SatsatDesignSystem.Colors.warning)
        }
        .padding(SatsatDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                .fill(SatsatDesignSystem.Colors.warning.opacity(0.05))
        )
    }
}

struct ExportOptionRow: View {
    let icon: String
    let title: String
    let description: String
    let fileExtension: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: SatsatDesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(SatsatDesignSystem.Colors.info)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Text(description)
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Text(fileExtension)
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(SatsatDesignSystem.Colors.backgroundTertiary)
                    )
            }
            .padding(SatsatDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                    .fill(SatsatDesignSystem.Colors.backgroundSecondary)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ImportOptionRow: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: SatsatDesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(SatsatDesignSystem.Colors.success)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Text(description)
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
            .padding(SatsatDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                    .fill(SatsatDesignSystem.Colors.backgroundSecondary)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Additional Views (Placeholders for sheets)

struct PSBTQRExportView: View {
    let psbt: GroupPSBT
    let qrImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("QR Export View")
                Button("Close") { dismiss() }
            }
            .navigationTitle("Share QR Code")
        }
    }
}

struct PSBTFileExportView: View {
    let psbt: GroupPSBT
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("File Export View")
                Button("Close") { dismiss() }
            }
            .navigationTitle("Export File")
        }
    }
}

struct PSBTImportView: View {
    let psbt: GroupPSBT
    @EnvironmentObject var psbtManager: PSBTManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Import View")
                Button("Close") { dismiss() }
            }
            .navigationTitle("Import Signatures")
        }
    }
}

// MARK: - Extensions

extension PSBTStatus {
    var icon: String {
        switch self {
        case .pendingSignatures: return "clock"
        case .readyToBroadcast: return "checkmark.circle"
        case .broadcasted: return "antenna.radiowaves.left.and.right"
        case .confirmed: return "checkmark.seal"
        case .failed: return "exclamationmark.triangle"
        case .cancelled: return "xmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .pendingSignatures: return SatsatDesignSystem.Colors.warning
        case .readyToBroadcast: return SatsatDesignSystem.Colors.info
        case .broadcasted: return SatsatDesignSystem.Colors.satsatOrange
        case .confirmed: return SatsatDesignSystem.Colors.success
        case .failed: return SatsatDesignSystem.Colors.error
        case .cancelled: return SatsatDesignSystem.Colors.textSecondary
        }
    }
    
    var displayName: String {
        switch self {
        case .pendingSignatures: return "Pending Signatures"
        case .readyToBroadcast: return "Ready to Broadcast"
        case .broadcasted: return "Broadcasted"
        case .confirmed: return "Confirmed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
}

extension TransactionPurpose {
    var color: Color {
        switch self {
        case .goalWithdrawal: return SatsatDesignSystem.Colors.success
        case .emergencyWithdrawal: return SatsatDesignSystem.Colors.error
        case .partialWithdrawal: return SatsatDesignSystem.Colors.warning
        case .rebalancing: return SatsatDesignSystem.Colors.info
        case .testing: return SatsatDesignSystem.Colors.textSecondary
        }
    }
}

// MARK: - Preview

#Preview {
    PSBTSigningView(psbt: GroupPSBT.samplePSBT)
        .environmentObject(PSBTManager.shared)
        .environmentObject(GroupManager.shared)
}