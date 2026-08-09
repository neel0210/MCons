import AppKit
import Foundation

/// Loads icon packs from the app bundle's Resources/IconPacks directory
final class IconPackLoader: Sendable {
    
    /// Loads all icon packs from the bundle and resource paths
    /// - Returns: Array of IconPack models
    func loadAllPacks() -> [IconPack] {
        var possiblePackURLs: [URL] = []
        
        if let resURL = Bundle.main.resourceURL {
            possiblePackURLs.append(resURL.appendingPathComponent("MCons_MCons.bundle/IconPacks"))
            possiblePackURLs.append(resURL.appendingPathComponent("IconPacks"))
        }
        
        #if SWIFT_PACKAGE
        if let moduleResURL = Bundle.module.resourceURL {
            possiblePackURLs.append(moduleResURL.appendingPathComponent("IconPacks"))
            possiblePackURLs.append(moduleResURL)
        }
        #endif
        
        // Development path fallback
        let currentDirURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        possiblePackURLs.append(currentDirURL.appendingPathComponent("MCons/Resources/IconPacks"))
        
        var loadedPacks: [String: IconPack] = [:]
        
        for packsURL in possiblePackURLs {
            let fileManager = FileManager.default
            guard let packDirs = try? fileManager.contentsOfDirectory(
                at: packsURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            for dir in packDirs {
                let isDir = (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                guard isDir else { continue }
                
                let metadataURL = dir.appendingPathComponent("metadata.json")
                var packId = dir.lastPathComponent.lowercased()
                var name = dir.lastPathComponent.capitalized
                var description = "Custom folder icon pack"
                var emoji = "📁"
                var accentColorHex = "#6C5CE7"
                
                if let data = try? Data(contentsOf: metadataURL),
                   let metadata = try? JSONDecoder().decode(IconPackMetadata.self, from: data) {
                    packId = metadata.id
                    name = metadata.name
                    description = metadata.description
                    emoji = metadata.emoji
                    accentColorHex = metadata.accentColorHex
                }
                
                let icons = loadIcons(from: dir, packId: packId)
                if !icons.isEmpty {
                    let pack = IconPack(
                        id: packId,
                        name: name,
                        description: description,
                        emoji: emoji,
                        accentColorHex: accentColorHex,
                        icons: icons
                    )
                    if loadedPacks[packId] == nil {
                        loadedPacks[packId] = pack
                    }
                }
            }
        }
        
        var allPacks = Array(loadedPacks.values)
        
        // Combine with default color packs if not already present
        for defaultPack in defaultPacks() {
            if loadedPacks[defaultPack.id] == nil {
                allPacks.append(defaultPack)
            }
        }
        
        return allPacks.sorted { $0.name < $1.name }
    }
    
    /// Loads individual icons from a pack directory
    private func loadIcons(from directory: URL, packId: String) -> [FolderIcon] {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        let imageExtensions = ["png", "jpg", "jpeg", "icns", "tiff"]
        
        return files
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { fileURL in
                FolderIcon(
                    id: "\(packId)_\(fileURL.deletingPathExtension().lastPathComponent)",
                    name: fileURL.deletingPathExtension().lastPathComponent
                        .replacingOccurrences(of: "_", with: " ")
                        .replacingOccurrences(of: "-", with: " ")
                        .capitalized,
                    packId: packId,
                    fileURL: fileURL
                )
            }
    }
    
    /// Returns default icon packs with programmatically generated icons
    func defaultPacks() -> [IconPack] {
        return [
            IconPack(
                id: "dark-mode-pro",
                name: "Dark Mode Pro",
                description: "Sleek matte black folders with neon accent edges",
                emoji: "🌙",
                accentColorHex: "#00F5FF",
                icons: generateDefaultIcons(packId: "dark-mode-pro", colors: [
                    ("Neon Cyan", "#00F5FF"),
                    ("Neon Green", "#00FF88"),
                    ("Neon Purple", "#BF00FF"),
                    ("Neon Pink", "#FF0080"),
                    ("Neon Orange", "#FF6600"),
                    ("Neon Yellow", "#FFE600"),
                    ("Neon Red", "#FF0040"),
                    ("Neon Blue", "#0066FF"),
                    ("Neon Lime", "#AAFF00"),
                    ("Neon Magenta", "#FF00FF"),
                    ("Neon Teal", "#00FFCC"),
                    ("Neon White", "#F0F0F0"),
                ])
            ),
            IconPack(
                id: "macos-native-plus",
                name: "macOS Native+",
                description: "Enhanced versions of Apple's native folder colors",
                emoji: "🍎",
                accentColorHex: "#007AFF",
                icons: generateDefaultIcons(packId: "macos-native-plus", colors: [
                    ("System Blue", "#007AFF"),
                    ("System Purple", "#AF52DE"),
                    ("System Pink", "#FF2D55"),
                    ("System Red", "#FF3B30"),
                    ("System Orange", "#FF9500"),
                    ("System Yellow", "#FFCC00"),
                    ("System Green", "#34C759"),
                    ("System Teal", "#5AC8FA"),
                    ("System Indigo", "#5856D6"),
                    ("System Brown", "#A2845E"),
                    ("System Mint", "#00C7BE"),
                    ("System Graphite", "#8E8E93"),
                ])
            ),
        ]
    }
    
    /// Generates default folder icons using programmatic rendering
    private func generateDefaultIcons(packId: String, colors: [(String, String)]) -> [FolderIcon] {
        return colors.map { (name, hex) in
            FolderIcon(
                id: "\(packId)_\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
                name: name,
                packId: packId,
                colorHex: hex
            )
        }
    }
}

// MARK: - Pack Metadata for JSON

struct IconPackMetadata: Codable {
    let id: String
    let name: String
    let description: String
    let emoji: String
    let accentColorHex: String
}
