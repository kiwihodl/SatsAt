//
//  SatsatApp.swift
//  Satsat
//
//  Created by Kiwi_ on 7/31/25.
//

import SwiftUI
import UserNotifications
import CoreData

@main
struct SatsatApp: App {
    // Core managers
    @StateObject private var coreDataManager = CoreDataManager.shared
    @StateObject private var nostrClient = NostrClient.shared
    @StateObject private var biometricAuth = BiometricAuthManager.shared
    @StateObject private var groupManager = GroupManager.shared
    @StateObject private var psbtManager = PSBTManager.shared
    @StateObject private var messageManager = MessageManager.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var lightningManager = LightningManager.shared
    @StateObject private var nwcLightningManager = NWCLightningManager.shared
    @StateObject private var backgroundTaskService = BackgroundTaskService.shared
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(coreDataManager)
                .environmentObject(nostrClient)
                .environmentObject(biometricAuth)
                .environmentObject(groupManager)
                .environmentObject(psbtManager)
                .environmentObject(messageManager)
                .environmentObject(notificationService)
                .environmentObject(lightningManager)
                .environmentObject(nwcLightningManager)
                .environmentObject(backgroundTaskService)
                .preferredColorScheme(.dark) // Default to dark mode
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Setup notification system
        Task {
            _ = await notificationService.requestPermission()
            notificationService.setupNotificationCategories()
        }
        
        // Configure background task service
        backgroundTaskService.configure(
            groupManager: groupManager,
            psbtManager: psbtManager,
            lightningManager: lightningManager,
            notificationService: notificationService
        )
        
        // Check biometric availability
        biometricAuth.checkBiometricAvailability()
        
        // Connect to Nostr relays
        nostrClient.connect()
    }
}

// MARK: - App Root View with Compliance Flow

struct AppRootView: View {
    @State private var authState: AuthState = .checking
    @State private var hasNostrKeys = false
    
    enum AuthState {
        case checking
        case needsOnboarding
        case needsAuth
        case authenticated
    }
    
    var body: some View {
        Group {
            switch authState {
            case .checking:
                SplashView()
            case .needsOnboarding:
                ComplianceOnboardingView()
                    .onReceive(NotificationCenter.default.publisher(for: .complianceOnboardingCompleted)) { _ in
                        checkAuthState()
                    }
            case .needsAuth:
                AuthSetupView()
                    .onReceive(NotificationCenter.default.publisher(for: .authenticationCompleted)) { _ in
                        checkAuthState()
                    }
            case .authenticated:
                ContentView()
            }
        }
        .onAppear {
            checkAuthState()
        }
    }
    
    private func checkAuthState() {
        // Check compliance onboarding
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedComplianceOnboarding")
        print("📋 Compliance onboarding completed: \(hasCompletedOnboarding)")
        
        if !hasCompletedOnboarding {
            authState = .needsOnboarding
            return
        }
        
        // Check if user has Nostr keys
        let userId = UserDefaults.standard.string(forKey: "currentUserId") ?? UUID().uuidString
        UserDefaults.standard.set(userId, forKey: "currentUserId")
        
        do {
            let _ = try KeychainManager.shared.retrieveNostrPrivateKey(for: userId)
            print("🔑 User has existing Nostr keys")
            
            // Check if user profile exists in CoreData
            let context = CoreDataManager.shared.viewContext
            if let _ = try? UserProfile.fetchCurrentUser(userId: userId, context: context) {
                print("✅ User profile found, authenticated")
                hasNostrKeys = true
                authState = .authenticated
            } else {
                print("❌ User profile missing, need to create profile")
                hasNostrKeys = false
                authState = .needsAuth
            }
        } catch {
            hasNostrKeys = false
            authState = .needsAuth
            print("🔑 User needs to set up Nostr keys")
        }
    }
}

