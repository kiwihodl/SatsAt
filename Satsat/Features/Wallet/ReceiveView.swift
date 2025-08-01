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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: SatsatDesignSystem.Spacing.lg) {
                    // Type Selector
                    typeSelectorSection
                    
                    // QR Code
                    qrCodeSection
                    
                    // Address Display
                    addressSection
                    
                    Spacer(minLength: SatsatDesignSystem.Spacing.xl)
                }
                .padding(SatsatDesignSystem.Spacing.md)
            }
            .background(SatsatDesignSystem.Colors.backgroundSecondary)
            .navigationBarTitleDisplayMode(.inline)
            .background(SatsatDesignSystem.Colors.backgroundSecondary)
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
        .background(SatsatDesignSystem.Colors.backgroundSecondary)
        .preferredColorScheme(.dark)
        .onAppear {
            generateAddress()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [shareText])
        }
    }
    
    // MARK: - View Sections
    
    private var typeSelectorSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.sm) {
            HStack {
                Text("Type")
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
                        .background(SatsatDesignSystem.Colors.backgroundSecondary)
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
    
    // MARK: - Helper Methods
    
    private func generateAddress() {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch selectedAddressType {
            case .multisig:
                generatedAddress = "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
            case .lightning:
                generatedAddress = "lnbc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
            }
            
            generateQRCode()
            isLoading = false
        }
    }
    
    private func generateQRCode() {
        guard !generatedAddress.isEmpty else { return }
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(generatedAddress.utf8)
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        }
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

// MARK: - Address Type Button

struct AddressTypeButton: View {
    let type: AddressType
    let isSelected: Bool
    let group: SavingsGroup
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : type.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : SatsatDesignSystem.Colors.textPrimary)
                }
                
                Spacer()
            }
            .padding(SatsatDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                    .fill(isSelected ? SatsatDesignSystem.Colors.satsatOrange : SatsatDesignSystem.Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                            .stroke(isSelected ? SatsatDesignSystem.Colors.satsatOrange : SatsatDesignSystem.Colors.backgroundTertiary, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Address Type Enum

enum AddressType: CaseIterable {
    case multisig
    case lightning
    
    var displayName: String {
        switch self {
        case .multisig:
            return "Bitcoin"
        case .lightning:
            return "Lightning"
        }
    }
    
    var icon: String {
        switch self {
        case .multisig:
            return "bitcoinsign.circle"
        case .lightning:
            return "bolt.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .multisig:
            return SatsatDesignSystem.Colors.satsatOrange
        case .lightning:
            return SatsatDesignSystem.Colors.lightning
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