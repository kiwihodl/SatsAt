// SatsatAnimations.swift
// Professional animations and transitions for Satsat

import SwiftUI

// MARK: - Animation Presets

struct SatsatAnimations {
    
    // MARK: - Basic Animations
    
    static let springBouncy = Animation.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0.25)
    static let springSnappy = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1)
    static let springSmooth = Animation.spring(response: 0.5, dampingFraction: 1.0, blendDuration: 0.25)
    
    static let easeInOut = Animation.easeInOut(duration: 0.3)
    static let easeIn = Animation.easeIn(duration: 0.25)
    static let easeOut = Animation.easeOut(duration: 0.25)
    
    static let quickFade = Animation.easeInOut(duration: 0.2)
    static let mediumFade = Animation.easeInOut(duration: 0.4)
    static let slowFade = Animation.easeInOut(duration: 0.6)
    
    // MARK: - Custom Animations
    
    static let buttonPress = Animation.easeInOut(duration: 0.1)
    static let cardAppear = Animation.spring(response: 0.7, dampingFraction: 0.8, blendDuration: 0.3)
    static let progressBar = Animation.spring(response: 1.0, dampingFraction: 0.9, blendDuration: 0.5)
    static let statusChange = Animation.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.2)
    
    // MARK: - Delayed Animations
    
    static func delayedSpring(delay: Double) -> Animation {
        return springSnappy.delay(delay)
    }
    
    static func staggeredAppear(index: Int, itemDelay: Double = 0.1) -> Animation {
        return cardAppear.delay(Double(index) * itemDelay)
    }
}

// MARK: - Custom Animation Modifiers

struct ScaleOnPressModifier: ViewModifier {
    @State private var isPressed = false
    let scale: CGFloat
    
