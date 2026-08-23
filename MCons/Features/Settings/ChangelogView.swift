import SwiftUI

/// Modal sheet displaying release changelog and update actions
struct ChangelogView: View {
    let release: ReleaseInfo
    let isUpdateAvailable: Bool
    @Environment(\.dismiss) private var dismiss
    @StateObject private var updateService = UpdateService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.accentGradient)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isUpdateAvailable ? "sparkles" : "doc.text.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Text(release.name)
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(.primary)
                        
                        if isUpdateAvailable {
                            Text("NEW")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#00B894"))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text("Released on \(release.formattedDate)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(AppTheme.Spacing.xl)
            .background(AppTheme.Colors.cardBackground)
            
            Divider()
            
            // Content / Changelog
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    // Version info row
                    HStack(spacing: AppTheme.Spacing.lg) {
                        versionBadge(title: "Current Version", version: updateService.currentFullVersion, color: .secondary)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        versionBadge(title: "Latest Version", version: release.tagName, color: isUpdateAvailable ? Color(hex: "#6C5CE7") : .secondary)
                    }
                    .padding(.bottom, AppTheme.Spacing.sm)
                    
                    Text("Release Notes & Changelog")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.primary)
                    
                    // Formatted body
                    Text(cleanReleaseNotes(release.body))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                        .padding(AppTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                .fill(AppTheme.Colors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                .stroke(AppTheme.Colors.border, lineWidth: 1)
                        )
                }
                .padding(AppTheme.Spacing.xl)
            }
            
            Divider()
            
            // Footer Action Buttons
            HStack(spacing: AppTheme.Spacing.md) {
                if let htmlURL = release.htmlURL {
                    Button {
                        NSWorkspace.shared.open(htmlURL)
                    } label: {
                        Label("View on GitHub", systemImage: "arrow.up.right")
                            .font(AppTheme.Typography.body)
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                if isUpdateAvailable {
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
                                Text("Update Now")
                            }
                        }
                        .font(AppTheme.Typography.bodyBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, 6)
                        .background(AppTheme.Colors.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))
                    }
                    .buttonStyle(.plain)
                    .disabled(updateService.isUpdating)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.Colors.cardBackground)
        }
        .frame(minWidth: 550, idealWidth: 600, minHeight: 450, idealHeight: 520)
        .background(AppTheme.Colors.background)
    }
    
    private func versionBadge(title: String, version: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
            
            Text(version)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
    
    private func cleanReleaseNotes(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