struct SplashView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "at.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("Satsat")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            ProgressView()
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct AuthSetupView: View {
    @State private var isGeneratingKeys = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "key.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("Create Your Account")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                Text("We'll generate your secure Nostr identity for Bitcoin savings groups.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.green)
                        Text("Private Key: Stored securely on your device")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        Text("Public Key: Your unique identity for groups")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            Button(action: generateKeys) {
                HStack {
                    if isGeneratingKeys {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    Text(isGeneratingKeys ? "Creating Account..." : "Create Account")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.orange)
                .cornerRadius(12)
            }
            .disabled(isGeneratingKeys)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .alert("Setup Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func generateKeys() {
        isGeneratingKeys = true
        
        Task {
            do {
                let userId = UserDefaults.standard.string(forKey: "currentUserId") ?? UUID().uuidString
                UserDefaults.standard.set(userId, forKey: "currentUserId")
                print("🔑 Creating account with userId: \(userId)")
                
                // Check if user already has keys but missing profile
                do {
                    let existingPrivateKey = try KeychainManager.shared.retrieveNostrPrivateKey(for: userId)
                    let publicKey = derivePublicKey(from: existingPrivateKey)
                    print("🔑 Found existing keys, creating missing profile")
                    
                    // Create user profile in CoreData
                    try await createUserProfile(userId: userId, publicKey: publicKey)
                } catch {
                    // Generate new Nostr private key
                    let privateKey = generatePrivateKey()
                    let publicKey = derivePublicKey(from: privateKey)
                    
                    // Store in keychain
                    try KeychainManager.shared.storeNostrPrivateKey(privateKey, for: userId)
                    print("🔑 Generated new keys for userId: \(userId)")
                    
                    // Create user profile in CoreData
                    try await createUserProfile(userId: userId, publicKey: publicKey)
                }
                
                // Mark as authenticated
                await MainActor.run {
                    isGeneratingKeys = false
                    NotificationCenter.default.post(name: .authenticationCompleted, object: nil)
                }
                
            } catch {
                await MainActor.run {
                    isGeneratingKeys = false
                    errorMessage = "Failed to generate keys: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func createUserProfile(userId: String, publicKey: String) async throws {
        let context = CoreDataManager.shared.viewContext
        
        try await MainActor.run {
            print("🔨 Creating user profile for userId: \(userId)")
            
            // Check if profile already exists
            if let existingProfile = try? UserProfile.fetchCurrentUser(userId: userId, context: context) {
                print("⚠️ User profile already exists: \(existingProfile.displayName)")
                return
            }
            
            let userProfile = UserProfile(context: context)
            userProfile.userId = userId
            userProfile.displayName = "User" // Default name, can be changed later
            userProfile.nostrPubkey = publicKey
            userProfile.avatarColor = "#FF9500" // Orange default
            userProfile.createdAt = Date()
            userProfile.lastSeen = Date()
            userProfile.isActive = true
            
            print("🔨 Saving user profile to CoreData...")
            try context.save()
            print("✅ User profile created successfully")
            
            // Verify creation
            if let verifyProfile = try? UserProfile.fetchCurrentUser(userId: userId, context: context) {
                print("✅ Profile verification successful: \(verifyProfile.displayName)")
            } else {
                print("❌ Profile verification failed - could not find created profile")
            }
        }
    }
    
    private func derivePublicKey(from privateKey: String) -> String {
        // Simple public key derivation - in production would use proper secp256k1
        return "npub" + privateKey.suffix(8) + String(privateKey.prefix(8))
    }
    
    private func generatePrivateKey() -> String {
        // Generate a 32-byte private key
        var keyData = Data(count: 32)
        let result = keyData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        if result == errSecSuccess {
            return keyData.map { String(format: "%02x", $0) }.joined()
        } else {
            // Fallback to UUID-based key generation
            return UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }
    }
}

extension Notification.Name {
    static let authenticationCompleted = Notification.Name("authenticationCompleted")
}
