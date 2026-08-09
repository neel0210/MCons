import Foundation

/// Represents a collection of themed folder icons
struct IconPack: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let description: String
    let emoji: String
    let accentColorHex: String
    var icons: [FolderIcon]
    
    var iconCount: Int { icons.count }
    
    /// Preview icons (first 4) for grid thumbnails
    var previewIcons: [FolderIcon] {
        Array(icons.prefix(4))
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: IconPack, rhs: IconPack) -> Bool {
        lhs.id == rhs.id
    }
}
