// TestRunnerView.swift
// Developer test runner interface for comprehensive testing

import SwiftUI

// MARK: - Test Runner View

struct TestRunnerView: View {
    @StateObject private var testSuite = ComprehensiveTestSuite.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingReport = false
    @State private var testReport = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Test Results
                ScrollView {
                    LazyVStack(spacing: SatsatDesignSystem.Spacing.md) {
                        if testSuite.testResults.isEmpty && !testSuite.isRunning {
                            emptyStateSection
                        } else {
                            ForEach(testSuite.testResults) { result in
                                TestResultRow(result: result)
                            }
                        }
                        
                        Spacer(minLength: SatsatDesignSystem.Spacing.xl)
                    }
                    .padding(SatsatDesignSystem.Spacing.md)
                }
                
                // Action Buttons
                actionButtonsSection
            }
            .background(SatsatDesignSystem.Colors.backgroundPrimary)
            .navigationTitle("App Testing")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Report") {
                        generateReport()
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                    .disabled(testSuite.testResults.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingReport) {
            TestReportView(report: testReport)
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            // Overall status
            HStack(spacing: SatsatDesignSystem.Spacing.md) {
                Image(systemName: testSuite.overallStatus.icon)
                    .font(.title2)
                    .foregroundColor(testSuite.overallStatus.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall Status")
                        .font(SatsatDesignSystem.Typography.headline)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                    
                    Text(testSuite.overallStatus.displayName)
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(testSuite.overallStatus.color)
                }
                
                Spacer()
                
                if testSuite.isRunning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: SatsatDesignSystem.Colors.satsatOrange))
                        .scaleEffect(0.8)
                }
            }
            
            // Test summary
            if !testSuite.testResults.isEmpty {
                testSummarySection
            }
            
            // Current test indicator
            if testSuite.isRunning {
                VStack(spacing: 8) {
                    Text("Running Tests...")
                        .font(SatsatDesignSystem.Typography.subheadline)
                        .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    
                    Text(testSuite.currentTest)
                        .font(SatsatDesignSystem.Typography.caption)
                        .foregroundColor(SatsatDesignSystem.Colors.warning)
                        .multilineTextAlignment(.center)
                }
                .padding(SatsatDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                        .fill(SatsatDesignSystem.Colors.backgroundCard)
                )
            }
        }
        .padding(SatsatDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.large)
                .fill(SatsatDesignSystem.Colors.backgroundCard)
        )
        .padding(.horizontal, SatsatDesignSystem.Spacing.md)
    }
    
    private var testSummarySection: some View {
        HStack(spacing: SatsatDesignSystem.Spacing.lg) {
            TestSummaryItem(
                count: testSuite.testResults.filter { $0.status == .passed }.count,
                label: "Passed",
                color: SatsatDesignSystem.Colors.success
            )
            
            TestSummaryItem(
                count: testSuite.testResults.filter { $0.status == .failed }.count,
                label: "Failed",
                color: SatsatDesignSystem.Colors.error
            )
            
            TestSummaryItem(
                count: testSuite.testResults.filter { $0.status == .warning }.count,
                label: "Warnings",
                color: SatsatDesignSystem.Colors.warning
            )
        }
        .padding(SatsatDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                .fill(SatsatDesignSystem.Colors.backgroundSecondary)
        )
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.lg) {
            Image(systemName: "testtube.2")
                .font(.system(size: 80))
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            
            Text("Ready to Test")
                .font(SatsatDesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
            
            Text("Run comprehensive tests to validate app functionality and App Store readiness.")
                .font(SatsatDesignSystem.Typography.body)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SatsatDesignSystem.Spacing.xl)
            
            VStack(spacing: SatsatDesignSystem.Spacing.md) {
                TestCategoryPreview(title: "Security", icon: "shield.checkerboard", description: "Keychain, encryption, biometrics")
                TestCategoryPreview(title: "Bitcoin", icon: "bitcoinsign.circle", description: "Multisig, PSBT, transactions")
                TestCategoryPreview(title: "Lightning", icon: "bolt.fill", description: "Invoices, payments, NWC")
                TestCategoryPreview(title: "Compliance", icon: "checkmark.seal", description: "App Store guidelines")
            }
            .padding(.top, SatsatDesignSystem.Spacing.lg)
        }
        .padding(.vertical, SatsatDesignSystem.Spacing.xl)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: SatsatDesignSystem.Spacing.md) {
            Button("Run All Tests") {
                runTests()
                HapticFeedback.medium()
            }
            .satsatPrimaryButton(isLoading: testSuite.isRunning)
            .disabled(testSuite.isRunning)
            .padding(.horizontal)
            
            if !testSuite.testResults.isEmpty {
                HStack(spacing: SatsatDesignSystem.Spacing.md) {
                    Button("Clear Results") {
                        clearResults()
                        HapticFeedback.light()
                    }
                    .satsatSecondaryButton()
                    
                    Button("Generate Report") {
                        generateReport()
                        HapticFeedback.light()
                    }
                    .satsatSecondaryButton()
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, SatsatDesignSystem.Spacing.lg)
        .background(
            Rectangle()
                .fill(SatsatDesignSystem.Colors.backgroundPrimary)
                .shadow(color: SatsatDesignSystem.Shadows.medium, radius: 8, x: 0, y: -2)
        )
    }
    
    // MARK: - Actions
    
    private func runTests() {
        Task {
            await testSuite.runAllTests()
        }
    }
    
    private func clearResults() {
        testSuite.testResults.removeAll()
        testSuite.overallStatus = .notStarted
    }
    
    private func generateReport() {
        testReport = testSuite.generateTestReport()
        showingReport = true
    }
}

// MARK: - Supporting Components

struct TestResultRow: View {
    let result: TestResult
    
    var body: some View {
        HStack(spacing: SatsatDesignSystem.Spacing.md) {
            // Status icon
            Image(systemName: result.status.icon)
                .font(.title3)
                .foregroundColor(result.status.color)
                .frame(width: 32)
            
            // Test details
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(SatsatDesignSystem.Typography.headline)
                    .fontWeight(.medium)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Text(result.message)
                    .font(SatsatDesignSystem.Typography.subheadline)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                
                Text(result.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(SatsatDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                .fill(SatsatDesignSystem.Colors.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                        .stroke(result.status.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct TestSummaryItem: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(SatsatDesignSystem.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(SatsatDesignSystem.Typography.caption)
                .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TestCategoryPreview: View {
    let title: String
    let icon: String
    let description: String
    
    var body: some View {
        HStack(spacing: SatsatDesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
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
        }
        .padding(SatsatDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.small)
                .fill(SatsatDesignSystem.Colors.backgroundSecondary)
        )
    }
}

// MARK: - Test Report View

struct TestReportView: View {
    let report: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.lg) {
                    Text(report)
                        .font(SatsatDesignSystem.Typography.monospaceBody)
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                        .textSelection(.enabled)
                }
                .padding(SatsatDesignSystem.Spacing.lg)
            }
            .background(SatsatDesignSystem.Colors.backgroundPrimary)
            .navigationTitle("Test Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Copy") {
                        UIPasteboard.general.string = report
                        HapticFeedback.success()
                    }
                    .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Developer Settings Integration

extension TestRunnerView {
    /// Add to developer settings menu
    static func developerMenuButton() -> some View {
        NavigationLink(destination: TestRunnerView()) {
            HStack {
                Image(systemName: "testtube.2")
                    .foregroundColor(SatsatDesignSystem.Colors.info)
                
                Text("Run Comprehensive Tests")
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TestRunnerView()
}