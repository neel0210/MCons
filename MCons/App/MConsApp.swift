import SwiftUI
import AppKit

@main
struct MConsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 840, minHeight: 620)
                .onAppear {
                    configureWindow()
                    appDelegate.appState = appState
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1040, height: 720)
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
        
        MenuBarExtra("MCons", systemImage: "folder.badge.gearshape") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
    
    private func configureWindow() {
        if let window = NSApplication.shared.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain }) ?? NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "mcons" {
            // Support mcons://apply?path=/path/to/folder
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            if let path = components?.queryItems?.first(where: { $0.name == "path" })?.value {
                let folderURL = URL(fileURLWithPath: path)
                appState.targetFolderURL = folderURL
                appState.selectedSidebarItem = .applyIcon
                NSApp.activate(ignoringOtherApps: true)
            }
        } else if url.isFileURL {
            appState.targetFolderURL = url
            appState.selectedSidebarItem = .applyIcon
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
