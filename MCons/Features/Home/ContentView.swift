import SwiftUI

/// Main content view with NavigationSplitView sidebar
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 225, max: 260)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .alert(
            appState.currentError?.errorDescription ?? "Error",
            isPresented: $appState.showErrorAlert,
            presenting: appState.currentError
        ) { error in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text([error.failureReason, error.recoverySuggestion].compactMap { $0 }.joined(separator: "\n\n"))
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        Group {
            switch appState.selectedSidebarItem {
            case .home:
                HomeView()
            case .iconPacks:
                IconPacksView()
            case .applyIcon:
                IconApplyView()
            case .updates:
                UpdaterView()
            case .settings:
                SettingsView()
            case .about:
                AboutView()
            }
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
    }
}

// MARK: - Refined Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var updateService = UpdateService.shared
    @State private var hoveredItem: SidebarItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // App Branding Header
            appBrandHeader
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.md)
            
            Divider()
                .opacity(0.4)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.sm)
            
            // Navigation Groups
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    // Main Navigation
                    navigationGroup(title: "DISCOVER") {
                        sidebarButton(for: .home)
                        sidebarButton(for: .iconPacks)
                        sidebarButton(for: .applyIcon)
                    }
                    
                    // Preferences & Info
                    navigationGroup(title: "PREFERENCES") {
                        sidebarButton(for: .updates)
                        sidebarButton(for: .settings)
                        sidebarButton(for: .about)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
            }
            
            Spacer(minLength: 0)
            
            // Footer (Status or Update Widget)
            sidebarFooter
                .padding(AppTheme.Spacing.sm)
        }
        .background(AppTheme.Colors.sidebarBackground)
    }
    
    // MARK: - App Brand Header
    
    private var appBrandHeader: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(nsImage: .appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .shadow(color: Color.black.opacity(0.2), radius: 3, y: 1.5)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("MCons")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.primary)
                
                Text("Icons for MacOS")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("v\(updateService.currentVersion)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .foregroundStyle(.secondary)
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Navigation Group
    
    private func navigationGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, 2)
            
            content()
        }
    }
    
    // MARK: - Sidebar Item Button
    
    private func sidebarButton(for item: SidebarItem) -> some View {
        let isSelected = appState.selectedSidebarItem == item
        let isHovered = hoveredItem == item
        
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                appState.selectedSidebarItem = item
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                // Leading accent indicator bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? AnyShapeStyle(AppTheme.Colors.accentGradient) : AnyShapeStyle(Color.clear))
                    .frame(width: 3, height: 16)
                
                // Icon
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                        ? AnyShapeStyle(AppTheme.Colors.accentGradient)
                        : AnyShapeStyle(.secondary)
                    )
                    .frame(width: 20)
                
                // Title
                Text(item.rawValue)
                    .font(isSelected ? AppTheme.Typography.bodyBold : AppTheme.Typography.body)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Spacer()
                
                // Update badge dot on Updates item
                if item == .updates, case .updateAvailable = updateService.status {
                    Circle()
                        .fill(Color(hex: "#00B894"))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.vertical, 7)
            .padding(.trailing, AppTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                    .fill(
                        isSelected
                        ? Color.white.opacity(0.08)
                        : (isHovered ? Color.white.opacity(0.04) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredItem = hovering ? item : nil
        }
    }
    
    // MARK: - Footer
    
    private var sidebarFooter: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            if !appState.statusMessage.isEmpty {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: appState.showSuccessAnimation ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundColor(appState.showSuccessAnimation ? AppTheme.Colors.success : .secondary)
                        .font(.caption2)
                    
                    Text(appState.statusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                        .fill(Color.black.opacity(0.2))
                )
                .transition(.opacity)
            }
        }
    }
}
