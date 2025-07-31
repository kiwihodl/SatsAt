// ComplianceOnboardingView.swift
// App Store compliant onboarding with educational disclaimers

import SwiftUI

// MARK: - Compliance Onboarding View

struct ComplianceOnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPage = 0
    @State private var hasAgreedToTerms = false
    @State private var hasConfirmedAge = false
    @State private var showingTerms = false
    @State private var showingPrivacyPolicy = false
    
    private let totalPages = 4
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Page content
                TabView(selection: $currentPage) {
                    educationalPurposePage.tag(0)
                    bitcoinEducationPage.tag(1)
                    riskDisclaimerPage.tag(2)
                    agreementPage.tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Navigation buttons
                navigationButtons
            }
            .background(SatsatDesignSystem.Colors.backgroundPrimary)
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingTerms) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
    
    // MARK: - View Components
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index <= currentPage ? SatsatDesignSystem.Colors.satsatOrange : SatsatDesignSystem.Colors.backgroundSecondary)
                    .frame(height: 4)
                    .animation(.easeInOut, value: currentPage)
            }
        }
        .padding(.horizontal, SatsatDesignSystem.Spacing.lg)
        .padding(.top, SatsatDesignSystem.Spacing.lg)
    }
    
    private var educationalPurposePage: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.xl) {
            Spacer()
            
            // Icon
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 80))
                .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                .padding(.bottom, SatsatDesignSystem.Spacing.lg)
            
            // Title
            Text("Educational Purpose")
                .font(SatsatDesignSystem.Typography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Description
            VStack(spacing: SatsatDesignSystem.Spacing.md) {
                Text("Satsat is designed for learning about Bitcoin and collaborative savings.")
                    .font(SatsatDesignSystem.Typography.title3)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("This app does not sell, exchange, or provide Bitcoin. It teaches Bitcoin concepts through hands-on educational experience.")
                    .font(SatsatDesignSystem.Typography.body)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, SatsatDesignSystem.Spacing.xl)
    }
    
    private var bitcoinEducationPage: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.xl) {
            Spacer()
            
            // Icon
            Image(systemName: "book.closed.fill")
                .font(.system(size: 80))
                .foregroundColor(SatsatDesignSystem.Colors.info)
                .padding(.bottom, SatsatDesignSystem.Spacing.lg)
            
            // Title
            Text("Learning About Bitcoin")
                .font(SatsatDesignSystem.Typography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Features
            VStack(spacing: SatsatDesignSystem.Spacing.lg) {
                EducationalFeatureRow(
                    icon: "person.3.fill",
                    title: "Collaborative Savings",
                    description: "Learn to save Bitcoin with trusted friends"
                )
                
                EducationalFeatureRow(
                    icon: "lock.shield.fill",
                    title: "Multisig Security",
                    description: "Understand advanced Bitcoin security concepts"
                )
                
                EducationalFeatureRow(
                    icon: "signature",
                    title: "Transaction Signing",
                    description: "Practice Bitcoin transaction coordination"
                )
                
                EducationalFeatureRow(
                    icon: "message.fill",
                    title: "Encrypted Communication",
                    description: "Learn about secure group messaging"
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, SatsatDesignSystem.Spacing.xl)
    }
    
    private var riskDisclaimerPage: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.xl) {
            Spacer()
            
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(SatsatDesignSystem.Colors.warning)
                .padding(.bottom, SatsatDesignSystem.Spacing.lg)
            
            // Title
            Text("Important Disclaimers")
                .font(SatsatDesignSystem.Typography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Risk warnings
            VStack(spacing: SatsatDesignSystem.Spacing.lg) {
                DisclaimerRow(
                    icon: "dollarsign.circle.fill",
                    title: "Financial Risk",
                    description: "Bitcoin involves significant financial risk. Only use amounts you can afford to lose."
                )
                
                DisclaimerRow(
                    icon: "person.crop.circle.badge.questionmark",
                    title: "No Financial Advice",
                    description: "This app does not provide financial, investment, or tax advice."
                )
                
                DisclaimerRow(
                    icon: "building.2.crop.circle.fill",
                    title: "External Services Required",
                    description: "To obtain Bitcoin, you must use external licensed services like Strike, Cash App, or Coinbase."
                )
                
                DisclaimerRow(
                    icon: "person.fill.checkmark",
                    title: "Your Responsibility",
                    description: "You are responsible for understanding Bitcoin technology and associated risks."
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, SatsatDesignSystem.Spacing.xl)
    }
    
    private var agreementPage: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.xl) {
            Spacer()
            
            // Checkmark icon
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(SatsatDesignSystem.Colors.success)
                .padding(.bottom, SatsatDesignSystem.Spacing.lg)
            
            // Title
            Text("Ready to Learn?")
                .font(SatsatDesignSystem.Typography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Agreement checkboxes
            VStack(spacing: SatsatDesignSystem.Spacing.lg) {
                // Age confirmation
                HStack(spacing: SatsatDesignSystem.Spacing.md) {
                    Button(action: {
                        hasConfirmedAge.toggle()
                        HapticFeedback.light()
                    }) {
                        Image(systemName: hasConfirmedAge ? "checkmark.square.fill" : "square")
                            .font(.title2)
                            .foregroundColor(hasConfirmedAge ? SatsatDesignSystem.Colors.success : SatsatDesignSystem.Colors.textSecondary)
                    }
                    
                    Text("I confirm that I am 17 years of age or older")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Spacer()
                }
                
                // Terms agreement
                HStack(spacing: SatsatDesignSystem.Spacing.md) {
                    Button(action: {
                        hasAgreedToTerms.toggle()
                        HapticFeedback.light()
                    }) {
                        Image(systemName: hasAgreedToTerms ? "checkmark.square.fill" : "square")
                            .font(.title2)
                            .foregroundColor(hasAgreedToTerms ? SatsatDesignSystem.Colors.success : SatsatDesignSystem.Colors.textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("I have read and agree to the")
                            .font(SatsatDesignSystem.Typography.subheadline)
                            .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                        
                        HStack(spacing: 8) {
                            Button("Terms of Service") {
                                showingTerms = true
                            }
                            .font(SatsatDesignSystem.Typography.subheadline)
                            .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                            
                            Text("and")
                                .font(SatsatDesignSystem.Typography.subheadline)
                                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                            
                            Button("Privacy Policy") {
                                showingPrivacyPolicy = true
                            }
                            .font(SatsatDesignSystem.Typography.subheadline)
                            .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, SatsatDesignSystem.Spacing.md)
            .padding(.vertical, SatsatDesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                    .fill(SatsatDesignSystem.Colors.backgroundCard)
            )
            
            // Final disclaimer
            Text("By proceeding, you acknowledge this is an educational tool for learning Bitcoin concepts.")
                .font(SatsatDesignSystem.Typography.caption)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SatsatDesignSystem.Spacing.lg)
            
            Spacer()
        }
        .padding(.horizontal, SatsatDesignSystem.Spacing.xl)
    }
    
    private var navigationButtons: some View {
        HStack(spacing: SatsatDesignSystem.Spacing.md) {
            // Back button
            if currentPage > 0 {
                Button("Back") {
                    withAnimation {
                        currentPage -= 1
                    }
                    HapticFeedback.light()
                }
                .satsatSecondaryButton()
            }
            
            Spacer()
            
            // Next/Complete button
            if currentPage < totalPages - 1 {
                Button("Next") {
                    withAnimation {
                        currentPage += 1
                    }
                    HapticFeedback.light()
                }
                .satsatPrimaryButton()
            } else {
                Button("Start Learning") {
                    completeOnboarding()
                    HapticFeedback.success()
                }
                .satsatPrimaryButton()
                .disabled(!canProceed)
            }
        }
        .padding(.horizontal, SatsatDesignSystem.Spacing.lg)
        .padding(.bottom, SatsatDesignSystem.Spacing.xl)
    }
    
    // MARK: - Computed Properties
    
    private var canProceed: Bool {
        return hasAgreedToTerms && hasConfirmedAge
    }
    
    // MARK: - Actions
    
    private func completeOnboarding() {
        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedComplianceOnboarding")
        UserDefaults.standard.set(Date(), forKey: "complianceOnboardingDate")
        
        dismiss()
    }
}

// MARK: - Supporting Components

struct EducationalFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: SatsatDesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SatsatDesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

struct DisclaimerRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: SatsatDesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(SatsatDesignSystem.Colors.warning)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SatsatDesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Terms and Privacy Views (Placeholders)

struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.lg) {
                    Text("Terms of Service")
                        .font(SatsatDesignSystem.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Group {
                        termsSection(title: "1. Educational Purpose", content: "Satsat is an educational application designed to teach Bitcoin concepts through hands-on experience. This app does not provide financial advice, sell Bitcoin, or operate as a financial exchange.")
                        
                        termsSection(title: "2. User Responsibilities", content: "Users are responsible for understanding Bitcoin technology, associated risks, and obtaining Bitcoin through external licensed services. Users must be 17 years of age or older.")
                        
                        termsSection(title: "3. Financial Risks", content: "Bitcoin involves significant financial risk. Users should only use amounts they can afford to lose. Satsat is not responsible for any financial losses.")
                        
                        termsSection(title: "4. External Services", content: "To obtain Bitcoin, users must use external licensed services. Satsat does not endorse or take responsibility for any external services.")
                        
                        termsSection(title: "5. Data and Privacy", content: "User data is encrypted and stored locally. See our Privacy Policy for detailed information about data handling.")
                    }
                }
                .padding(SatsatDesignSystem.Spacing.lg)
            }
            .background(SatsatDesignSystem.Colors.backgroundPrimary)
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func termsSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.sm) {
            Text(title)
                .font(SatsatDesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
            
            Text(content)
                .font(SatsatDesignSystem.Typography.body)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.lg) {
                    Text("Privacy Policy")
                        .font(SatsatDesignSystem.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Group {
                        privacySection(title: "Data Collection", content: "Satsat collects minimal data necessary for educational functionality. All sensitive data is encrypted locally on your device.")
                        
                        privacySection(title: "Data Storage", content: "Your Bitcoin keys, messages, and group data are encrypted using AES-256-GCM encryption and stored locally on your device using iOS Keychain.")
                        
                        privacySection(title: "Data Sharing", content: "Satsat does not share your personal data with third parties. Group messages are encrypted end-to-end between group members only.")
                        
                        privacySection(title: "Analytics", content: "No personal analytics or tracking data is collected. Crash reports may be sent anonymously to improve app stability.")
                        
                        privacySection(title: "Contact", content: "For privacy questions, contact us at privacy@satsat.app")
                    }
                }
                .padding(SatsatDesignSystem.Spacing.lg)
            }
            .background(SatsatDesignSystem.Colors.backgroundPrimary)
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func privacySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.sm) {
            Text(title)
                .font(SatsatDesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
            
            Text(content)
                .font(SatsatDesignSystem.Typography.body)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    ComplianceOnboardingView()
}