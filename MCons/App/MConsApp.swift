import SwiftUI

@main
struct MConsApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    configureWindow()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NSApp.keyWindow?.undoManager?.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                
                Button("Redo") {
                    NSApp.keyWindow?.undoManager?.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
    
    private func configureWindow() {
        // Configure the main window appearance
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
        }
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var previousSidebarItem: SidebarItem?
    @Published var selectedSidebarItem: SidebarItem = .home {
        didSet {
            if oldValue != selectedSidebarItem {
                previousSidebarItem = oldValue
            }
        }
    }
    @Published var selectedIconPack: IconPack?
    @Published var selectedIcon: FolderIcon?
    @Published var targetFolderURL: URL? {
        didSet {
            if let url = targetFolderURL {
                SecurityBookmarkManager.shared.saveBookmark(for: url)
            }
        }
    }
    @Published var recentFolders: [URL] = []
    @Published var showSuccessAnimation: Bool = false
    @Published var statusMessage: String = ""
    @Published var currentError: IconServiceError?
    @Published var showErrorAlert: Bool = false
    @Published var cachedIconPacks: [IconPack] = []
    
    let iconService = IconService()
    let folderService = FolderService()
    let iconPackLoader = IconPackLoader()
    
    init() {
        // Instant synchronous first-pass pack metadata loading
        let packs = iconPackLoader.loadAllPacks()
        self.cachedIconPacks = packs
        // Background async preheating of all icon bitmaps for silky smooth 120fps UI
        IconImageCache.shared.preheat(packs: packs)
    }
    
    /// Returns cached icon packs instantly without disk re-scanning
    func loadIconPacks() -> [IconPack] {
        if !cachedIconPacks.isEmpty {
            return cachedIconPacks
        }
        let packs = iconPackLoader.loadAllPacks()
        cachedIconPacks = packs
        IconImageCache.shared.preheat(packs: packs)
        return packs
    }
    
    /// Force refreshes packs and updates the image cache
    func refreshIconPacks() {
        let packs = iconPackLoader.loadAllPacks()
        cachedIconPacks = packs
        IconImageCache.shared.preheat(packs: packs)
    }
    
    /// Executes folder rename and icon application as an atomic operation with UndoManager support (Cmd+Z)
    func applyAtomicOperation(
        icon: FolderIcon,
        targetFolder: URL,
        desiredName: String,
        undoManager: UndoManager? = nil
    ) -> Bool {
        let originalURL = targetFolder
        let originalName = targetFolder.lastPathComponent
        let hadCustomIcon = iconService.hasCustomIcon(for: originalURL)
        let originalIconImage: NSImage? = hadCustomIcon ? iconService.getIcon(for: originalURL) : nil
        
        let cleanName = desiredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newName = cleanName.isEmpty ? originalName : cleanName
        
        var currentURL = originalURL
        var didRename = false
        
        // Step 1: Perform Rename if requested
        if newName != originalName {
            if let renamedURL = folderService.renameFolder(at: originalURL, to: newName) {
                currentURL = renamedURL
                didRename = true
            } else {
                let err = IconServiceError.unknown("Failed to rename folder from '\(originalName)' to '\(newName)'.")
                currentError = err
                showErrorAlert = true
                statusMessage = "Rename failed"
                return false
            }
        }
        
        // Step 2: Load and Apply Icon with Rollback on failure
        guard let image = icon.loadImage() else {
            if didRename {
                _ = folderService.renameFolder(at: currentURL, to: originalName)
            }
            let err = IconServiceError.invalidImage
            currentError = err
            showErrorAlert = true
            statusMessage = "Failed to load icon"
            return false
        }
        
        do {
            try iconService.setIcon(image: image, for: currentURL)
        } catch {
            // Rollback rename if setIcon fails
            if didRename {
                _ = folderService.renameFolder(at: currentURL, to: originalName)
            }
            if let iconErr = error as? IconServiceError {
                currentError = iconErr
            } else {
                currentError = IconServiceError.unknown(error.localizedDescription)
            }
            showErrorAlert = true
            statusMessage = currentError?.errorDescription ?? "Failed to apply icon"
            return false
        }
        
        // Step 3: Success state updates
        self.targetFolderURL = currentURL
        self.statusMessage = didRename ? "Folder renamed & icon applied!" : "Icon applied successfully!"
        self.showSuccessAnimation = true
        
        if !recentFolders.contains(currentURL) {
            recentFolders.insert(currentURL, at: 0)
            if recentFolders.count > 10 {
                recentFolders.removeLast()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showSuccessAnimation = false
        }
        
        // Step 4: Register Undo action with UndoManager
        if let undoManager = undoManager {
            undoManager.registerUndo(withTarget: self) { [weak self] _ in
                self?.performRollback(
                    currentURL: currentURL,
                    originalURL: originalURL,
                    didRename: didRename,
                    originalName: originalName,
                    hadCustomIcon: hadCustomIcon,
                    originalIconImage: originalIconImage,
                    redoIcon: icon,
                    redoDesiredName: desiredName,
                    undoManager: undoManager
                )
            }
            undoManager.setActionName(didRename ? "Apply Icon & Rename" : "Apply Icon")
        }
        
        return true
    }
    
    /// Reverses an atomic folder operation (Undo / Redo execution)
    private func performRollback(
        currentURL: URL,
        originalURL: URL,
        didRename: Bool,
        originalName: String,
        hadCustomIcon: Bool,
        originalIconImage: NSImage?,
        redoIcon: FolderIcon,
        redoDesiredName: String,
        undoManager: UndoManager
    ) {
        // 1. Restore previous icon
        if hadCustomIcon, let prevImage = originalIconImage {
            try? iconService.setIcon(image: prevImage, for: currentURL)
        } else {
            try? iconService.resetIcon(for: currentURL)
        }
        
        // 2. Restore original folder name if it was renamed
        var restoredURL = currentURL
        if didRename {
            if let unrenamedURL = folderService.renameFolder(at: currentURL, to: originalName) {
                restoredURL = unrenamedURL
            }
        }
        
        // Update AppState UI
        self.targetFolderURL = restoredURL
        self.statusMessage = "Undid icon & rename operation (Cmd+Z)"
        
        // 3. Register Redo operation
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            _ = self?.applyAtomicOperation(
                icon: redoIcon,
                targetFolder: restoredURL,
                desiredName: redoDesiredName,
                undoManager: undoManager
            )
        }
        undoManager.setActionName(didRename ? "Apply Icon & Rename" : "Apply Icon")
    }
    
    func applyIcon(_ icon: FolderIcon, to folderURL: URL) -> Bool {
        return applyAtomicOperation(icon: icon, targetFolder: folderURL, desiredName: folderURL.lastPathComponent)
    }
    
    func resetIcon(for folderURL: URL) -> Bool {
        do {
            try iconService.resetIcon(for: folderURL)
            statusMessage = "Icon reset to default"
            return true
        } catch let err as IconServiceError {
            currentError = err
            showErrorAlert = true
            statusMessage = err.errorDescription ?? "Failed to reset icon"
            return false
        } catch {
            let err = IconServiceError.unknown(error.localizedDescription)
            currentError = err
            showErrorAlert = true
            statusMessage = err.errorDescription ?? "Failed to reset icon"
            return false
        }
    }
}

// MARK: - Sidebar Navigation

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case iconPacks = "Icon Packs"
    case applyIcon = "Apply Icon"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .iconPacks: return "square.grid.3x3.fill"
        case .applyIcon: return "folder.badge.plus"
        case .settings: return "gearshape.fill"
        }
    }
}
