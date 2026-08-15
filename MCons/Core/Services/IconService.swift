import AppKit
import Foundation

// MARK: - Icon Service Error

/// Strongly typed errors for folder icon operations conforming to LocalizedError
enum IconServiceError: LocalizedError, Identifiable {
    case folderNotFound(path: String)
    case permissionDenied(path: String)
    case invalidImage
    case setIconFailed(path: String)
    case resetIconFailed(path: String)
    case unknown(String)
    
    var id: String {
        switch self {
        case .folderNotFound(let path): return "fnf_\(path)"
        case .permissionDenied(let path): return "pd_\(path)"
        case .invalidImage: return "inv_img"
        case .setIconFailed(let path): return "sif_\(path)"
        case .resetIconFailed(let path): return "rif_\(path)"
        case .unknown(let msg): return "unk_\(msg)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .folderNotFound:
            return "Folder Not Found"
        case .permissionDenied:
            return "Permission Denied"
        case .invalidImage:
            return "Invalid Icon Image"
        case .setIconFailed:
            return "Failed to Set Folder Icon"
        case .resetIconFailed:
            return "Failed to Reset Folder Icon"
        case .unknown:
            return "Unexpected Icon Error"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .folderNotFound(let path):
            return "No directory exists at path: '\(path)'."
        case .permissionDenied(let path):
            return "MCons does not have write permissions for folder at path: '\(path)'."
        case .invalidImage:
            return "The selected icon image could not be loaded or processed."
        case .setIconFailed(let path):
            return "macOS system call NSWorkspace.setIcon failed for folder at path: '\(path)'."
        case .resetIconFailed(let path):
            return "macOS system call NSWorkspace.setIcon(nil) failed for folder at path: '\(path)'."
        case .unknown(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .folderNotFound:
            return "Please select a valid folder that exists on your Mac."
        case .permissionDenied:
            return "Check folder permissions in Finder (Get Info > Sharing & Permissions) or select a folder in your User directory."
        case .invalidImage:
            return "Try selecting a different image or an icon from one of the bundled icon packs."
        case .setIconFailed, .resetIconFailed:
            return "Ensure the folder is not locked or on a read-only volume, then try again."
        case .unknown:
            return "Please try restarting MCons or choosing a different target folder."
        }
    }
}

// MARK: - Icon Service

/// Service wrapping NSWorkspace icon operations for folders with robust error handling
final class IconService: Sendable {
    
    /// Sets a custom icon on a folder at the given URL
    /// - Parameters:
    ///   - image: The NSImage to use as the folder icon
    ///   - folderURL: The URL of the folder to customize
    /// - Throws: `IconServiceError` if folder is invalid, permission denied, or setIcon fails
    func setIcon(image: NSImage, for folderURL: URL) throws {
        try SecurityBookmarkManager.shared.withSecurityScopedAccess(to: folderURL) { scopedURL in
            let fileManager = FileManager.default
            let path = scopedURL.path
            
            // 1. Validate folder existence
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
                throw IconServiceError.folderNotFound(path: path)
            }
            
            // 2. Validate write permissions
            guard fileManager.isWritableFile(atPath: path) else {
                throw IconServiceError.permissionDenied(path: path)
            }
            
            // 3. Prepare image
            let iconImage = prepareIconImage(image)
            
            // 4. Perform setIcon operation under App Sandbox security scope
            let workspace = NSWorkspace.shared
            let success = workspace.setIcon(iconImage, forFile: path, options: [])
            
            guard success else {
                throw IconServiceError.setIconFailed(path: path)
            }
            
            // 5. Touch folder to refresh Finder UI
            refreshFinder(for: scopedURL)
        }
    }
    
    /// Sets a custom icon from a file path
    /// - Parameters:
    ///   - imagePath: Path to the image file
    ///   - folderURL: The URL of the folder to customize
    /// - Throws: `IconServiceError` if image loading or setIcon fails
    func setIcon(fromPath imagePath: String, for folderURL: URL) throws {
        guard let image = NSImage(contentsOfFile: imagePath) else {
            throw IconServiceError.invalidImage
        }
        try setIcon(image: image, for: folderURL)
    }
    
