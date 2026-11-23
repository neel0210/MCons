import AppKit
import Foundation

/// High-performance, thread-safe memory cache and background preloader for folder icons
final class IconImageCache: @unchecked Sendable {
    static let shared = IconImageCache()
    
    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.mcons.iconcache", qos: .userInitiated, attributes: .concurrent)
    
    private init() {
        // Configure cache limits: retain up to 300 images or 64MB memory (thumbnails ~65KB each)
        cache.countLimit = 300
        cache.totalCostLimit = 64 * 1024 * 1024
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
    
    /// Loads or retrieves an image from a URL with instant caching and reuse
    func image(for url: URL, targetSize: NSSize? = nil) -> NSImage? {
        let key = targetSize != nil
            ? "\(url.path)_\(Int(targetSize!.width))"
            : url.path
        
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        
        // Check if unscaled base image is already in cache to avoid disk re-read
        let baseImage: NSImage
        if let cachedBase = cache.object(forKey: url.path as NSString) {
            baseImage = cachedBase
        } else if let loaded = NSImage(contentsOf: url) {
            baseImage = loaded
            // Cache full image only if no target size requested
            if targetSize == nil {
                setImage(baseImage, forKey: url.path)
            }
        } else {
            return nil
        }
        
        // If target size specified and different, scale and cache thumbnail
        if let target = targetSize, baseImage.size != target {
            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(target.width),
                pixelsHigh: Int(target.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) else {
                setImage(baseImage, forKey: key)
                return baseImage
            }
            
            rep.size = target
            NSGraphicsContext.saveGraphicsState()
            if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
                NSGraphicsContext.current = ctx
                ctx.cgContext.clear(CGRect(origin: .zero, size: target))
                ctx.imageInterpolation = .high
                baseImage.draw(
                    in: NSRect(origin: .zero, size: target),
                    from: NSRect(origin: .zero, size: baseImage.size),
                    operation: .sourceOver,
                    fraction: 1.0
                )
            }
            NSGraphicsContext.restoreGraphicsState()
            
            let scaled = NSImage(size: target)
            scaled.addRepresentation(rep)
            setImage(scaled, forKey: key)
            return scaled
        }
        
        setImage(baseImage, forKey: key)
        return baseImage
    }
    
    /// Pre-warms lightweight icon thumbnails in parallel across CPU cores on background queue
    /// Prioritizes preview icons first on userInitiated QoS for instant 120 FPS card scrolling
    func preheat(packs: [IconPack]) {
        let targetSize = NSSize(width: 128, height: 128)
        let previewIcons = packs.flatMap { $0.previewIcons }
        let otherIcons = packs.flatMap { Array($0.icons.dropFirst(4)) }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            // Fast parallel decode of preview icons (only ~80 icons, ~150ms)
            DispatchQueue.concurrentPerform(iterations: previewIcons.count) { i in
                let icon = previewIcons[i]
                if let url = icon.fileURL {
                    _ = self.image(for: url, targetSize: targetSize)
                } else if let hex = icon.colorHex {
                    let thumbKey = "\(hex)_128"
                    if self.image(forKey: thumbKey) == nil {
                        let img = FolderIconRenderer.renderFolderIcon(colorHex: hex, size: 128)
                        self.setImage(img, forKey: thumbKey)
                    }
                }
            }
            
            // Secondary parallel decode of remaining icons on utility queue
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else { return }
                DispatchQueue.concurrentPerform(iterations: otherIcons.count) { i in
                    let icon = otherIcons[i]
                    if let url = icon.fileURL {
                        _ = self.image(for: url, targetSize: targetSize)
                    } else if let hex = icon.colorHex {
                        let thumbKey = "\(hex)_128"
                        if self.image(forKey: thumbKey) == nil {
                            let img = FolderIconRenderer.renderFolderIcon(colorHex: hex, size: 128)
                            self.setImage(img, forKey: thumbKey)
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
    
    /// Instant 0ms memory cache lookup for thumbnail (zero disk read, zero UI blocking)
    func cachedThumbnail(for icon: FolderIcon) -> NSImage? {
        if let url = icon.fileURL {
            let key = "\(url.path)_128"
            return cache.object(forKey: key as NSString)
        }
        if let hex = icon.colorHex {
            let key = "\(hex)_128"
            return cache.object(forKey: key as NSString)
        }
        return nil
    }
    
    /// Asynchronously decodes or renders thumbnail on background thread with non-blocking continuation
    func loadThumbnailAsync(for icon: FolderIcon) async -> NSImage? {
        if let cached = cachedThumbnail(for: icon) {
            return cached
        }
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                let targetSize = NSSize(width: 128, height: 128)
                if let url = icon.fileURL {
                    let img = self.image(for: url, targetSize: targetSize)
                    continuation.resume(returning: img)
                } else if let hex = icon.colorHex {
                    let key = "\(hex)_128"
                    if let cached = self.image(forKey: key) {
                        continuation.resume(returning: cached)
                    } else {
                        let rendered = FolderIconRenderer.renderFolderIcon(colorHex: hex, size: 128)
                        self.setImage(rendered, forKey: key)
                        continuation.resume(returning: rendered)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
