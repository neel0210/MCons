import Foundation

/// Manages Security-Scoped Bookmarks for macOS App Sandbox compliance
final class SecurityBookmarkManager {
    
    static let shared = SecurityBookmarkManager()
    private let userDefaults = UserDefaults.standard
    private let keyPrefix = "mcons_sec_bookmark_"
    
    // MARK: - Save Bookmark
    
    /// Saves a security-scoped bookmark for a target URL
    /// - Parameter url: The URL to bookmark
    /// - Returns: `true` if bookmark data was generated and saved
    @discardableResult
    func saveBookmark(for url: URL) -> Bool {
        // Start accessing if URL already has security scope
        let startedScope = url.startAccessingSecurityScopedResource()
        defer {
            if startedScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let options: URL.BookmarkCreationOptions = [.withSecurityScope]
            let bookmarkData = try url.bookmarkData(
                options: options,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            let key = keyPrefix + url.path
            userDefaults.set(bookmarkData, forKey: key)
            return true
        } catch {
            print("SecurityBookmarkManager: Failed to create bookmark for '\(url.path)': \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Resolve Bookmark
    
    /// Resolves a security-scoped bookmark for a URL
    /// - Parameter url: The target URL
    /// - Returns: Resolved security-scoped URL, or original URL if not found/invalid
    func resolveBookmark(for url: URL) -> URL {
        let key = keyPrefix + url.path
        guard let data = userDefaults.data(forKey: key) else {
            return url
        }
        
        var isStale = false
        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                saveBookmark(for: resolvedURL)
            }
            
            return resolvedURL
        } catch {
            print("SecurityBookmarkManager: Failed to resolve bookmark for '\(url.path)': \(error.localizedDescription)")
            return url
        }
    }
    
    // MARK: - Scoped Access Execution
    
    /// Executes a block with security-scoped resource access automatically managed
    /// - Parameters:
    ///   - url: The target URL
    ///   - block: Closure to execute with security-scoped access
    /// - Returns: The return value of the closure
    func withSecurityScopedAccess<T>(to url: URL, block: (URL) throws -> T) throws -> T {
        let resolvedURL = resolveBookmark(for: url)
        let didStartAccessing = resolvedURL.startAccessingSecurityScopedResource()
        
        defer {
            if didStartAccessing {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }
        
        return try block(resolvedURL)
    }
    
    /// Removes saved bookmark data for a URL
    func removeBookmark(for url: URL) {
        let key = keyPrefix + url.path
        userDefaults.removeObject(forKey: key)
    }
}