    /// Removes a custom icon from a folder, restoring the default
    /// - Parameter folderURL: The URL of the folder to reset
    /// - Throws: `IconServiceError` if folder is invalid, permission denied, or resetIcon fails
    func resetIcon(for folderURL: URL) throws {
        try SecurityBookmarkManager.shared.withSecurityScopedAccess(to: folderURL) { scopedURL in
            let fileManager = FileManager.default
            let path = scopedURL.path
            
            // 1. Validate folder existence
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
                throw IconServiceError.folderNotFound(path: path)
            }
            
            // 2. Validate write permissions
            guard fileManager.isWritableFile(atPath: path) else {
                throw IconServiceError.permissionDenied(path: path)
            }
            
            // 3. Perform resetIcon under App Sandbox security scope
            let workspace = NSWorkspace.shared
            let success = workspace.setIcon(nil, forFile: path, options: [])
            
            guard success else {
                throw IconServiceError.resetIconFailed(path: path)
            }
            
            // 4. Touch folder to refresh Finder UI
            refreshFinder(for: scopedURL)
        }
    }
    
    /// Gets the current icon for a folder
    /// - Parameter folderURL: The URL of the folder
    /// - Returns: The current icon as NSImage
    func getIcon(for folderURL: URL) -> NSImage {
        return NSWorkspace.shared.icon(forFile: folderURL.path)
    }
    
    /// Checks if a folder has a custom icon set
    /// - Parameter folderURL: The URL of the folder to check
    /// - Returns: `true` if the folder has a custom icon
    func hasCustomIcon(for folderURL: URL) -> Bool {
        let iconFile = folderURL.appendingPathComponent("Icon\r")
        return FileManager.default.fileExists(atPath: iconFile.path)
    }
    
    // MARK: - Private Helpers & Image Cache
    
    private static let scaledImageCache = NSCache<NSString, NSImage>()
    
    /// Prepares an image for use as a folder icon (512x512)
    /// Trims transparent margins and scales the icon to fill ~96% of the canvas, matching standard macOS folder visual size
    private func prepareIconImage(_ image: NSImage) -> NSImage {
        let targetSize = NSSize(width: 512, height: 512)
        
        // Check cache using image identity and dimensions
        let cacheKey = NSString(string: "\(ObjectIdentifier(image).hashValue)_\(Int(image.size.width))x\(Int(image.size.height))")
        if let cachedImage = Self.scaledImageCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        let contentRect = nonTransparentBounds(for: image)
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        
        if let context = NSGraphicsContext.current?.cgContext {
            context.clear(CGRect(origin: .zero, size: targetSize))
        }
        NSGraphicsContext.current?.imageInterpolation = .high
        
        let fillRatio: CGFloat = 0.96
        let maxCanvasDim = targetSize.width * fillRatio
        let srcAspect = contentRect.width / max(contentRect.height, 1)
        let destW: CGFloat = srcAspect > 1 ? maxCanvasDim : maxCanvasDim * srcAspect
        let destH: CGFloat = srcAspect > 1 ? maxCanvasDim / srcAspect : maxCanvasDim
        let destRect = NSRect(
            x: (targetSize.width - destW) / 2,
            y: (targetSize.height - destH) / 2,
            width: destW,
            height: destH
        )
        
        image.draw(
            in: destRect,
            from: contentRect,
            operation: .sourceOver,
            fraction: 1.0
        )
        
        newImage.unlockFocus()
        
        // Cache result for future calls
        Self.scaledImageCache.setObject(newImage, forKey: cacheKey)
        
        return newImage
    }
    
    /// Finds the non-transparent bounding box of an image, or returns full bounds if not available
    private func nonTransparentBounds(for image: NSImage) -> NSRect {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return NSRect(origin: .zero, size: image.size)
        }
        
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        guard width > 0, height > 0, bitmap.hasAlpha else {
            return NSRect(origin: .zero, size: image.size)
        }
        
        var minX = width, maxX = 0, minY = height, maxY = 0
        var foundAny = false
        
        for y in 0..<height {
            for x in 0..<width {
                if let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.05 {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                    foundAny = true
                }
            }
        }
        
        guard foundAny && maxX >= minX && maxY >= minY else {
            return NSRect(origin: .zero, size: image.size)
        }
        
        let scaleX = image.size.width / CGFloat(width)
        let scaleY = image.size.height / CGFloat(height)
        
        let cropX = CGFloat(minX) * scaleX
        let cropY = CGFloat(height - 1 - maxY) * scaleY
        let cropW = CGFloat(maxX - minX + 1) * scaleX
        let cropH = CGFloat(maxY - minY + 1) * scaleY
        
        return NSRect(x: cropX, y: cropY, width: cropW, height: cropH)
    }
    
    /// Nudges Finder to refresh the folder's icon
    private func refreshFinder(for folderURL: URL) {
        let fileManager = FileManager.default
        let attributes = [FileAttributeKey.modificationDate: Date()]
        try? fileManager.setAttributes(attributes, ofItemAtPath: folderURL.path)
    }
}
