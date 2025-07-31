// KeyAdditionStatusView.swift
// Status notifications for adding keys and QR scanning for xpub import

import SwiftUI
import AVFoundation
import Foundation

struct KeyAdditionStatusView: View {
    let group: SavingsGroup
    @EnvironmentObject var groupManager: GroupManager
    @State private var showingQRScanner = false
    @State private var userKeyStatus: KeyStatus = .notAdded
    
    enum KeyStatus {
        case notAdded
        case pending
        case added
        case verified
        
        var description: String {
            switch self {
            case .notAdded: return "Key Required"
            case .pending: return "Key Pending"
            case .added: return "Key Added"
            case .verified: return "Key Verified"
            }
        }
        
        var color: Color {
            switch self {
            case .notAdded: return .red
            case .pending: return .orange
            case .added: return .blue
            case .verified: return .green
            }
        }
    }
    
    var body: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            // Status header
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(userKeyStatus.color)
                
                Text("Your Key Status")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text(userKeyStatus.description)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(userKeyStatus.color)
                    .cornerRadius(6)
            }
            
            // Status message
            Text(statusMessage)
                .font(SatsatDesignSystem.Typography.body)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.leading)
            
            // Action button
            if userKeyStatus == .notAdded {
                Button(action: {
                    showingQRScanner = true
                }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                        Text("Scan Key QR Code")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(.blue)
                    .cornerRadius(8)
                }
            }
        }
        .satsatCard()
        .sheet(isPresented: $showingQRScanner) {
            XPubQRScannerView(group: group) { scannedXPub in
                handleScannedXPub(scannedXPub)
            }
        }
        .onAppear {
            checkKeyStatus()
        }
    }
    
    private var statusIcon: String {
        switch userKeyStatus {
        case .notAdded: return "exclamationmark.triangle.fill"
        case .pending: return "clock.fill"
        case .added: return "key.fill"
        case .verified: return "checkmark.seal.fill"
        }
    }
    
    private var statusStyle: String {
        switch userKeyStatus {
        case .notAdded: return "error"
        case .pending: return "warning"
        case .added: return "info"
        case .verified: return "success"
        }
    }
    
    private var statusMessage: String {
        switch userKeyStatus {
        case .notAdded:
            return "You need to add your extended public key (xpub) to participate in this group's multisig wallet. Use your hardware wallet or compatible app to generate a QR code."
        case .pending:
            return "Your key has been submitted and is being verified by the group creator."
        case .added:
            return "Your key has been added to the group. Waiting for other members to complete setup."
        case .verified:
            return "Your key is verified and ready. The multisig wallet will be created once all required members join."
        }
    }
    
    private func checkKeyStatus() {
        // TODO: Check if current user has added their key to this group
        // For now, default to .notAdded
        userKeyStatus = .notAdded
    }
    
    private func handleScannedXPub(_ xpubData: XPubData) {
        // Update status to pending
        userKeyStatus = .pending
        
        // Store the xpub data and notify group
        Task {
            do {
                try await groupManager.addUserXPub(groupId: group.id, xpubData: xpubData)
                await MainActor.run {
                    userKeyStatus = .added
                }
            } catch {
                print("Failed to add xpub: \(error)")
                await MainActor.run {
                    userKeyStatus = .notAdded
                }
            }
        }
    }
}

