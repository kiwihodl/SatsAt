// QRCodeScanner.swift
// Camera-based QR code scanner for Bitcoin addresses and invites

import SwiftUI
import AVFoundation
import VisionKit

// MARK: - QR Code Scanner View

struct QRCodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onError: (ScanError) -> Void
    
    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let scanner = QRCodeScannerViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onError: onError)
    }
    
    class Coordinator: NSObject, QRCodeScannerDelegate {
        let onScan: (String) -> Void
        let onError: (ScanError) -> Void
        
        init(onScan: @escaping (String) -> Void, onError: @escaping (ScanError) -> Void) {
            self.onScan = onScan
            self.onError = onError
        }
        
        func qrScanner(_ scanner: QRCodeScannerViewController, didScan code: String) {
            onScan(code)
        }
        
        func qrScanner(_ scanner: QRCodeScannerViewController, didFailWithError error: ScanError) {
            onError(error)
        }
    }
}

// MARK: - Scanner Delegate Protocol

protocol QRCodeScannerDelegate: AnyObject {
    func qrScanner(_ scanner: QRCodeScannerViewController, didScan code: String)
    func qrScanner(_ scanner: QRCodeScannerViewController, didFailWithError error: ScanError)
}

// MARK: - Scanner View Controller

class QRCodeScannerViewController: UIViewController {
    weak var delegate: QRCodeScannerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var scannerOverlay: ScannerOverlayView!
    
    private var hasScanned = false
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupOverlay()
        setupHaptics()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            delegate?.qrScanner(self, didFailWithError: .cameraUnavailable)
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureMetadataOutput()
            
            captureSession = AVCaptureSession()
            captureSession?.addInput(input)
            captureSession?.addOutput(output)
            
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            previewLayer?.frame = view.layer.bounds
            previewLayer?.videoGravity = .resizeAspectFill
            
            view.layer.addSublayer(previewLayer!)
            
        } catch {
            delegate?.qrScanner(self, didFailWithError: .cameraSetupFailed)
        }
    }
    
    private func setupOverlay() {
        scannerOverlay = ScannerOverlayView()
        scannerOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scannerOverlay)
        
        NSLayoutConstraint.activate([
            scannerOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            scannerOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scannerOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scannerOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupHaptics() {
        hapticFeedback.prepare()
    }
    
    // MARK: - Scanning Control
    
    private func startScanning() {
        hasScanned = false
        captureSession?.startRunning()
    }
    
    private func stopScanning() {
        captureSession?.stopRunning()
    }
    
    func resetScanning() {
        hasScanned = false
        startScanning()
    }
    
    // MARK: - Scan Processing
    
    private func processScannedCode(_ code: String) {
        guard !hasScanned else { return }
        hasScanned = true
        
        // Haptic feedback
        hapticFeedback.impactOccurred()
        
        // Visual feedback
        scannerOverlay.showSuccessAnimation()
        
        // Stop scanning temporarily
        stopScanning()
        
        // Notify delegate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.delegate?.qrScanner(self, didScan: code)
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRCodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }
        
        processScannedCode(stringValue)
    }
}

// MARK: - Scanner Overlay View

class ScannerOverlayView: UIView {
    private let scanArea = CGRect(x: 50, y: 200, width: 250, height: 250)
    private var animationLayer: CAShapeLayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Semi-transparent overlay
        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        context.fill(rect)
        
        // Clear scan area
        let scanRect = CGRect(
            x: (rect.width - 250) / 2,
            y: (rect.height - 250) / 2,
            width: 250,
            height: 250
        )
        
        context.setBlendMode(.clear)
        context.fill(scanRect)
        context.setBlendMode(.normal)
        
        // Draw corner indicators
        drawCornerIndicators(in: scanRect, context: context)
        
