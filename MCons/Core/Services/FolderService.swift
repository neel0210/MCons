import Foundation

/// Service for file system folder operations
final class FolderService {
    
    private let fileManager = FileManager.default
    
    /// Creates a new folder at the specified location
    /// - Parameters:
    ///   - name: Name of the folder to create
    ///   - parentURL: Parent directory URL
    /// - Returns: The URL of the created folder, or nil on failure
    func createFolder(named name: String, at parentURL: URL) -> URL? {
        let folderURL = parentURL.appendingPathComponent(name)
        
        do {
            try fileManager.createDirectory(
                at: folderURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            SecurityBookmarkManager.shared.saveBookmark(for: folderURL)
            return folderURL
        } catch {
            print("Failed to create folder: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Checks if a folder exists at the given URL
    /// - Parameter url: The URL to check
    /// - Returns: `true` if a directory exists at the URL
    func folderExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
    
    /// Gets the contents of a directory (folders only)
    /// - Parameter url: The directory URL
    /// - Returns: Array of folder URLs
    func foldersInDirectory(at url: URL) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        return contents.filter { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            return values?.isDirectory == true
        }
    }
    
    /// Gets the display name for a folder
    /// - Parameter url: The folder URL
    /// - Returns: The display name
    func displayName(for url: URL) -> String {
        return fileManager.displayName(atPath: url.path)
    }
    
    /// Gets the home directory URL
    var homeDirectory: URL {
        return fileManager.homeDirectoryForCurrentUser
    }
    
    /// Gets the Desktop directory URL
    var desktopDirectory: URL? {
        return fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
    }
    
    /// Gets the Documents directory URL
    var documentsDirectory: URL? {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    /// Renames a folder
    /// - Parameters:
    ///   - url: Current folder URL
    ///   - newName: New name for the folder
    /// - Returns: New URL if successful, nil otherwise
    func renameFolder(at url: URL, to newName: String) -> URL? {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        
        do {
            try fileManager.moveItem(at: url, to: newURL)
            SecurityBookmarkManager.shared.removeBookmark(for: url)
            SecurityBookmarkManager.shared.saveBookmark(for: newURL)
            return newURL
        } catch {
            print("Failed to rename folder: \(error.localizedDescription)")
            return nil
        }
    }
}
