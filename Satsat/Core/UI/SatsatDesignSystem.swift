// SatsatDesignSystem.swift
// Satsat design system

import SwiftUI

// MARK: - Satsat Design System

struct SatsatDesignSystem {
    
    // MARK: - Colors
    
    struct Colors {
        // Primary Colors
        static let satsatOrange = Color(hex: "#FF8C00")
        static let satsatOrangeLight = Color(hex: "#FFB347")
        static let satsatOrangeDark = Color(hex: "#E67E00")
        
        // Background Colors
        static let backgroundPrimary = Color(hex: "#000000")
        static let backgroundSecondary = Color(hex: "#1C1C1E")
        static let backgroundTertiary = Color(hex: "#2C2C2E")
        static let backgroundCard = Color(hex: "#1C1C1E")
        
        // Text Colors
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "#8E8E93")
        static let textTertiary = Color(hex: "#636366")
        
        // Accent Colors
        static let success = Color(hex: "#34C759")
        static let warning = Color(hex: "#FF9F0A")
        static let error = Color(hex: "#FF3B30")
        static let info = Color(hex: "#007AFF")
        
        // Bitcoin Colors
        static let bitcoin = Color(hex: "#F7931A")
        static let lightning = Color(hex: "#FFD700")
        
        // Gradient Colors
        static let orangeGradient = LinearGradient(
            colors: [satsatOrange, satsatOrangeDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let darkGradient = LinearGradient(
            colors: [backgroundSecondary, backgroundTertiary],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Typography
    
    struct Typography {
        // Display Fonts
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        
        // Body Fonts
        static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodySmall = Font.system(size: 15, weight: .regular, design: .default)
        
        // UI Fonts
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        
        // Monospace for Bitcoin amounts
        static let monospaceBody = Font.system(size: 17, weight: .regular, design: .monospaced)
        static let monospaceTitle = Font.system(size: 24, weight: .bold, design: .monospaced)
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Border Radius
    
    struct Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 24
        static let circle: CGFloat = 50
    }
    
    // MARK: - Shadows
    
    struct Shadows {
        static let soft = Color.black.opacity(0.1)
        static let medium = Color.black.opacity(0.2)
        static let strong = Color.black.opacity(0.3)
        
        static let cardShadow = Shadow(
            color: soft,
            radius: 8,
            x: 0,
            y: 2
        )
        
        static let buttonShadow = Shadow(
            color: medium,
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Design System Components

// MARK: - Satsat Button Styles

struct SatsatPrimaryButtonStyle: ButtonStyle {
    let isDestructive: Bool
    let isLoading: Bool
    
    init(isDestructive: Bool = false, isLoading: Bool = false) {
        self.isDestructive = isDestructive
        self.isLoading = isLoading
    }
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: SatsatDesignSystem.Spacing.sm) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            }
            
            configuration.label
        }
        .font(SatsatDesignSystem.Typography.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                .fill(
                    isDestructive 
                        ? LinearGradient(colors: [SatsatDesignSystem.Colors.error], startPoint: .leading, endPoint: .trailing)
                        : SatsatDesignSystem.Colors.orangeGradient
                )
        )
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        .disabled(isLoading)
    }
}

struct SatsatSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SatsatDesignSystem.Typography.headline)
            .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                    .stroke(SatsatDesignSystem.Colors.satsatOrange, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: SatsatDesignSystem.Radius.medium)
                            .fill(SatsatDesignSystem.Colors.backgroundCard)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SatsatIconButtonStyle: ButtonStyle {
    let size: CGFloat
    
    init(size: CGFloat = 44) {
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(SatsatDesignSystem.Colors.backgroundSecondary)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Satsat Card Style

struct SatsatCardStyle: ViewModifier {
    let padding: CGFloat
    let cornerRadius: CGFloat
    
    init(padding: CGFloat = SatsatDesignSystem.Spacing.md, cornerRadius: CGFloat = SatsatDesignSystem.Radius.large) {
        self.padding = padding
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(SatsatDesignSystem.Colors.backgroundCard)
                    .shadow(color: SatsatDesignSystem.Shadows.soft, radius: 8, x: 0, y: 2)
            )
    }
}

// MARK: - Bitcoin Amount Display

struct BitcoinAmountView: View {
    let amount: UInt64
    let showUSD: Bool
    let style: AmountStyle
    let alignment: HorizontalAlignment
    
    enum AmountStyle {
        case large, medium, small
        
        var font: Font {
            switch self {
            case .large: return SatsatDesignSystem.Typography.monospaceTitle
            case .medium: return SatsatDesignSystem.Typography.monospaceBody
            case .small: return SatsatDesignSystem.Typography.caption
            }
        }
    }
    
    init(amount: UInt64, showUSD: Bool = true, style: AmountStyle = .medium, alignment: HorizontalAlignment = .leading) {
        self.amount = amount
        self.showUSD = showUSD
        self.style = style
        self.alignment = alignment
    }
    
    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(amount.formattedSats)
                .font(style.font)
                .fontWeight(.bold)
                .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
            
            if showUSD {
                Text(estimatedUSD)
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
        }
    }
    
    private var estimatedUSD: String {
        // Simplified USD conversion for MVP
        let btcAmount = Double(amount) / 100_000_000.0
        let estimatedPrice = btcAmount * 45000 // Rough BTC price
        return String(format: "≈$%.2f", estimatedPrice)
    }
}

// MARK: - Progress Bar Component

struct SatsatProgressBar: View {
    let progress: Double
    let height: CGFloat
    let showPercentage: Bool
    
