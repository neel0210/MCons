import AppKit
import SwiftUI

// MARK: - NSColor Hex Extension

extension NSColor {
    /// Creates an NSColor from a hex string (e.g., "#FF5733" or "FF5733")
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        
        switch length {
        case 6: // RGB
            self.init(
                red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(rgb & 0x0000FF) / 255.0,
                alpha: 1.0
            )
        case 8: // RGBA
            self.init(
                red: CGFloat((rgb & 0xFF000000) >> 24) / 255.0,
                green: CGFloat((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: CGFloat((rgb & 0x0000FF00) >> 8) / 255.0,
                alpha: CGFloat(rgb & 0x000000FF) / 255.0
            )
        default:
            return nil
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    /// Creates a SwiftUI Color from a hex string
    init(hex: String) {
        let nsColor = NSColor(hex: hex) ?? .white
        self.init(nsColor: nsColor)
    }
}

// MARK: - NSImage Extensions

extension NSImage {
    /// Cached app icon instance from bundle or system application icon
    static let appIcon: NSImage = {
        if let icon = NSImage(named: "AppIcon") {
            return icon
        }
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            return icon
        }
        return NSApplication.shared.applicationIconImage
    }()
    
    /// Resizes the image to the given size
    func resized(to targetSize: NSSize) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        self.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: self.size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }
    
    /// Converts NSImage to PNG data
    var pngData: Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

// MARK: - URL Extensions

extension URL {
    /// Returns true if this URL points to a directory
    var isDirectory: Bool {
        let values = try? resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory == true
    }
    
    /// Returns the folder name without path
    var folderName: String {
        return lastPathComponent
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a glassmorphism effect
    func glassMorphism(
        cornerRadius: CGFloat = 16,
        opacity: Double = 0.1,
        blur: CGFloat = 10
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(opacity > 0 ? 1 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    /// Adds a subtle card shadow
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    /// Adds a hover glow effect
    func hoverGlow(color: Color = .accentColor, isHovering: Bool) -> some View {
        self.shadow(
            color: isHovering ? color.opacity(0.4) : .clear,
            radius: isHovering ? 12 : 0,
            x: 0,
            y: 0
        )
    }
}
