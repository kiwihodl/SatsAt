//
//  SatsatApp.swift
//  Satsat
//
//  Created by Kiwi_ on 7/31/25.
//

import SwiftUI
import UserNotifications

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
    @State private var showingComplianceOnboarding = false
    
    var body: some View {
        Group {
            if needsComplianceOnboarding {
                ComplianceOnboardingView()
            } else {
                ContentView()
            }
        }
        .onAppear {
            checkComplianceStatus()
        }
    }
    
    private var needsComplianceOnboarding: Bool {
        return !UserDefaults.standard.bool(forKey: "hasCompletedComplianceOnboarding")
    }
    
    private func checkComplianceStatus() {
        // Log compliance status for debugging
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedComplianceOnboarding")
        print("📋 Compliance onboarding completed: \(hasCompleted)")
        
        if let completionDate = UserDefaults.standard.object(forKey: "complianceOnboardingDate") as? Date {
            print("📅 Compliance completed on: \(completionDate)")
        }
    }
}
