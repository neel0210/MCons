import AppKit
import Foundation
import SwiftUI

/// Represents a single folder icon within a pack
struct FolderIcon: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let packId: String
    var fileURL: URL?
    var colorHex: String?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FolderIcon, rhs: FolderIcon) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Loads the NSImage for this icon with instant in-memory caching
    func loadImage() -> NSImage? {
        // If we have a file URL, retrieve from cache or load and cache
        if let url = fileURL {
            return IconImageCache.shared.image(for: url)
        }
        
        // Otherwise generate/retrieve colored folder icon programmatically with caching
        if let hex = colorHex {
            let key = "\(hex)_512"
            if let cached = IconImageCache.shared.image(forKey: key) {
                return cached
            }
            let rendered = FolderIconRenderer.renderFolderIcon(colorHex: hex, size: 512)
            IconImageCache.shared.setImage(rendered, forKey: key)
            return rendered
        }
        
        return nil
    }
    
    /// Returns a SwiftUI Image for preview (instant cache hit)
    func previewImage() -> NSImage {
        if let image = loadImage() {
            return image
        }
        // Fallback to system folder icon
        return NSWorkspace.shared.icon(for: .folder)
    }
}