struct XPubQRScannerView: View {
    let group: SavingsGroup
    let onScanned: (XPubData) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingManualEntry = false
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Scan your extended public key (xpub) QR code from your hardware wallet or compatible Bitcoin app.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                
                            QRCodeScannerView(
                onScan: { result in
                    handleScanResult(result)
                },
                onError: { error in
                    print("QR scan error: \(error)")
                }
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Button("Enter Manually") {
                    showingManualEntry = true
                }
                .padding()
            }
            .navigationTitle("Scan XPub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualXPubEntryView(group: group, onComplete: { xpubData in
                onScanned(xpubData)
                dismiss()
            })
        }
    }
    
    private func handleScanResult(_ result: String) {
        // Parse the scanned QR code
        if let xpubData = parseXPubQR(result) {
            onScanned(xpubData)
            dismiss()
        } else {
            // Show error - invalid QR code
            print("Invalid xpub QR code: \(result)")
        }
    }
    
    private func parseXPubQR(_ qrContent: String) -> XPubData? {
        // Parse various xpub formats
        // Support for:
        // - Plain xpub/ypub/zpub strings
        // - Descriptor format: wpkh([fingerprint/derivation]xpub...)
        // - JSON format with fingerprint and derivation path
        
        if qrContent.hasPrefix("{") {
            // JSON format
            return parseJSONXPub(qrContent)
        } else if qrContent.contains("[") && qrContent.contains("]") {
            // Descriptor format
            return parseDescriptorXPub(qrContent)
        } else if qrContent.hasPrefix("xpub") || qrContent.hasPrefix("ypub") || qrContent.hasPrefix("zpub") {
            // Plain xpub
            return XPubData(
                xpub: qrContent,
                fingerprint: nil,
                derivationPath: "m/48'/1'/0'/2'", // Default native segwit
                scriptType: .p2wsh
            )
        }
        
        return nil
    }
    
    private func parseJSONXPub(_ json: String) -> XPubData? {
        // Parse JSON format xpub data
        guard let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let xpub = parsed["xpub"] as? String else {
            return nil
        }
        
        return XPubData(
            xpub: xpub,
            fingerprint: parsed["fingerprint"] as? String,
            derivationPath: parsed["derivation"] as? String ?? "m/48'/1'/0'/2'",
            scriptType: .p2wsh
        )
    }
    
    private func parseDescriptorXPub(_ descriptor: String) -> XPubData? {
        // Parse descriptor format: wpkh([fingerprint/derivation]xpub...)
        // This is a simplified parser - real implementation would be more robust
        
        let pattern = #"\[([a-fA-F0-9]+)/([m0-9'/]+)\]([xyz]pub[a-zA-Z0-9]+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = descriptor as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        if let match = regex?.firstMatch(in: descriptor, range: range) {
            let fingerprint = nsString.substring(with: match.range(at: 1))
            let derivation = nsString.substring(with: match.range(at: 2))
            let xpub = nsString.substring(with: match.range(at: 3))
            
            return XPubData(
                xpub: xpub,
                fingerprint: fingerprint,
                derivationPath: "m/\(derivation)",
                scriptType: .p2wsh
            )
        }
        
        return nil
    }
}

struct ManualXPubEntryView: View {
    let group: SavingsGroup
    let onComplete: (XPubData) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var xpub = ""
    @State private var fingerprint = ""
    @State private var derivationPath = "m/48'/1'/0'/2'"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Extended Public Key") {
                    TextField("xpub/ypub/zpub...", text: $xpub)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("Fingerprint (Optional)") {
                    TextField("8-character hex", text: $fingerprint)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("Derivation Path") {
                    TextField("m/48'/1'/0'/2'", text: $derivationPath)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Text("Native Segwit (P2WSH) is used for optimal fee efficiency and security.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addXPub()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        return xpub.hasPrefix("xpub") || xpub.hasPrefix("ypub") || xpub.hasPrefix("zpub")
    }
    
    private func addXPub() {
        let xpubData = XPubData(
            xpub: xpub,
            fingerprint: fingerprint.isEmpty ? nil : fingerprint,
            derivationPath: derivationPath,
            scriptType: .p2wsh
        )
        
        onComplete(xpubData)
    }
}

// Data model for xpub information
struct XPubData {
    let xpub: String
    let fingerprint: String?
    let derivationPath: String
    let scriptType: MultisigScriptType
}

// Using existing QRCodeScannerView from Core/Camera/QRCodeScanner.swift