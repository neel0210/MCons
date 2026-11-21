import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Service for exporting icons to PNG, ICNS, or original vector formats
@MainActor
final class IconExportService {
    static let shared = IconExportService()
    
    private init() {}
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case png = "PNG Image (1024×1024)"
        case icns = "macOS Icon (.icns)"
        case svg = "Original Vector (.svg)"
        
        var id: String { rawValue }
        
        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .icns: return "icns"
            case .svg: return "svg"
            }
        }
        
        var contentType: UTType {
            switch self {
            case .png: return .png
            case .icns: return .icns
            case .svg: return .svg
            }
        }
    }
    
    /// Displays a native macOS save panel to export the icon
    func export(icon: FolderIcon, format: ExportFormat, tintColor: NSColor? = nil) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.nameFieldStringValue = "\(icon.name).\(format.fileExtension)"
        panel.allowedContentTypes = [format.contentType]
        panel.title = "Export \(icon.name) as \(format.rawValue)"
        
        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }
        
        do {
            switch format {
            case .png:
                try exportAsPNG(icon: icon, to: destinationURL, tintColor: tintColor)
            case .icns:
                try exportAsICNS(icon: icon, to: destinationURL, tintColor: tintColor)
            case .svg:
                try exportAsOriginalVector(icon: icon, to: destinationURL)
            }
            
            NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
    
    /// Exports high-resolution 1024×1024 PNG
    func exportAsPNG(icon: FolderIcon, to destinationURL: URL, tintColor: NSColor? = nil) throws {
        guard var image = icon.loadImage() else {
            throw IconServiceError.invalidImage
        }
        
        if let tint = tintColor {
            image = IconService.tintImage(image, with: tint)
        }
        
        // Render crisp 1024×1024 bitmap representation
        let size = NSSize(width: 1024, height: 1024)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        guard let bitmapRep = rep else {
            throw IconServiceError.invalidImage
        }
        
        bitmapRep.size = size
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.current = context
        context?.imageInterpolation = .high
        
        let rect = NSRect(origin: .zero, size: size)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        
        NSGraphicsContext.restoreGraphicsState()
        
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw IconServiceError.invalidImage
        }
        
        try pngData.write(to: destinationURL)
    }
    
    /// Exports multi-resolution Apple .icns archive via temporary iconset & iconutil
    func exportAsICNS(icon: FolderIcon, to destinationURL: URL, tintColor: NSColor? = nil) throws {
        guard var baseImage = icon.loadImage() else {
            throw IconServiceError.invalidImage
        }
        
        if let tint = tintColor {
            baseImage = IconService.tintImage(baseImage, with: tint)
        }
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("MCons_icns_\(UUID().uuidString)")
        let iconsetDir = tempDir.appendingPathComponent("icon.iconset")
        try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Standard macOS iconset dimensions
        let sizes: [(String, Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024),
        ]
        
        for (filename, px) in sizes {
            let size = NSSize(width: px, height: px)
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: px,
                pixelsHigh: px,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
            
            if let bitmapRep = rep {
                bitmapRep.size = size
                NSGraphicsContext.saveGraphicsState()
                let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
                NSGraphicsContext.current = context
                context?.imageInterpolation = .high
                baseImage.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
                NSGraphicsContext.restoreGraphicsState()
                
                if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    try pngData.write(to: iconsetDir.appendingPathComponent(filename))
                }
            }
        }
        
        // Convert iconset to icns using macOS native iconutil tool
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconsetDir.path, "-o", destinationURL.path]
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            // Fallback: If iconutil fails, write 1024 PNG with icns extension
            try exportAsPNG(icon: icon, to: destinationURL, tintColor: tintColor)
            return
        }
    }
    
    /// Exports original vector SVG if available
    func exportAsOriginalVector(icon: FolderIcon, to destinationURL: URL) throws {
        if let fileURL = icon.fileURL, fileURL.pathExtension.lowercased() == "svg" {
            let data = try Data(contentsOf: fileURL)
            try data.write(to: destinationURL)
        } else {
            // If icon is programmatically rendered or non-SVG, export as PNG
            try exportAsPNG(icon: icon, to: destinationURL)
        }
    }
}
