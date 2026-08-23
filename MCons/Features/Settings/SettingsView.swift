import SwiftUI

/// App settings / preferences view
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("defaultIconSize") private var defaultIconSize: Double = 512
    @AppStorage("showIconNames") private var showIconNames: Bool = true
    @AppStorage("autoRefreshFinder") private var autoRefreshFinder: Bool = true
    @AppStorage("recentFolderLimit") private var recentFolderLimit: Int = 10
    
    @StateObject private var updateService = UpdateService.shared
    @State private var selectedReleaseForChangelog: ReleaseInfo?
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                // Header
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Settings")
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(.primary)
                    
                    Text("Configure MCons preferences")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Icon Settings
                settingsSection(title: "Icons", icon: "photo.fill") {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Icon size
                        HStack {
                            Label("Default Icon Size", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(AppTheme.Typography.body)
                            Spacer()
                            Picker("", selection: Binding(
                                get: { Int(defaultIconSize) },
                                set: { defaultIconSize = Double($0) }
                            )) {
                                Text("256×256").tag(256)
                                Text("512×512").tag(512)
                                Text("1024×1024").tag(1024)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 240)
                        }
                        
                        Divider()
                        
                        // Show icon names
                        Toggle(isOn: $showIconNames) {
                            Label("Show icon names in grid", systemImage: "textformat")
                                .font(AppTheme.Typography.body)
                        }
                        .toggleStyle(.switch)
                    }
                }
                
                // Behavior Settings
                settingsSection(title: "Behavior", icon: "gearshape.fill") {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        Toggle(isOn: $autoRefreshFinder) {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Auto-refresh Finder", systemImage: "arrow.clockwise")
                                    .font(AppTheme.Typography.body)
                                Text("Automatically nudge Finder to show updated icons")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        
                        Divider()
                        
                        HStack {
                            Label("Recent folders limit", systemImage: "clock")
                                .font(AppTheme.Typography.body)
                            Spacer()
                            Stepper("\(recentFolderLimit)", value: $recentFolderLimit, in: 5...25, step: 5)
                                .frame(width: 120)
                        }
                    }
                }
                
                // Data Management
                settingsSection(title: "Data", icon: "externaldrive.fill") {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Clear Recent Folders", systemImage: "trash")
                                    .font(AppTheme.Typography.body)
                                Text("\(appState.recentFolders.count) folders in history")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Clear") {
                                appState.recentFolders.removeAll()
                                appState.statusMessage = "Recent folders cleared"
                            }
                            .buttonStyle(.bordered)
                            .disabled(appState.recentFolders.isEmpty)
                        }
                    }
                }
                
                // Software Update
                settingsSection(title: "Updates", icon: "arrow.triangle.2.circlepath") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Software Update")
                                .font(AppTheme.Typography.headline)
                            Text("Current version: \(updateService.currentFullVersion)")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            appState.selectedSidebarItem = .updates
                        } label: {
                            HStack(spacing: 4) {
                                Text("Manage Updates")
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // About & Fair Use
                settingsSection(title: "About", icon: "info.circle.fill") {
                    VStack(spacing: AppTheme.Spacing.md) {
                        HStack {
                            Image(nsImage: .appIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 36, height: 36)
                                .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("MCons — Icons for MacOS")
                                    .font(AppTheme.Typography.headline)
                                Text("Version \(updateService.currentFullVersion) • Neel0210")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        Button {
                            appState.selectedSidebarItem = .about
                        } label: {
                            HStack {
                                Label("View About, Fair Use & Licenses", systemImage: "scalemass.fill")
                                    .font(AppTheme.Typography.body)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer(minLength: AppTheme.Spacing.xxl)
            }
            .padding(AppTheme.Spacing.xxl)
        }
        .frame(minWidth: 500)
        .background(AppTheme.Colors.background)
        .sheet(item: $selectedReleaseForChangelog) { release in
            ChangelogView(release: release, isUpdateAvailable: true)
        }
        .sheet(isPresented: $updateService.showChangelogSheet) {
            if let release = updateService.latestRelease {
                ChangelogView(release: release, isUpdateAvailable: true)
            }
        }
    }
    
    @ViewBuilder
    private var updateStatusSubtitle: some View {
        switch updateService.status {
        case .idle:
            if let date = updateService.lastCheckedDate {
                Text("Last checked: \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Automatic updates via GitHub Releases")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        case .checking:
            Text("Checking for updates...")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        case .updateAvailable(let release):
            Text("Update \(release.tagName) available!")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color(hex: "#00B894"))
        case .upToDate:
            Text("You're on the latest version.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        case .error(let msg):
            Text("Check failed: \(msg)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.red)
        }
    }
    
    // MARK: - Settings Section Builder
    
    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Label(title, systemImage: icon)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.primary)
            
            content()
                .padding(AppTheme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                        .fill(AppTheme.Colors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                )
        }
    }
}
