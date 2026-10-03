import SwiftUI

/// View displaying user's bookmarked favorite folder icons for quick access and application
struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedIcon: FolderIcon?
    @State private var hoveredIcon: FolderIcon?
    @State private var searchText = ""
    
    private var favoriteIcons: [FolderIcon] {
        let icons = appState.favoriteIcons()
        if searchText.isEmpty {
            return icons
        }
        return icons.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.packId.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(AppTheme.Spacing.xl)
                .background(.ultraThinMaterial)
            
            Divider()
            
            if appState.favoriteIconIds.isEmpty {
                emptyState
            } else {
                content
            }
            
            // Bottom action bar
            if let icon = selectedIcon {
                actionBar(for: icon)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(AppTheme.Colors.background)
        .animation(AppAnimations.smooth, value: selectedIcon)
        .animation(AppAnimations.smooth, value: appState.favoriteIconIds)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text("⭐")
                        .font(.system(size: 24))
                    Text("Favorite Icons")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(.primary)
                    
                    if !appState.favoriteIconIds.isEmpty {
                        Text("\(appState.favoriteIconIds.count)")
                            .font(AppTheme.Typography.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.yellow.opacity(0.2))
                            )
                            .foregroundStyle(Color.yellow)
                    }
                }
                
                Text("Your personal curated bookmarks for 1-click folder customization")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Content
    
    private var content: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                // Search bar
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search your favorites...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(AppTheme.Typography.body)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .fill(AppTheme.Colors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                )
                
                // Icons grid
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 110, maximum: 140), spacing: AppTheme.Spacing.lg)
                ], spacing: AppTheme.Spacing.lg) {
                    ForEach(favoriteIcons) { icon in
                        IconCell(
                            icon: icon,
                            isSelected: selectedIcon == icon,
                            isHovered: hoveredIcon == icon,
                            accentHex: "#FFD200"
                        ) {
                            withAnimation(AppAnimations.bouncy) {
                                selectedIcon = icon
                                appState.selectedIcon = icon
                            }
                        }
                        .onHover { hovering in
                            hoveredIcon = hovering ? icon : nil
                        }
                    }
                }
                
                Spacer(minLength: AppTheme.Spacing.xxxl)
            }
            .padding(AppTheme.Spacing.xl)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.12))
                    .frame(width: 96, height: 96)
                
                Image(systemName: "star.slash.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.yellow)
            }
            
            VStack(spacing: AppTheme.Spacing.xs) {
                Text("No Favorite Icons Yet")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.primary)
                
                Text("Star any icon while browsing packs to keep it bookmarked here.")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            
            Button {
                appState.selectedSidebarItem = .iconPacks
            } label: {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "square.grid.3x3.fill")
                    Text("Explore Icon Packs")
                }
                .font(AppTheme.Typography.headline)
                .foregroundColor(.white)
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .fill(AppTheme.Colors.accent)
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.Spacing.xxl)
    }
    
    // MARK: - Action Bar
    
    private func actionBar(for icon: FolderIcon) -> some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(nsImage: icon.previewImage())
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(icon.name)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.primary)
                    Text("Pack: \(icon.packId.capitalized)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                appState.toggleFavorite(icon: icon)
                if selectedIcon == icon {
                    selectedIcon = nil
                }
            } label: {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "star.slash")
                    Text("Unfavorite")
                }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                        .fill(AppTheme.Colors.cardBackground)
                )
            }
            .buttonStyle(.plain)
            
            Button("Apply to Folder") {
                appState.selectedIcon = icon
                if let pack = appState.cachedIconPacks.first(where: { $0.id == icon.packId }) {
                    appState.selectedIconPack = pack
                }
                appState.selectedSidebarItem = .applyIcon
            }
            .buttonStyle(PrimaryButtonStyle(accentHex: "#FFD200"))
        }
        .padding(AppTheme.Spacing.lg)
        .background(.ultraThickMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}
