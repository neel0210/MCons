import SwiftUI

/// Shared animation constants and modifiers
enum AppAnimations {
    
    // MARK: - Spring Animations
    
    /// Bouncy spring for interactive elements
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.1)
    
    /// Smooth spring for layout transitions
    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.1)
    
    /// Quick spring for micro-interactions
    static let quick = Animation.spring(response: 0.25, dampingFraction: 0.7, blendDuration: 0)
    
    /// Gentle spring for subtle movements
    static let gentle = Animation.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.15)
    
    // MARK: - Eased Animations
    
    /// Standard ease-in-out
    static let standard = Animation.easeInOut(duration: 0.3)
    
    /// Slow fade for overlays
    static let fade = Animation.easeInOut(duration: 0.2)
    
    /// Long animation for success states
    static let success = Animation.spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0.1)
}

// MARK: - Animated View Modifiers

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
                            .white.opacity(0.1),
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
            .offset(y: isVisible ? 0 : 20)
            .animation(AppAnimations.smooth.delay(delay), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

// MARK: - View Extension

extension View {
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
