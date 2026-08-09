import SwiftUI

/// Centralized design system for Mac_ICOns
enum AppTheme {
    
    // MARK: - Colors
    
    enum Colors {
        /// Primary accent gradient
        static let accentGradient = LinearGradient(
            colors: [Color(hex: "#6C5CE7"), Color(hex: "#A29BFE")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// Secondary gradient for backgrounds
        static let backgroundGradient = LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .windowBackgroundColor).opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        
        /// Sidebar background
        static let sidebarBackground = Color(nsColor: .controlBackgroundColor).opacity(0.5)
        
        /// Card background for light/dark mode
        static let cardBackground = Color(nsColor: .controlBackgroundColor)
        
        /// Subtle text
        static let subtitleText = Color.secondary
        
        /// Success green
        static let success = Color(hex: "#00B894")
        
        /// Warning amber
        static let warning = Color(hex: "#FDCB6E")
        
        /// Error red
        static let error = Color(hex: "#D63031")
        
        /// Gradients for icon pack cards
        static func packGradient(hex: String) -> LinearGradient {
            let baseColor = Color(hex: hex)
            return LinearGradient(
                colors: [baseColor.opacity(0.8), baseColor.opacity(0.4)],
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
