import AppKit
import Foundation

// MARK: - App Delegate & macOS Services Integration

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appState: AppState?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }
    
    // Service provider for macOS Finder context menu: "Apply Icon with MCons"
    @objc func applyIconFromService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let types = pboard.types, types.contains(.fileURL),
              let url = pboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let appState = self?.appState else { return }
            appState.targetFolderURL = url
            appState.selectedSidebarItem = .applyIcon
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        if let folderURL = urls.first {
            DispatchQueue.main.async { [weak self] in
                guard let appState = self?.appState else { return }
                appState.targetFolderURL = folderURL
                appState.selectedSidebarItem = .applyIcon
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
