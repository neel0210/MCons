import AppKit
import Foundation
import SwiftUI

/// Represents metadata for a GitHub release
struct ReleaseInfo: Identifiable, Sendable {
    let id: String
    let tagName: String
    let name: String
    let body: String
    let publishedAt: String
    let htmlURL: URL?
    let downloadURL: URL?
    let isPrerelease: Bool
    
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: publishedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return publishedAt
    }
}

/// Status of update check
enum UpdateStatus: Equatable {
    case idle
    case checking
    case updateAvailable(ReleaseInfo)
    case upToDate
    case error(String)
    
    static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking), (.upToDate, .upToDate):
            return true
        case (.updateAvailable(let a), .updateAvailable(let b)):
            return a.tagName == b.tagName
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Manages checking for updates, parsing changelogs, and executing updates
@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()
    
    @Published var status: UpdateStatus = .idle
    @Published var latestRelease: ReleaseInfo?
    @Published var showChangelogSheet: Bool = false
    @Published var lastCheckedDate: Date?
    
    @Published var isUpdating: Bool = false
    @Published var updateProgressText: String = ""
    
    private let repo = "neel0210/MCons"
    
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.2"
    }
    
    var currentBuildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var currentFullVersion: String {
        "v\(currentVersion).\(currentBuildNumber)"
    }
    
    /// Checks GitHub Releases API for new version
    func checkForUpdates(silent: Bool = false) async {
        status = .checking
        
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            status = .error("Invalid update URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("MCons-App", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if !silent {
                    status = .error("Failed to connect to update server")
                } else {
                    status = .idle
                }
                return
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                status = .error("Malformed release metadata")
                return
            }
            
            let name = json["name"] as? String ?? tagName
            let body = json["body"] as? String ?? "No release notes provided."
            let publishedAt = json["published_at"] as? String ?? ""
            let htmlURLStr = json["html_url"] as? String ?? ""
            let isPrerelease = json["prerelease"] as? Bool ?? false
            
            var downloadURL: URL?
            if let assets = json["assets"] as? [[String: Any]], let firstAsset = assets.first,
               let downloadStr = firstAsset["browser_download_url"] as? String {
                downloadURL = URL(string: downloadStr)
            }
            
            let release = ReleaseInfo(
                id: tagName,
                tagName: tagName,
                name: name,
                body: body,
                publishedAt: publishedAt,
                htmlURL: URL(string: htmlURLStr),
                downloadURL: downloadURL,
                isPrerelease: isPrerelease
            )
            
            self.lastCheckedDate = Date()
            self.latestRelease = release
            
            if isVersionNewer(remoteTag: tagName, currentVersion: currentVersion, currentBuild: currentBuildNumber) {
                self.status = .updateAvailable(release)
                if !silent {
                    self.showChangelogSheet = true
                }
            } else {
                self.status = .upToDate
            }
        } catch {
            if !silent {
                self.status = .error(error.localizedDescription)
            } else {
                self.status = .idle
            }
        }
    }
    
    /// Compares remote tag with current version
    func isVersionNewer(remoteTag: String, currentVersion: String, currentBuild: String) -> Bool {
        let cleanTag = remoteTag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let remoteParts = cleanTag.split(separator: ".").compactMap { Int($0) }
        
        let cleanCurrent = currentVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        var currentParts = cleanCurrent.split(separator: ".").compactMap { Int($0) }
        
        // If remote tag has 4 components (e.g. 1.0.2.21) and local has 3 (1.0.2), append build number
        if remoteParts.count > currentParts.count {
            let buildNum = Int(currentBuild) ?? 0
            currentParts.append(buildNum)
        }
        
        for i in 0..<max(remoteParts.count, currentParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        
        return false
    }
    
    /// Launches the 1-line update script in Terminal via a temporary executable script
    func launchInstallerInTerminal() {
        let scriptPath = "/tmp/mcons_update.command"
        let script = """
        #!/bin/bash
        echo "=========================================="
        echo "          🚀 Updating MCons...            "
        echo "=========================================="
        echo ""
        curl -fsSL https://raw.githubusercontent.com/neel0210/MCons/main/install.sh | bash
        """
        
        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        let chmod = Process()
        chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmod.arguments = ["+x", scriptPath]
        try? chmod.run()
        chmod.waitUntilExit()
        
        NSWorkspace.shared.open(URL(fileURLWithPath: scriptPath))
    }
    
    /// Downloads and installs update directly in background with visual progress
    func installUpdateDirectly() async {
        guard let release = latestRelease else {
            launchInstallerInTerminal()
            return
        }
        
        let downloadURL = release.downloadURL ?? URL(string: "https://github.com/\(repo)/releases/download/\(release.tagName)/MCons-v1.0.2-release.zip")!
        
        isUpdating = true
        updateProgressText = "Downloading \(release.tagName)..."
        
        do {
            let (tempZipURL, _) = try await URLSession.shared.download(from: downloadURL)
            updateProgressText = "Extracting..."
            
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let ditto = Process()
            ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            ditto.arguments = ["-x", "-k", tempZipURL.path, tempDir.path]
            try ditto.run()
            ditto.waitUntilExit()
            
            updateProgressText = "Installing..."
            
            var extractedApp = tempDir.appendingPathComponent("MCons.app")
            if !FileManager.default.fileExists(atPath: extractedApp.path) {
                if let found = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil).first(where: { $0.lastPathComponent == "MCons.app" }) {
                    extractedApp = found
                }
            }
            
            guard FileManager.default.fileExists(atPath: extractedApp.path) else {
                throw NSError(domain: "MCons", code: 1, userInfo: [NSLocalizedDescriptionKey: "Extracted app not found"])
            }
            
            var targetDir = URL(fileURLWithPath: "/Applications")
            if !FileManager.default.isWritableFile(atPath: targetDir.path) {
                targetDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
                try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
            }
            let targetApp = targetDir.appendingPathComponent("MCons.app")
            
            _ = try? FileManager.default.removeItem(at: targetApp)
            try FileManager.default.copyItem(at: extractedApp, to: targetApp)
            
            let xattr = Process()
            xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattr.arguments = ["-cr", targetApp.path]
            try? xattr.run()
            xattr.waitUntilExit()
            
            updateProgressText = "Relaunching MCons..."
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            NSWorkspace.shared.open(targetApp)
            try? await Task.sleep(nanoseconds: 400_000_000)
            NSApplication.shared.terminate(nil)
        } catch {
            isUpdating = false
            updateProgressText = "Direct install failed. Opening Terminal..."
            launchInstallerInTerminal()
        }
    }
}