        // Draw instructions
        drawInstructions(in: rect, scanRect: scanRect, context: context)
    }
    
    private func drawCornerIndicators(in scanRect: CGRect, context: CGContext) {
        let cornerLength: CGFloat = 20
        let cornerWidth: CGFloat = 3
        
        context.setStrokeColor(UIColor.orange.cgColor)
        context.setLineWidth(cornerWidth)
        
        // Top-left corner
        context.move(to: CGPoint(x: scanRect.minX, y: scanRect.minY + cornerLength))
        context.addLine(to: CGPoint(x: scanRect.minX, y: scanRect.minY))
        context.addLine(to: CGPoint(x: scanRect.minX + cornerLength, y: scanRect.minY))
        
        // Top-right corner
        context.move(to: CGPoint(x: scanRect.maxX - cornerLength, y: scanRect.minY))
        context.addLine(to: CGPoint(x: scanRect.maxX, y: scanRect.minY))
        context.addLine(to: CGPoint(x: scanRect.maxX, y: scanRect.minY + cornerLength))
        
        // Bottom-left corner
        context.move(to: CGPoint(x: scanRect.minX, y: scanRect.maxY - cornerLength))
        context.addLine(to: CGPoint(x: scanRect.minX, y: scanRect.maxY))
        context.addLine(to: CGPoint(x: scanRect.minX + cornerLength, y: scanRect.maxY))
        
        // Bottom-right corner
        context.move(to: CGPoint(x: scanRect.maxX - cornerLength, y: scanRect.maxY))
        context.addLine(to: CGPoint(x: scanRect.maxX, y: scanRect.maxY))
        context.addLine(to: CGPoint(x: scanRect.maxX, y: scanRect.maxY - cornerLength))
        
        context.strokePath()
    }
    
    private func drawInstructions(in rect: CGRect, scanRect: CGRect, context: CGContext) {
        let instructionText = "Position QR code within the frame"
        let font = UIFont.systemFont(ofSize: 16, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        
        let textSize = instructionText.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (rect.width - textSize.width) / 2,
            y: scanRect.maxY + 30,
            width: textSize.width,
            height: textSize.height
        )
        
        instructionText.draw(in: textRect, withAttributes: attributes)
    }
    
    func showSuccessAnimation() {
        let animation = CABasicAnimation(keyPath: "backgroundColor")
        animation.fromValue = UIColor.clear.cgColor
        animation.toValue = UIColor.green.withAlphaComponent(0.3).cgColor
        animation.duration = 0.3
        animation.autoreverses = true
        
        layer.add(animation, forKey: "successFlash")
    }
}

// MARK: - Scan Error Types

enum ScanError: Error, LocalizedError {
    case cameraUnavailable
    case cameraSetupFailed
    case permissionDenied
    case invalidCode
    
    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera is not available on this device"
        case .cameraSetupFailed:
            return "Failed to set up camera for scanning"
        case .permissionDenied:
            return "Camera permission denied"
        case .invalidCode:
            return "Invalid QR code format"
        }
    }
}

// MARK: - Camera Permission Helper

class CameraPermissionManager {
    static func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    static var isCameraPermissionGranted: Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
}

// MARK: - SwiftUI Integration

struct CameraQRScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var showingPermissionAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var hasPermission = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if hasPermission {
                    QRCodeScannerView(
                        onScan: { code in
                            onScan(code)
                            dismiss()
                        },
                        onError: { error in
                            errorMessage = error.localizedDescription
                            showingErrorAlert = true
                        }
                    )
                } else {
                    permissionView
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Manual Entry") {
                        // Handle manual entry
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            checkCameraPermission()
        }
        .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Please enable camera access in Settings to scan QR codes.")
        }
        .alert("Scan Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var permissionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("To scan QR codes, Satsat needs access to your camera. This allows you to easily scan Bitcoin addresses and group invites.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Enable Camera") {
                requestCameraPermission()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.orange)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private func checkCameraPermission() {
        hasPermission = CameraPermissionManager.isCameraPermissionGranted
    }
    
    private func requestCameraPermission() {
        CameraPermissionManager.requestCameraPermission { granted in
            if granted {
                hasPermission = true
            } else {
                showingPermissionAlert = true
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}