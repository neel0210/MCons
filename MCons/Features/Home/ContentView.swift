import SwiftUI

/// Main content view with NavigationSplitView sidebar
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 228, max: 260)
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
        .transition(.opacity.animation(.easeInOut(duration: 0.12)))
    }
}

// MARK: - Refined High-Performance Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var updateService = UpdateService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // App Branding Header
            appBrandHeader
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.sm)
            
            Divider()
                .opacity(0.3)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.xs)
            
            // Navigation Groups
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    // Discover Group
                    navigationGroup(title: "DISCOVER") {
                        SidebarRow(
                            item: .home,
                            isSelected: appState.selectedSidebarItem == .home,
                            shortcut: "1",
                            action: { select(.home) }
                        )
                        
                        SidebarRow(
                            item: .iconPacks,
                            isSelected: appState.selectedSidebarItem == .iconPacks,
                            badge: "\(max(appState.cachedIconPacks.count, 6))",
                            shortcut: "2",
                            action: { select(.iconPacks) }
                        )
                        
                        SidebarRow(
                            item: .applyIcon,
                            isSelected: appState.selectedSidebarItem == .applyIcon,
                            shortcut: "3",
                            action: { select(.applyIcon) }
                        )
                    }
                    
                    // Preferences Group
                    navigationGroup(title: "PREFERENCES") {
                        SidebarRow(
                            item: .updates,
                            isSelected: appState.selectedSidebarItem == .updates,
                            hasUpdateBadge: hasAvailableUpdate,
                            shortcut: "4",
                            action: { select(.updates) }
                        )
                        
                        SidebarRow(
                            item: .settings,
                            isSelected: appState.selectedSidebarItem == .settings,
                            shortcut: ",",
                            action: { select(.settings) }
                        )
                        
                        SidebarRow(
                            item: .about,
                            isSelected: appState.selectedSidebarItem == .about,
                            shortcut: "i",
                            action: { select(.about) }
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
            }
            
            Spacer(minLength: 0)
            
            // Status bar footer
            if !appState.statusMessage.isEmpty {
                sidebarFooter
                    .padding(AppTheme.Spacing.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(AppTheme.Colors.sidebarBackground)
    }
    
    private var hasAvailableUpdate: Bool {
        if case .updateAvailable = updateService.status {
            return true
        }
        return false
    }
    
    private func select(_ item: SidebarItem) {
        if appState.selectedSidebarItem != item {
            withAnimation(.easeInOut(duration: 0.12)) {
                appState.selectedSidebarItem = item
            }
        }
    }
    
    // MARK: - App Brand Header
    
    private var appBrandHeader: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(nsImage: .appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .shadow(color: Color.black.opacity(0.25), radius: 3, y: 1.5)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("MCons")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Icons for macOS")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("v\(updateService.currentVersion)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.07))
                .foregroundStyle(.secondary)
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Navigation Group Builder
    
    private func navigationGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.35))
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, 3)
            
            content()
        }
    }
    
    // MARK: - Footer
    
    private var sidebarFooter: some View {
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
                .fill(Color.black.opacity(0.25))
        )
    }
}

// MARK: - Isolated Fast Sidebar Row

private struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    var badge: String? = nil
    var hasUpdateBadge: Bool = false
    var shortcut: KeyEquivalent? = nil
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                // Leading accent glow indicator bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? AnyShapeStyle(AppTheme.Colors.accentGradient) : AnyShapeStyle(Color.clear))
                    .frame(width: 3, height: 16)
                
                // SF Symbol Icon
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                        ? AnyShapeStyle(AppTheme.Colors.accentGradient)
                        : AnyShapeStyle(Color.secondary)
                    )
                    .frame(width: 18)
                
                // Item Label
                Text(item.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : (isHovered ? .primary : .secondary))
                
                Spacer()
                
                // Pack count badge pill
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.06))
                        )
                }
                
                // Update indicator badge
                if hasUpdateBadge {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color(hex: "#00B894"))
                            .frame(width: 6, height: 6)
                        Text("NEW")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "#00B894"))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#00B894").opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(.vertical, 6)
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
            isHovered = hovering
        }
        .ifLet(shortcut) { view, sc in
            view.keyboardShortcut(sc, modifiers: .command)
        }
    }
}

// MARK: - View Extension Helper

private extension View {
    @ViewBuilder
    func ifLet<T, V: View>(_ value: T?, @ViewBuilder transform: (Self, T) -> V) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}
