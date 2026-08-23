import SwiftUI

/// Centralized JetBlack design system for MCons
enum AppTheme {
    
    // MARK: - JetBlack Colors & Surfaces
    
    enum Colors {
        /// Primary accent gradient (Electric Violet to Indigo)
        static let accentGradient = LinearGradient(
            colors: [Color(hex: "#6366F1"), Color(hex: "#8B5CF6")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// Secondary neon cyan gradient
        static let cyanGradient = LinearGradient(
            colors: [Color(hex: "#00D2FF"), Color(hex: "#3A7BD5")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// JetBlack Root Background
        static let jetBlackBackground = Color(hex: "#090A0F")
        
        /// JetBlack Canvas Background
        static let background = Color(hex: "#0C0E14")
        
        /// JetBlack Sidebar Background
        static let sidebarBackground = Color(hex: "#08090D")
        
        /// JetBlack Card Surface
        static let cardBackground = Color(hex: "#13151F")
        
        /// JetBlack Elevated Card Surface
        static let cardElevated = Color(hex: "#1A1D2A")
        
        /// Subtle Border Stroke
        static let border = Color.white.opacity(0.08)
        
        /// Hover Border Stroke
        static let borderHover = Color.white.opacity(0.18)
        
        /// Subtle text
        static let subtitleText = Color(hex: "#94A3B8")
        
        /// Success Emerald
        static let success = Color(hex: "#10B981")
        
        /// Warning Amber
        static let warning = Color(hex: "#F59E0B")
        
        /// Error Rose
        static let error = Color(hex: "#F43F5E")
        
        /// Gradients for icon pack cards
        static func packGradient(hex: String) -> LinearGradient {
            let baseColor = Color(hex: hex)
            return LinearGradient(
                colors: [baseColor.opacity(0.75), baseColor.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 22, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 14, weight: .regular, design: .default)
        static let callout = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 11, weight: .regular, design: .default)
        static let captionBold = Font.system(size: 11, weight: .semibold, design: .rounded)
        static let monoCaption = Font.system(size: 11, weight: .regular, design: .monospaced)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Icon Sizes
    
    enum IconSize {
        static let small: CGFloat = 32
        static let medium: CGFloat = 48
        static let large: CGFloat = 64
        static let xlarge: CGFloat = 96
        static let preview: CGFloat = 128
        static let hero: CGFloat = 200
    }
}
