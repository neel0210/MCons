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
    
    /// Loads the NSImage for this icon
    func loadImage() -> NSImage? {
        // If we have a file URL, load from disk
        if let url = fileURL {
            return NSImage(contentsOf: url)
        }
        
        // Otherwise generate a colored folder icon programmatically
        if let hex = colorHex {
            return FolderIconRenderer.renderFolderIcon(colorHex: hex, size: 512)
        }
        
        return nil
    }
    
    /// Returns a SwiftUI Image for preview
    func previewImage() -> NSImage {
        if let image = loadImage() {
            return image
        }
        // Fallback to system folder icon
        return NSWorkspace.shared.icon(for: .folder)
    }
}
