import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Menu Bar quick access popup: Allows drag-and-drop icon apply and favorites access from the macOS status bar
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var isTargeted: Bool = false
    @State private var statusFeedback: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("MCons Quick Apply")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.title == "MCons" || $0.canBecomeKey }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open Main Window")
            }
            
            Divider()
            
            // Drop target for quick folder selection
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 3])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.04))
                    )
                
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.targetFolderURL?.lastPathComponent ?? "Drop Folder Here")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text(appState.targetFolderURL != nil ? "Folder ready for icon" : "Drag folder from Finder")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        chooseFolder()
                    } label: {
                        Text("Browse")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
            }
            .frame(height: 52)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
            
            // Favorites Quick-Apply Strip
            let favorites = appState.favoriteIcons()
            if !favorites.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("FAVORITE ICONS (1-CLICK)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(favorites.prefix(8)) { icon in
                                Button {
                                    applyFavorite(icon: icon)
                                } label: {
                                    VStack(spacing: 2) {
                                        Image(nsImage: icon.previewImage())
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 36, height: 36)
                                        Text(icon.name)
                                            .font(.system(size: 9))
                                            .lineLimit(1)
                                            .frame(width: 44)
                                    }
                                    .padding(4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.primary.opacity(0.04))
                                    )
                                }
                                .buttonStyle(.plain)
                                .help("Apply \(icon.name) to selected folder")
                            }
                        }
                    }
                }
            }
            
            // Recent Folders
            if !appState.recentFolders.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RECENT FOLDERS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    ForEach(appState.recentFolders.prefix(3), id: \.self) { url in
                        Button {
                            appState.targetFolderURL = url
                            statusFeedback = "Target: \(url.lastPathComponent)"
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                                Text(url.lastPathComponent)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Status Feedback
            if let feedback = statusFeedback {
                Text(feedback)
                    .font(.caption2)
                    .foregroundStyle(Color.green)
            }
            
            Divider()
            
            // Footer controls
            HStack {
                Button("Open MCons") {
                    NSApp.activate(ignoringOtherApps: true)
                    if let mainWindow = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain }) {
                        mainWindow.makeKeyAndOrderFront(nil)
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 290)
    }
    
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            appState.targetFolderURL = url
            statusFeedback = "Selected: \(url.lastPathComponent)"
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                DispatchQueue.main.async {
                    appState.targetFolderURL = url
                    statusFeedback = "Selected: \(url.lastPathComponent)"
                }
            }
        }
    }
    
    private func applyFavorite(icon: FolderIcon) {
        guard let folder = appState.targetFolderURL else {
            statusFeedback = "Drop or select a folder first!"
            return
        }
        
        let success = appState.applyAtomicOperation(
            icon: icon,
            targetFolder: folder,
            desiredName: folder.lastPathComponent
        )
        
        statusFeedback = success ? "Applied \(icon.name)!" : "Failed to apply"
    }
}
