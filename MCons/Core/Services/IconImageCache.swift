import AppKit
import Foundation

/// High-performance, thread-safe memory cache and background preloader for folder icons
final class IconImageCache: @unchecked Sendable {
    static let shared = IconImageCache()
    
    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.mcons.iconcache", qos: .userInitiated, attributes: .concurrent)
    
    private init() {
        // Configure cache limits: retain up to 250 images or 200MB memory
        cache.countLimit = 250
        cache.totalCostLimit = 200 * 1024 * 1024
    }
    
    /// Retrieves an image from cache by key
    func image(forKey key: String) -> NSImage? {
        return cache.object(forKey: key as NSString)
    }
    
    /// Stores an image in cache with an estimated memory cost
    func setImage(_ image: NSImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    /// Loads or retrieves an image from a URL with instant caching
    func image(for url: URL, targetSize: NSSize? = nil) -> NSImage? {
        let key = targetSize != nil
            ? "\(url.path)_\(Int(targetSize!.width))x\(Int(targetSize!.height))"
            : url.path
        
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        
        // Load image from disk
        guard let image = NSImage(contentsOf: url) else {
            return nil
        }
        
        // If target size specified and different, scale and cache
        if let target = targetSize, image.size != target {
            let scaled = NSImage(size: target)
            scaled.lockFocus()
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.clear(CGRect(origin: .zero, size: target))
            }
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(
                in: NSRect(origin: .zero, size: target),
                from: NSRect(origin: .zero, size: image.size),
                operation: .sourceOver,
                fraction: 1.0
            )
            scaled.unlockFocus()
            setImage(scaled, forKey: key)
            return scaled
        }
        
        setImage(image, forKey: key)
        return image
    }
    
    /// Pre-warms/caches icons on a background queue so all UI renders at 60/120 FPS
    func preheat(packs: [IconPack]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            for pack in packs {
                for icon in pack.icons {
                    if let url = icon.fileURL {
                        _ = self.image(for: url)
                    } else if let hex = icon.colorHex {
                        let key = "\(hex)_512"
                        if self.image(forKey: key) == nil {
                            let img = FolderIconRenderer.renderFolderIcon(colorHex: hex, size: 512)
                            self.setImage(img, forKey: key)
                        }
                    }
                }
            }
        }
    }
    
    /// Clears the entire image cache
    func clear() {
        cache.removeAllObjects()
    }
}