    init(scale: CGFloat = 0.95) {
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(SatsatAnimations.buttonPress, value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

struct FloatingActionModifier: ViewModifier {
    @State private var isFloating = false
    let amplitude: CGFloat
    let duration: Double
    
    init(amplitude: CGFloat = 3.0, duration: Double = 2.0) {
        self.amplitude = amplitude
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -amplitude : amplitude)
            .animation(
                Animation.easeInOut(duration: duration).repeatForever(autoreverses: true),
                value: isFloating
            )
            .onAppear {
                isFloating = true
            }
    }
}

struct SlideInModifier: ViewModifier {
    @State private var isVisible = false
    let direction: SlideDirection
    let delay: Double
    
    enum SlideDirection {
        case leading, trailing, top, bottom
        
        var offset: CGSize {
            switch self {
            case .leading: return CGSize(width: -100, height: 0)
            case .trailing: return CGSize(width: 100, height: 0)
            case .top: return CGSize(width: 0, height: -100)
            case .bottom: return CGSize(width: 0, height: 100)
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .offset(isVisible ? .zero : direction.offset)
            .opacity(isVisible ? 1 : 0)
            .animation(SatsatAnimations.cardAppear.delay(delay), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    
    init(duration: Double = 1.5) {
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.white.opacity(0.4),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: -200 + phase * 400)
                .animation(
                    Animation.linear(duration: duration).repeatForever(autoreverses: false),
                    value: phase
                )
            )
            .onAppear {
                phase = 1
            }
    }
}

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    let scale: CGFloat
    let opacity: Double
    let duration: Double
    
    init(scale: CGFloat = 1.1, opacity: Double = 0.8, duration: Double = 1.0) {
        self.scale = scale
        self.opacity = opacity
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? scale : 1.0)
            .opacity(isPulsing ? opacity : 1.0)
            .animation(
                Animation.easeInOut(duration: duration).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - View Extensions

extension View {
    func scaleOnPress(scale: CGFloat = 0.95) -> some View {
        modifier(ScaleOnPressModifier(scale: scale))
    }
    
    func floatingAction(amplitude: CGFloat = 3.0, duration: Double = 2.0) -> some View {
        modifier(FloatingActionModifier(amplitude: amplitude, duration: duration))
    }
    
    func slideIn(from direction: SlideInModifier.SlideDirection, delay: Double = 0) -> some View {
        modifier(SlideInModifier(direction: direction, delay: delay))
    }
    
    func shimmer(duration: Double = 1.5) -> some View {
        modifier(ShimmerModifier(duration: duration))
    }
    
    func pulse(scale: CGFloat = 1.1, opacity: Double = 0.8, duration: Double = 1.0) -> some View {
        modifier(PulseModifier(scale: scale, opacity: opacity, duration: duration))
    }
    
    func staggeredAppear(index: Int, itemDelay: Double = 0.1) -> some View {
        self
            .opacity(0)
            .offset(y: 20)
            .onAppear {
                withAnimation(SatsatAnimations.staggeredAppear(index: index, itemDelay: itemDelay)) {
                    // Animation will be handled by the modifier
                }
            }
    }
}

// MARK: - Custom Transition Effects

extension AnyTransition {
    static var slideAndFade: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    static var scaleAndFade: AnyTransition {
        AnyTransition.scale.combined(with: .opacity)
    }
    
    static var bounceScale: AnyTransition {
        AnyTransition.scale.animation(SatsatAnimations.springBouncy)
    }
    
    static func customSlide(from edge: Edge) -> AnyTransition {
        AnyTransition.move(edge: edge)
            .combined(with: .opacity)
            .animation(SatsatAnimations.cardAppear)
    }
}

// MARK: - Animated Number Counter

struct AnimatedNumberView: View {
    let value: Double
    let format: String
    let duration: Double
    
    @State private var displayedValue: Double = 0
    
    init(value: Double, format: String = "%.0f", duration: Double = 1.0) {
        self.value = value
        self.format = format
        self.duration = duration
    }
    
    var body: some View {
        Text(String(format: format, displayedValue))
            .onAppear {
                animateToValue()
            }
            .onChange(of: value) { newValue in
                animateToValue()
            }
    }
    
    private func animateToValue() {
        let startValue = displayedValue
        let endValue = value
        let range = endValue - startValue
        
        let startTime = Date()
        
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)
            
            // Ease out animation
            let easedProgress = 1 - pow(1 - progress, 3)
            
            displayedValue = startValue + (range * easedProgress)
            
            if progress >= 1.0 {
                displayedValue = endValue
                timer.invalidate()
            }
        }
    }
}

// MARK: - Loading Animation Components

struct LoadingDotsView: View {
    @State private var animating = false
    let color: Color
    let size: CGFloat
    
    init(color: Color = SatsatDesignSystem.Colors.satsatOrange, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

struct SkeletonView: View {
    @State private var isAnimating = false
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(height: CGFloat = 20, cornerRadius: CGFloat = 4) {
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        SatsatDesignSystem.Colors.backgroundSecondary,
                        SatsatDesignSystem.Colors.backgroundTertiary,
                        SatsatDesignSystem.Colors.backgroundSecondary
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: height)
            .offset(x: isAnimating ? 200 : -200)
            .animation(
                Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Success Animation Component

struct SuccessCheckmarkView: View {
    @State private var trimEnd: CGFloat = 0
    @State private var scale: CGFloat = 0
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 50, color: Color = SatsatDesignSystem.Colors.success) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .scaleEffect(scale)
            
            Path { path in
                path.move(to: CGPoint(x: size * 0.3, y: size * 0.5))
                path.addLine(to: CGPoint(x: size * 0.45, y: size * 0.65))
                path.addLine(to: CGPoint(x: size * 0.7, y: size * 0.35))
            }
            .trim(from: 0, to: trimEnd)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(SatsatAnimations.springBouncy) {
                scale = 1.0
            }
            
            withAnimation(SatsatAnimations.easeOut.delay(0.2)) {
                trimEnd = 1.0
            }
        }
    }
}

// MARK: - Currency Flip Animation

struct CurrencyFlipView: View {
    @State private var showingUSD = true
    let satsAmount: UInt64
    let usdAmount: String
    
    var body: some View {
        VStack {
            Text(showingUSD ? usdAmount : satsAmount.formattedSats)
                .font(SatsatDesignSystem.Typography.monospaceTitle)
                .fontWeight(.bold)
                .foregroundColor(SatsatDesignSystem.Colors.satsatOrange)
                .rotation3DEffect(
                    .degrees(showingUSD ? 0 : 180),
                    axis: (x: 1, y: 0, z: 0)
                )
                .animation(SatsatAnimations.springSnappy, value: showingUSD)
                .onTapGesture {
                    showingUSD.toggle()
                    HapticFeedback.light()
                }
        }
    }
}