    init(progress: Double, height: CGFloat = 8, showPercentage: Bool = false) {
        self.progress = progress
        self.height = height
        self.showPercentage = showPercentage
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(SatsatDesignSystem.Colors.backgroundTertiary)
                        .frame(height: height)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(progressGradient)
                        .frame(width: geometry.size.width * progress, height: height)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: height)
            
            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
            }
        }
    }
    
    private var progressGradient: LinearGradient {
        switch progress {
        case 0..<0.25:
            return LinearGradient(colors: [SatsatDesignSystem.Colors.error, SatsatDesignSystem.Colors.warning], startPoint: .leading, endPoint: .trailing)
        case 0.25..<0.75:
            return LinearGradient(colors: [SatsatDesignSystem.Colors.warning, SatsatDesignSystem.Colors.satsatOrange], startPoint: .leading, endPoint: .trailing)
        case 0.75..<1.0:
            return LinearGradient(colors: [SatsatDesignSystem.Colors.satsatOrange, SatsatDesignSystem.Colors.success], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [SatsatDesignSystem.Colors.success, SatsatDesignSystem.Colors.success], startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - Avatar Component

struct SatsatAvatar: View {
    let name: String
    let color: String
    let size: CGFloat
    let isOnline: Bool
    
    init(name: String, color: String = "#FF9500", size: CGFloat = 40, isOnline: Bool = false) {
        self.name = name
        self.color = color
        self.size = size
        self.isOnline = isOnline
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: color))
                .frame(width: size, height: size)
            
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if isOnline {
                Circle()
                    .fill(SatsatDesignSystem.Colors.success)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .overlay(
                        Circle()
                            .stroke(SatsatDesignSystem.Colors.backgroundCard, lineWidth: 2)
                    )
                    .offset(x: size * 0.35, y: -size * 0.35)
            }
        }
    }
}

// MARK: - Status Badge

struct SatsatStatusBadge: View {
    let text: String
    let style: BadgeStyle
    
    enum BadgeStyle {
        case success, warning, error, info, neutral
        
        var backgroundColor: Color {
            switch self {
            case .success: return SatsatDesignSystem.Colors.success
            case .warning: return SatsatDesignSystem.Colors.warning
            case .error: return SatsatDesignSystem.Colors.error
            case .info: return SatsatDesignSystem.Colors.info
            case .neutral: return SatsatDesignSystem.Colors.backgroundTertiary
            }
        }
        
        var textColor: Color {
            switch self {
            case .neutral: return SatsatDesignSystem.Colors.textPrimary
            default: return .white
            }
        }
    }
    
    var body: some View {
        Text(text)
            .font(SatsatDesignSystem.Typography.caption)
            .fontWeight(.medium)
            .foregroundColor(style.textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(style.backgroundColor)
            )
    }
}

// MARK: - View Extensions

extension View {
    func satsatCard(padding: CGFloat = SatsatDesignSystem.Spacing.md, cornerRadius: CGFloat = SatsatDesignSystem.Radius.large) -> some View {
        modifier(SatsatCardStyle(padding: padding, cornerRadius: cornerRadius))
    }
    
    func satsatPrimaryButton(isDestructive: Bool = false, isLoading: Bool = false) -> some View {
        buttonStyle(SatsatPrimaryButtonStyle(isDestructive: isDestructive, isLoading: isLoading))
    }
    
    func satsatSecondaryButton() -> some View {
        buttonStyle(SatsatSecondaryButtonStyle())
    }
    
    func satsatIconButton(size: CGFloat = 44) -> some View {
        buttonStyle(SatsatIconButtonStyle(size: size))
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Haptic Feedback

struct HapticFeedback {
    static func light() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    static func medium() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    static func heavy() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    static func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    static func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
}