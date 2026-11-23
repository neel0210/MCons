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
            let key = "\(hex)_1024"
            if let cached = IconImageCache.shared.image(forKey: key) {
                return cached
            }
            let rendered = FolderIconRenderer.renderFolderIcon(colorHex: hex, size: 1024)
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
    
    /// Returns a pre-cached standardized thumbnail for UI display (128×128)
    /// GPU scales efficiently across 36-128pt frames with a single unified memory footprint
    func thumbnailImage(size: Int = 128) -> NSImage {
        let standardSize = 128
        let targetSize = NSSize(width: standardSize, height: standardSize)
        
        if let url = fileURL {
            if let cached = IconImageCache.shared.image(for: url, targetSize: targetSize) {
                return cached
            }
        }
        
        if let hex = colorHex {
            let key = "\(hex)_\(standardSize)"
            if let cached = IconImageCache.shared.image(forKey: key) {
                return cached
            }
            let rendered = FolderIconRenderer.renderFolderIcon(colorHex: hex, size: CGFloat(standardSize))
            IconImageCache.shared.setImage(rendered, forKey: key)
            return rendered
        }
        
        // Fallback
        return previewImage()
    }
}

// MARK: - Asynchronous High-FPS Thumbnail View

/// Renders folder icon thumbnails asynchronously with zero main-thread hitching
/// Returns instantly when cached in memory, or decodes in background with smooth transition
struct IconThumbnailView: View {
    let icon: FolderIcon
    var size: CGFloat = 76
    var fixedSize: Bool = true
    
    @State private var asyncImage: NSImage?
    private static let placeholderImage = NSWorkspace.shared.icon(for: .folder)
    
    var body: some View {
        Group {
            if let img = asyncImage ?? IconImageCache.shared.cachedThumbnail(for: icon) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(nsImage: Self.placeholderImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.3)
            }
        }
        .modifier(ThumbnailFrameModifier(size: size, fixedSize: fixedSize))
        .onAppear {
            if asyncImage == nil, let cached = IconImageCache.shared.cachedThumbnail(for: icon) {
                asyncImage = cached
            }
        }
        .task(id: icon.id) {
            if asyncImage == nil {
                if let cached = IconImageCache.shared.cachedThumbnail(for: icon) {
                    asyncImage = cached
                } else {
                    let decoded = await IconImageCache.shared.loadThumbnailAsync(for: icon)
                    asyncImage = decoded
                }
            }
        }
    }
}

private struct ThumbnailFrameModifier: ViewModifier {
    let size: CGFloat
    let fixedSize: Bool
    
    func body(content: Content) -> some View {
        if fixedSize {
            content.frame(width: size, height: size)
        } else {
            content.frame(maxWidth: size, maxHeight: size)
        }
    }
}
