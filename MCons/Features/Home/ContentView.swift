import SwiftUI

/// Main content view with NavigationSplitView sidebar
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
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
            case .settings:
                SettingsView()
            }
        }
        .animation(AppAnimations.quick, value: appState.selectedSidebarItem)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var hoveredItem: SidebarItem?
    
    var body: some View {
        List(SidebarItem.allCases, selection: $appState.selectedSidebarItem) { item in
            sidebarRow(item)
                .tag(item)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            // App branding header
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "folder.fill.badge.gearshape")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.Colors.accentGradient)
                
                Text("MCons")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.primary)
                
                Text("Icons for MacOS")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.sm)
        }
        .safeAreaInset(edge: .bottom) {
            // Status bar
            if !appState.statusMessage.isEmpty {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: appState.showSuccessAnimation ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundColor(appState.showSuccessAnimation ? AppTheme.Colors.success : .secondary)
                        .font(.caption)
                    
                    Text(appState.statusMessage)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(AppAnimations.smooth, value: appState.statusMessage)
    }
    
    private func sidebarRow(_ item: SidebarItem) -> some View {
        Label {
            Text(item.rawValue)
                .font(AppTheme.Typography.body)
        } icon: {
            Image(systemName: item.icon)
                .foregroundStyle(
                    appState.selectedSidebarItem == item
                    ? AnyShapeStyle(AppTheme.Colors.accentGradient)
                    : AnyShapeStyle(.secondary)
                )
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
    }
}
