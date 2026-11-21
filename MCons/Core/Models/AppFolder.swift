import Foundation

/// Represents a folder on the file system that the user wants to customize
struct AppFolder: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let hasCustomIcon: Bool
    
    init(url: URL, hasCustomIcon: Bool = false) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.hasCustomIcon = hasCustomIcon
    }
}
