import SwiftUI
import AVFoundation

struct XPubImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var xpub = ""
    @State private var fingerprint = ""
    @State private var derivationPath = "m/84'/0'/0'"
    @State private var showingQRScanner = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isImporting = false
    @State private var showFullXpub = false
    @State private var showingImportOptions = true
    @State private var showingManualEntry = false
    
    let group: SavingsGroup
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Import Key")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding(.top)
                    
                    if showingImportOptions {
                        // Import Options
                        VStack(spacing: 16) {
                            Button(action: {
                                showingQRScanner = true
                            }) {
                                HStack {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.title2)
                                    Text("Scan QR Code")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showingImportOptions = false
                                showingManualEntry = true
                            }) {
                                HStack {
                                    Image(systemName: "keyboard")
                                        .font(.title2)
                                    Text("Manual Entry")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    } else if showingManualEntry {
                        // Manual Entry Form
                        VStack(spacing: 16) {
                            // XPub Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Extended Public Key")
                                        .font(.headline)
                                    Spacer()
                                    Button(action: {
                                        showFullXpub.toggle()
                                    }) {
                                        Image(systemName: showFullXpub ? "eye.slash" : "eye")
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                if showFullXpub {
                                    TextField("xpub...", text: $xpub)
                                        .font(.system(.body, design: .monospaced))
                                        .padding()
                                        .background(SatsatDesignSystem.Colors.backgroundSecondary)
                                        .cornerRadius(8)
                                        .foregroundColor(.white)
                                } else {
                                    HStack {
                                        Text(xpub.isEmpty ? "xpub..." : String(xpub.prefix(8)) + "..." + String(xpub.suffix(4)))
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(xpub.isEmpty ? .secondary : .primary)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(SatsatDesignSystem.Colors.backgroundSecondary)
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        if let clipboardString = UIPasteboard.general.string {
                                            xpub = clipboardString
                                        }
                                    }
                                }
                            }
                            
                            // Fingerprint Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Master Key Fingerprint")
                                        .font(.headline)
                                    Text("*")
                                        .foregroundColor(.red)
                                }
                                
                                TextField("8-character hex", text: $fingerprint)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .background(SatsatDesignSystem.Colors.backgroundSecondary)
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                                    .onTapGesture {
                                        if let clipboardString = UIPasteboard.general.string {
                                            fingerprint = clipboardString
                                        }
                                    }
                            }
                            
                            // Derivation Path Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Derivation Path")
                                    .font(.headline)
                                
                                TextField("m/84'/0'/0'", text: $derivationPath)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .background(SatsatDesignSystem.Colors.backgroundSecondary)
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                                    .onTapGesture {
                                        if let clipboardString = UIPasteboard.general.string {
                                            derivationPath = clipboardString
                                        }
                                    }
                            }
                            
                            // Import Button
                            Button(action: importKey) {
                                HStack {
                                    if isImporting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "key.fill")
                                    }
                                    Text(isImporting ? "Importing..." : "Import Key")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isImportButtonEnabled ? Color.orange : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(!isImportButtonEnabled || isImporting)
                            
                            Spacer()
                        }
                    }
                }
                .padding()
            }
            .background(SatsatDesignSystem.Colors.backgroundSecondary)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showingManualEntry {
                        Button("Back") {
                            showingManualEntry = false
                            showingImportOptions = true
                        }
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingQRScanner) {
            XPubImportQRScannerView { result in
                switch result {
                case .success(let scannedString):
                    xpub = scannedString
                case .failure(let error):
                    alertMessage = "QR scanning failed: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
        .alert(alertMessage.contains("Error") ? "Error" : "Success", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isImportButtonEnabled: Bool {
        !xpub.isEmpty && !fingerprint.isEmpty && !derivationPath.isEmpty
    }
    
    private func importKey() {
        isImporting = true
        
        // Validate xpub format
        guard xpub.hasPrefix("xpub") || xpub.hasPrefix("ypub") || xpub.hasPrefix("zpub") else {
            alertMessage = "Invalid extended public key format. Must start with xpub, ypub, or zpub."
            showingAlert = true
            isImporting = false
            return
        }
        
        // Validate fingerprint format
        guard fingerprint.count == 8 && fingerprint.allSatisfy({ $0.isHexDigit }) else {
            alertMessage = "Invalid fingerprint format. Must be 8 hexadecimal characters."
            showingAlert = true
            isImporting = false
            return
        }
        
        // Validate derivation path
        guard derivationPath.hasPrefix("m/") else {
            alertMessage = "Invalid derivation path. Must start with 'm/'."
            showingAlert = true
            isImporting = false
            return
        }
        
        // Simulate import process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isImporting = false
            
            // Store the imported key data
            // In a real implementation, this would save to CoreData or secure storage
            print("✅ Key imported successfully:")
            print("   XPub: \(xpub)")
            print("   Fingerprint: \(fingerprint)")
            print("   Derivation Path: \(derivationPath)")
            
            // Update the group member with the imported key
            if let firstMemberIndex = group.members.firstIndex(where: { $0.id == group.members.first?.id }) {
                // Update the member's xpub in the group
                group.members[firstMemberIndex].xpub = xpub
                group.members[firstMemberIndex].fingerprint = fingerprint
                group.members[firstMemberIndex].derivationPath = derivationPath
                
                print("🔑 Updated member with imported key")
                print("   XPub: \(xpub)")
                print("   Fingerprint: \(fingerprint)")
                print("   Derivation Path: \(derivationPath)")
                
                // Trigger UI update notification
                NotificationCenter.default.post(
                    name: Notification.Name("groupDataUpdated"),
                    object: group.id
                )
                
                // Dismiss immediately
                dismiss()
            } else {
                alertMessage = "Error: No members found in group"
                showingAlert = true
            }
        }
    }
}

// QR Scanner View for XPub Import
struct XPubImportQRScannerView: UIViewControllerRepresentable {
    let completion: (Result<String, Error>) -> Void
    
    func makeUIViewController(context: Context) -> XPubImportQRScannerViewController {
        let controller = XPubImportQRScannerViewController()
        controller.completion = completion
        return controller
    }
    
    func updateUIViewController(_ uiViewController: XPubImportQRScannerViewController, context: Context) {}
}

class XPubImportQRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var completion: ((Result<String, Error>) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            completion?(.failure(QRScannerError.noCamera))
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            completion?(.failure(error))
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            completion?(.failure(QRScannerError.invalidInput))
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            completion?(.failure(QRScannerError.invalidOutput))
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            captureSession.stopRunning()
            completion?(.success(stringValue))
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
}

enum QRScannerError: Error {
    case noCamera
    case invalidInput
    case invalidOutput
}

extension Character {
    var isHexDigit: Bool {
        return isNumber || (isLetter && (self >= "a" && self <= "f") || (self >= "A" && self <= "F"))
    }
} 