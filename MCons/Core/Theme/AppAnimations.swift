import SwiftUI

/// Shared high-performance animation constants, springs, and modifiers
enum AppAnimations {
    
    // MARK: - Spring Animations
    
    /// Bouncy spring for tactile buttons and icons
    static let bouncy = Animation.spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0.05)
    
    /// Smooth spring for layout and page transitions
    static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.08)
    
    /// Ultra-fast spring for hover states (60/120fps)
    static let quick = Animation.spring(response: 0.22, dampingFraction: 0.75, blendDuration: 0)
    
    /// Interactive spring for drag and touch
    static let interactive = Animation.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.05)
    
    /// Gentle spring for hero effects and subtle floating
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.88, blendDuration: 0.1)
    
    // MARK: - Eased Animations
    
    /// Standard ease-out for quick state changes
    static let standard = Animation.easeOut(duration: 0.2)
    
    /// Fade animation for modal and overlay presentations
    static let fade = Animation.easeInOut(duration: 0.18)
    
    /// Celebration animation for success states
    static let success = Animation.spring(response: 0.5, dampingFraction: 0.55, blendDuration: 0.05)
}

// MARK: - Animated View Modifiers

/// Pro-grade Card Lift & Glow effect on hover
struct CardLiftModifier: ViewModifier {
    @State private var isHovering = false
    var accentHex: String = "#6C5CE7"
    var liftScale: CGFloat = 1.018
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? liftScale : 1.0)
            .shadow(
                color: isHovering ? Color(hex: accentHex).opacity(0.35) : Color.black.opacity(0.18),
                radius: isHovering ? 14 : 6,
                x: 0,
                y: isHovering ? 8 : 3
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .stroke(
                        isHovering
                            ? Color(hex: accentHex).opacity(0.7)
                            : Color(nsColor: .separatorColor).opacity(0.25),
                        lineWidth: isHovering ? 1.5 : 1
                    )
            )
            .animation(AppAnimations.quick, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

/// Scales an element when hovered
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
