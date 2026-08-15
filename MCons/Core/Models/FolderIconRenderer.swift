import AppKit
import Foundation

// MARK: - Programmatic Folder Icon Renderer

/// Vector graphics renderer for generating custom colored folder icons programmatically
enum FolderIconRenderer {
    
    private static let renderedFolderCache = NSCache<NSString, NSImage>()
    
    /// Renders a colored folder icon programmatically
    /// Uses lazy/cached rendering, only computing when the colorHex or size changes
    static func renderFolderIcon(colorHex: String, size: CGFloat = 512) -> NSImage {
        let cacheKey = NSString(string: "\(colorHex)_\(Int(size))")
        if let cached = renderedFolderCache.object(forKey: cacheKey) {
            return cached
        }
        
        let image = NSImage(size: NSSize(width: size, height: size))
        
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        let color = NSColor(hex: colorHex) ?? .systemBlue
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        
        // Draw folder shape
        drawFolderShape(in: context, rect: rect, color: color)
        
        image.unlockFocus()
        
        // Cache result
        renderedFolderCache.setObject(image, forKey: cacheKey)
        
        return image
    }
    
    private static func drawFolderShape(in context: CGContext, rect: CGRect, color: NSColor) {
        let w = rect.width
        let h = rect.height
        let padding = w * 0.025
        
        // Folder body dimensions matching native macOS folder proportions (95% width)
        let bodyX = padding
        let bodyY = h * 0.08
        let bodyW = w - padding * 2
        let bodyH = h * 0.68
        let cornerRadius = w * 0.045
        
        // Tab dimensions
        let tabW = bodyW * 0.38
        let tabH = h * 0.12
        let tabCornerRadius = w * 0.035
        
        context.saveGState()
        
        // === Shadow ===
        context.setShadow(
            offset: CGSize(width: 0, height: -w * 0.02),
            blur: w * 0.04,
            color: CGColor(gray: 0, alpha: 0.25)
        )
        
        // === Back panel (slightly darker) ===
        let backColor = color.blended(withFraction: 0.25, of: .black) ?? color
        context.setFillColor(backColor.cgColor)
        
        let backRect = CGRect(
            x: bodyX,
            y: bodyY + bodyH * 0.02,
            width: bodyW,
            height: bodyH + tabH
        )
        let backPath = CGPath(roundedRect: backRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(backPath)
        context.fillPath()
        
        // === Tab ===
        context.setShadow(offset: .zero, blur: 0) // Remove shadow for tab
        let tabColor = color.blended(withFraction: 0.1, of: .black) ?? color
        context.setFillColor(tabColor.cgColor)
        
        let tabRect = CGRect(
            x: bodyX + w * 0.04,
            y: bodyY + bodyH - cornerRadius * 0.5,
            width: tabW,
            height: tabH
        )
        let tabPath = CGPath(roundedRect: tabRect, cornerWidth: tabCornerRadius, cornerHeight: tabCornerRadius, transform: nil)
        context.addPath(tabPath)
        context.fillPath()
        
        // === Front panel (main color) ===
        context.setShadow(
            offset: CGSize(width: 0, height: -w * 0.015),
            blur: w * 0.03,
            color: CGColor(gray: 0, alpha: 0.15)
        )
        context.setFillColor(color.cgColor)
        
        let frontRect = CGRect(
            x: bodyX,
            y: bodyY,
            width: bodyW,
            height: bodyH
        )
        let frontPath = CGPath(roundedRect: frontRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(frontPath)
        context.fillPath()
        
        // === Highlight (gradient overlay for depth) ===
        context.setShadow(offset: .zero, blur: 0)
        let highlightColor = color.blended(withFraction: 0.3, of: .white) ?? color
        
        context.setFillColor(highlightColor.withAlphaComponent(0.3).cgColor)
        let highlightRect = CGRect(
            x: bodyX + w * 0.02,
            y: bodyY + bodyH * 0.55,
            width: bodyW - w * 0.04,
            height: bodyH * 0.42
        )
        let highlightPath = CGPath(roundedRect: highlightRect, cornerWidth: cornerRadius * 0.8, cornerHeight: cornerRadius * 0.8, transform: nil)
        context.addPath(highlightPath)
        context.fillPath()
        
        // === Subtle inner edge line ===
        let edgeColor = color.blended(withFraction: 0.15, of: .white) ?? color
        context.setStrokeColor(edgeColor.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(w * 0.004)
        context.addPath(frontPath)
        context.strokePath()
        
        context.restoreGState()
    }
}
