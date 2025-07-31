// ExternalServicesView.swift
// App Store compliant external service links for Bitcoin acquisition

import SwiftUI

// MARK: - External Services View

struct ExternalServicesView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: SatsatDesignSystem.Spacing.xl) {
                    // Header
                    headerSection
                    
                    // Educational disclaimer
                    educationalDisclaimerSection
                    
                    // External services
                    externalServicesSection
                    
                    // Additional disclaimers
                    finalDisclaimerSection
                    
                    Spacer(minLength: SatsatDesignSystem.Spacing.xl)
                }
                .padding(SatsatDesignSystem.Spacing.lg)
            }
            .background(SatsatDesignSystem.Colors.backgroundPrimary)
            .navigationTitle("Get Bitcoin")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(SatsatDesignSystem.Colors.info)
            
            Text("External Bitcoin Services")
                .font(SatsatDesignSystem.Typography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("To add Bitcoin to your educational savings groups, you'll need to obtain Bitcoin from these external licensed services.")
                .font(SatsatDesignSystem.Typography.body)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var educationalDisclaimerSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(SatsatDesignSystem.Colors.info)
                
                Text("Educational Reminder")
                    .font(SatsatDesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            Text("Satsat is an educational app that teaches Bitcoin concepts. These external services are required for obtaining actual Bitcoin to use in your learning experience.")
                .font(SatsatDesignSystem.Typography.subheadline)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
        }
        .padding(SatsatDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                .fill(SatsatDesignSystem.Colors.info.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                        .stroke(SatsatDesignSystem.Colors.info.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var externalServicesSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            HStack {
                Text("Recommended Services")
                    .font(SatsatDesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: SatsatDesignSystem.Spacing.md) {
                ExternalServiceCard(
                    name: "Strike",
                    description: "Lightning-fast Bitcoin transactions with low fees",
                    url: "https://strike.me",
                    icon: "bolt.fill",
                    color: .orange,
                    features: ["Lightning Network", "Low Fees", "Easy Setup"]
                )
                
                ExternalServiceCard(
                    name: "Cash App",
                    description: "Popular mobile app with Bitcoin support",
                    url: "https://cash.app",
                    icon: "dollarsign.circle.fill",
                    color: .green,
                    features: ["User Friendly", "Instant Deposits", "Well Established"]
                )
                
                ExternalServiceCard(
                    name: "Coinbase",
                    description: "Large, regulated cryptocurrency exchange",
                    url: "https://coinbase.com",
                    icon: "building.2.fill",
                    color: .blue,
                    features: ["Highly Regulated", "Educational Resources", "Global Availability"]
                )
                
                ExternalServiceCard(
                    name: "Swan Bitcoin",
                    description: "Bitcoin-only service focused on savings",
                    url: "https://swanbitcoin.com",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple,
                    features: ["Bitcoin Only", "Dollar Cost Averaging", "Educational Focus"]
                )
            }
        }
    }
    
    private var finalDisclaimerSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(SatsatDesignSystem.Colors.warning)
                
                Text("Important Disclaimers")
                    .font(SatsatDesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.sm) {
                DisclaimerPoint(text: "Satsat does not endorse, operate, or take responsibility for any external services")
                DisclaimerPoint(text: "Bitcoin involves significant financial risk - only use amounts you can afford to lose")
                DisclaimerPoint(text: "These services are independent and subject to their own terms and regulations")
                DisclaimerPoint(text: "Always research and understand any service before using it")
                DisclaimerPoint(text: "Satsat provides educational content only, not financial advice")
            }
        }
        .padding(SatsatDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                .fill(SatsatDesignSystem.Colors.warning.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                        .stroke(SatsatDesignSystem.Colors.warning.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Supporting Components

struct ExternalServiceCard: View {
    let name: String
    let description: String
    let url: String
    let icon: String
    let color: Color
    let features: [String]
    
    var body: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            // Header
            HStack(spacing: SatsatDesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(SatsatDesignSystem.Typography.headline)
                        .fontWeight(.bold)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Text(description)
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square.fill")
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            // Features
            HStack(spacing: SatsatDesignSystem.Spacing.sm) {
                ForEach(features, id: \.self) { feature in
                    Text(feature)
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(color.opacity(0.1))
                        )
                }
                
                Spacer()
            }
            
            // Action button
            Button("Visit \(name)") {
                openExternalService(url: url)
                HapticFeedback.medium()
            }
            .satsatSecondaryButton()
            .foregroundColor(color)
        }
        .padding(SatsatDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                .fill(SatsatDesignSystem.Colors.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func openExternalService(url: String) {
        guard let serviceURL = URL(string: url) else { return }
        UIApplication.shared.open(serviceURL)
    }
}

struct DisclaimerPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: SatsatDesignSystem.Spacing.sm) {
            Image(systemName: "circle.fill")
                .font(.caption)
                .foregroundColor(SatsatDesignSystem.Colors.warning)
                .padding(.top, 4)
            
            Text(text)
                .font(SatsatDesignSystem.Typography.subheadline)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            
            Spacer()
        }
    }
}

// MARK: - Educational Flow Integration

extension ExternalServicesView {
    /// Helper method to create educational messaging for receive flows
    static func educationalReceiveMessage() -> some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(SatsatDesignSystem.Colors.info)
                
                Text("Learning Experience")
                    .font(SatsatDesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            Text("To practice Bitcoin deposits in this educational app, obtain Bitcoin from external licensed services like Strike, Cash App, or Coinbase, then send to the address below.")
                .font(SatsatDesignSystem.Typography.subheadline)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
        }
        .padding(SatsatDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                .fill(SatsatDesignSystem.Colors.info.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                        .stroke(SatsatDesignSystem.Colors.info.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    ExternalServicesView()
}