import Foundation

/// Represents a collection of themed folder icons
struct IconPack: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let description: String
    let emoji: String
    let accentColorHex: String
    var icons: [FolderIcon]
    var isCustom: Bool = false
    
    var iconCount: Int { icons.count }
    
    /// Category tag for filtering
    var category: String {
        if isCustom { return "Custom" }
        switch id {
        case "attack-on-titan", "black-clover", "chainsaw-man", "dandadan", "death-note",
             "demon-slayer", "dragon-ball-super", "fullmetal-alchemist-brotherhood",
             "jujutsu-kaisen", "kaiju-no-8", "naruto", "one-piece", "pokemon", "solo-leveling":
            return "Anime"
        case "developer-tech":
            return "Dev & Tech"
        case "google":
            return "Apps"
        case "macos-native-plus":
            return "System"
        default:
            return "Other"
        }
    }
    
    /// Preview icons (first 4) for grid thumbnails
    var previewIcons: [FolderIcon] {
        Array(icons.prefix(4))
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, emoji, accentColorHex, icons, isCustom
    }
    
    init(
        id: String,
        name: String,
        description: String,
        emoji: String,
        accentColorHex: String,
        icons: [FolderIcon],
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.emoji = emoji
        self.accentColorHex = accentColorHex
        self.icons = icons
        self.isCustom = isCustom
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        emoji = try container.decode(String.self, forKey: .emoji)
        accentColorHex = try container.decode(String.self, forKey: .accentColorHex)
        icons = try container.decodeIfPresent([FolderIcon].self, forKey: .icons) ?? []
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: IconPack, rhs: IconPack) -> Bool {
        lhs.id == rhs.id
    }
}
