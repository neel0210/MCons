import SwiftUI

/// Shared high-performance animation constants, springs, and modifiers tuned for Apple ProMotion (120Hz)
enum AppAnimations {
    
    // MARK: - ProMotion Springs
    
    /// Tactile spring for selection, tab switches and icon clicks
    static let bouncy = Animation.spring(response: 0.28, dampingFraction: 0.72, blendDuration: 0.02)
    
    /// Smooth fluid spring for layout and page navigation
    static let smooth = Animation.spring(response: 0.35, dampingFraction: 0.86, blendDuration: 0.04)
    
    /// Instant response spring for hover states (zero lag)
    static let quick = Animation.spring(response: 0.20, dampingFraction: 0.82, blendDuration: 0)
    
    /// Snappy interactive response
    static let snappy = Animation.spring(response: 0.24, dampingFraction: 0.78, blendDuration: 0)
    
    /// Interactive spring for drag and touch
    static let interactive = Animation.interactiveSpring(response: 0.25, dampingFraction: 0.75, blendDuration: 0.02)
    
    /// Gentle spring for hero effects and subtle floating
    static let gentle = Animation.spring(response: 0.45, dampingFraction: 0.90, blendDuration: 0.05)
    
    // MARK: - Eased Animations
    
    /// Standard ease-out for quick state changes
    static let standard = Animation.easeOut(duration: 0.16)
    
    /// Fade animation for modal and overlay presentations
    static let fade = Animation.easeInOut(duration: 0.15)
    
    /// Celebration animation for success states
    static let success = Animation.spring(response: 0.42, dampingFraction: 0.60, blendDuration: 0.04)
}

// MARK: - Animated View Modifiers

/// Pro-grade JetBlack Card Hover Illumination & Lift
struct CardLiftModifier: ViewModifier {
    @State private var isHovering = false
    var accentHex: String = "#6366F1"
    var liftScale: CGFloat = 1.006
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? liftScale : 1.0)
            .shadow(
                color: isHovering ? Color(hex: accentHex).opacity(0.3) : Color.black.opacity(0.35),
                radius: isHovering ? 12 : 5,
                x: 0,
                y: isHovering ? 6 : 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .stroke(
                        isHovering
                            ? Color(hex: accentHex).opacity(0.65)
                            : AppTheme.Colors.border,
                        lineWidth: isHovering ? 1.2 : 1
                    )
            )
            .animation(AppAnimations.quick, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

/// Scales an element when hovered without affecting container frame
struct HoverScale: ViewModifier {
    @State private var isHovering = false
    let scale: CGFloat
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? scale : 1.0)
            .animation(AppAnimations.quick, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

/// Adds a press/depress animation
struct PressEffect: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
            .animation(AppAnimations.quick, value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

/// Shimmer loading animation
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.12),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 3)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

/// Fade in from bottom animation
struct FadeInUp: ViewModifier {
    @State private var isVisible = false
    let delay: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 12)
            .animation(AppAnimations.smooth.delay(delay), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

// MARK: - View Extension

extension View {
    func cardLift(accentHex: String = "#6C5CE7", scale: CGFloat = 1.018) -> some View {
        modifier(CardLiftModifier(accentHex: accentHex, liftScale: scale))
    }
    
    func hoverScale(_ scale: CGFloat = 1.05) -> some View {
        modifier(HoverScale(scale: scale))
    }
    
    func pressEffect() -> some View {
        modifier(PressEffect())
    }
    
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
    
    func fadeInUp(delay: Double = 0) -> some View {
        modifier(FadeInUp(delay: delay))
    }
}
