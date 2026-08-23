import SwiftUI

/// Standalone Software Update & Changelog view
struct UpdaterView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var updateService = UpdateService.shared
    @State private var isCopied: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                // Header
                headerSection
                    .fadeInUp()
                
                // Version & Check Card
                versionCard
                    .fadeInUp(delay: 0.1)
                
                // Release & Changelog Card
                releaseAndChangelogCard
                    .fadeInUp(delay: 0.2)
                
                // Terminal 1-Liner Fallback Card
                terminalHelperCard
                    .fadeInUp(delay: 0.3)
                
                Spacer(minLength: AppTheme.Spacing.xxl)
            }
            .padding(AppTheme.Spacing.xxl)
        }
        .background(AppTheme.Colors.background)
        .onAppear {
            if updateService.status == .idle {
                Task {
                    await updateService.checkForUpdates(silent: true)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Text("Software Update")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(.primary)
                
                if case .updateAvailable = updateService.status {
                    Text("NEW")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#00B894"))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            
            Text("Keep MCons updated with latest icon packs, macOS enhancements, and bug fixes.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Version & Check Card
    
    private var versionCard: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            HStack(spacing: AppTheme.Spacing.lg) {
                Image(nsImage: .appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.black.opacity(0.18), radius: 5, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Text("MCons")
                            .font(AppTheme.Typography.title2)
                            .foregroundStyle(.primary)
                        
                        Text(updateService.currentFullVersion)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    
                    statusPill
                }
                
                Spacer()
                
                Button {
                    Task {
                        await updateService.checkForUpdates(silent: false)
                    }
                } label: {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        if updateService.status == .checking {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 16, height: 16)
                            Text("Checking...")
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text("Check for Updates")
                        }
                    }
                    .font(AppTheme.Typography.body)
                }
                .buttonStyle(.bordered)
                .disabled(updateService.status == .checking || updateService.isUpdating)
            }
            
            if let date = updateService.lastCheckedDate {
                Divider()
                
                HStack {
                    Text("Last checked: \(date.formatted(date: .abbreviated, time: .standard))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("Channel: GitHub Releases (Stable)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(AppTheme.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                .fill(AppTheme.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }
    
    // MARK: - Status Pill
    
    @ViewBuilder
    private var statusPill: some View {
        switch updateService.status {
        case .idle:
            Text("Ready to check")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        case .checking:
            Text("Connecting to GitHub Releases...")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        case .updateAvailable(let release):
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                Text("Version \(release.tagName) available!")
            }
            .font(AppTheme.Typography.captionBold)
            .foregroundStyle(Color(hex: "#00B894"))
        case .upToDate:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("You're on the latest version")
            }
            .font(AppTheme.Typography.captionBold)
            .foregroundStyle(AppTheme.Colors.success)
        case .error(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Check failed: \(msg)")
            }
            .font(AppTheme.Typography.caption)
            .foregroundStyle(AppTheme.Colors.error)
        }
    }
    
    // MARK: - Release & Changelog Card
    
    @ViewBuilder
    private var releaseAndChangelogCard: some View {
        if let release = updateService.latestRelease {
            let isAvailable: Bool = {
                if case .updateAvailable = updateService.status { return true }
                return false
            }()
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Release Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Text(release.name)
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(.primary)
                            
                            if isAvailable {
                                Text("UPDATE")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.Colors.accentGradient)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Text("Published on \(release.formattedDate) • Tag: \(release.tagName)")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if isAvailable {
                        Button {
                            Task {
                                await updateService.installUpdateDirectly()
                            }
                        } label: {
                            HStack(spacing: AppTheme.Spacing.xs) {
                                if updateService.isUpdating {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 14, height: 14)
                                    Text(updateService.updateProgressText.isEmpty ? "Updating..." : updateService.updateProgressText)
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Install Update")
                                }
                            }
                            .font(AppTheme.Typography.bodyBold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                            .padding(.vertical, 8)
                            .background(AppTheme.Colors.accentGradient)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))
                        }
                        .buttonStyle(.plain)
                        .disabled(updateService.isUpdating)
                    }
                }
                
                Divider()
                
                // Release Notes / Changelog Text
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Release Notes")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(.secondary)
                    
                    Text(release.body.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                        .padding(AppTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                .fill(Color.black.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                .stroke(AppTheme.Colors.border, lineWidth: 1)
                        )
                }
                
                // Action Links
                HStack(spacing: AppTheme.Spacing.md) {
                    if let htmlURL = release.htmlURL {
                        Button {
                            NSWorkspace.shared.open(htmlURL)
                        } label: {
                            Label("View on GitHub", systemImage: "arrow.up.right")
                                .font(AppTheme.Typography.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(hex: "#6C5CE7"))
                    }
                    
                    Button {
                        updateService.launchInstallerInTerminal()
                    } label: {
                        Label("Update via Terminal", systemImage: "terminal")
                            .font(AppTheme.Typography.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    
                    Spacer()
                }
            }
            .padding(AppTheme.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .fill(AppTheme.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .stroke(
                        isAvailable
                        ? Color(hex: "#6C5CE7").opacity(0.3)
                        : AppTheme.Colors.border,
                        lineWidth: 1
                    )
            )
        }
    }
    
    // MARK: - Terminal Helper Card
    
    private var terminalHelperCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Label("1-Line Terminal Installer & Updater", systemImage: "terminal.fill")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.primary)
            
            Text("If you prefer installing/updating via Terminal, run the official 1-line script below. It automatically downloads the latest build, bypasses Gatekeeper quarantine, and updates MCons:")
                .font(AppTheme.Typography.callout)
                .foregroundStyle(.secondary)
            
            HStack(spacing: AppTheme.Spacing.sm) {
                Text("curl -fsSL https://raw.githubusercontent.com/neel0210/MCons/main/install.sh | bash")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00D2FF"))
                    .lineLimit(1)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))
                
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("curl -fsSL https://raw.githubusercontent.com/neel0210/MCons/main/install.sh | bash", forType: .string)
                    isCopied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        isCopied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied" : "Copy")
                    }
                    .font(AppTheme.Typography.captionBold)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(AppTheme.Spacing.xl)
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
