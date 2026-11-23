import Foundation

// MARK: - Sidebar Navigation

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case iconPacks = "Icon Packs"
    case favorites = "Favorites"
    case applyIcon = "Apply Icon"
    case batchApply = "Batch Apply"
    case packBuilder = "Pack Builder"
    case updates = "Updates"
    case settings = "Settings"
    case about = "About"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .iconPacks: return "square.grid.3x3.fill"
        case .favorites: return "star.fill"
        case .applyIcon: return "folder.badge.plus"
        case .batchApply: return "square.stack.3d.up.fill"
        case .packBuilder: return "wrench.and.screwdriver.fill"
        case .updates: return "arrow.triangle.2.circlepath"
        case .settings: return "gearshape.fill"
        case .about: return "info.circle.fill"
        }
    }
}
