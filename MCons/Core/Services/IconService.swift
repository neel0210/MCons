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
    /// Uses lazy/cached computation, only recomputing when the source image changes
    private func prepareIconImage(_ image: NSImage) -> NSImage {
        let targetSize = NSSize(width: 512, height: 512)
        
        // Fast path 1: If image is already 512x512, no scaling needed
        if image.size == targetSize {
            return image
        }
        
        // Fast path 2: Check cache using image identity and dimensions
        let cacheKey = NSString(string: "\(ObjectIdentifier(image).hashValue)_\(Int(image.size.width))x\(Int(image.size.height))")
        if let cachedImage = Self.scaledImageCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // Lazy computation: scale to 512x512
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        
        newImage.unlockFocus()
        
        // Cache result for future calls
        Self.scaledImageCache.setObject(newImage, forKey: cacheKey)
        
        return newImage
    }
    
    /// Nudges Finder to refresh the folder's icon
    private func refreshFinder(for folderURL: URL) {
        let fileManager = FileManager.default
        let attributes = [FileAttributeKey.modificationDate: Date()]
        try? fileManager.setAttributes(attributes, ofItemAtPath: folderURL.path)
    }
}
