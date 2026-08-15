import SwiftUI

/// Home dashboard with welcome message and quick actions
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var iconPacks: [IconPack] = []
    @State private var animateHero = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                // Hero Section
                heroSection
                    .fadeInUp()
                
                // Quick Actions
                quickActionsSection
                    .fadeInUp(delay: 0.1)
                
                // Featured Packs Preview
                featuredPacksSection
                    .fadeInUp(delay: 0.2)
                
                // Recent Folders
                if !appState.recentFolders.isEmpty {
                    recentFoldersSection
                        .fadeInUp(delay: 0.3)
                }
                
                Spacer(minLength: AppTheme.Spacing.xxl)
            }
            .padding(AppTheme.Spacing.xxl)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            iconPacks = appState.loadIconPacks()
            withAnimation(AppAnimations.gentle) {
                animateHero = true
            }
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Animated folder icon
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#6C5CE7").opacity(0.3), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(animateHero ? 1.1 : 0.8)
                    .opacity(animateHero ? 1 : 0)
                
                Image(systemName: "folder.fill.badge.gearshape")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(AppTheme.Colors.accentGradient)
                    .scaleEffect(animateHero ? 1.0 : 0.5)
                    .opacity(animateHero ? 1 : 0)
            }
            .animation(AppAnimations.bouncy, value: animateHero)
            
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("MCons")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(.primary)
                
                Text("Icons for MacOS")
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(AppTheme.Colors.accentGradient)
                
                Text("Customize your folders with stunning icon packs")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xl)
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text("Quick Actions")
                .font(AppTheme.Typography.title2)
                .foregroundStyle(.primary)
            
            HStack(spacing: AppTheme.Spacing.lg) {
                QuickActionCard(
                    icon: "folder.badge.plus",
                    title: "Create & Style",
                    subtitle: "New folder with icon",
                    gradient: LinearGradient(
                        colors: [Color(hex: "#6C5CE7"), Color(hex: "#A29BFE")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ) {
                    appState.selectedSidebarItem = .applyIcon
                }
                
                QuickActionCard(
                    icon: "square.grid.3x3.fill",
                    title: "Browse Packs",
                    subtitle: "\(iconPacks.count) packs available",
                    gradient: LinearGradient(
                        colors: [Color(hex: "#00B894"), Color(hex: "#55EFC4")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ) {
                    appState.selectedSidebarItem = .iconPacks
                }
                
                QuickActionCard(
                    icon: "photo.on.rectangle.angled",
                    title: "Custom Icon",
                    subtitle: "Use your own image",
                    gradient: LinearGradient(
                        colors: [Color(hex: "#E17055"), Color(hex: "#FDCB6E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ) {
                    appState.selectedSidebarItem = .applyIcon
                }
            }
        }
    }
    
    // MARK: - Featured Packs Preview
    
    private var featuredPacksSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack {
                Text("Icon Packs")
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button("View All") {
                    appState.selectedSidebarItem = .iconPacks
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(hex: "#6C5CE7"))
                .font(AppTheme.Typography.callout)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppTheme.Spacing.lg),
                GridItem(.flexible(), spacing: AppTheme.Spacing.lg),
                GridItem(.flexible(), spacing: AppTheme.Spacing.lg),
            ], spacing: AppTheme.Spacing.lg) {
                ForEach(Array(iconPacks.prefix(3))) { pack in
                    PackPreviewCard(pack: pack) {
                        appState.selectedIconPack = pack
                        appState.selectedSidebarItem = .iconPacks
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Folders
    
    private var recentFoldersSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text("Recent Folders")
                .font(AppTheme.Typography.title2)
                .foregroundStyle(.primary)
            
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(appState.recentFolders.prefix(5), id: \.self) { url in
                    RecentFolderRow(url: url) {
                        appState.targetFolderURL = url
                        appState.selectedSidebarItem = .applyIcon
                    }
                }
            }
        }
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: LinearGradient
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .fill(gradient)
                    )
                
                VStack(spacing: AppTheme.Spacing.xxs) {
                    Text(title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .fill(AppTheme.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .stroke(
                        isHovering ? Color(hex: "#6C5CE7").opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(isHovering ? 1.03 : 1.0)
            .cardShadow()
            .animation(AppAnimations.quick, value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Pack Preview Card

struct PackPreviewCard: View {
    let pack: IconPack
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                // Icon grid preview
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(pack.previewIcons.prefix(3)) { icon in
                        let nsImage = icon.previewImage()
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .fill(AppTheme.Colors.packGradient(hex: pack.accentColorHex))
                )
                
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    HStack {
                        Text(pack.emoji)
                        Text(pack.name)
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(.primary)
                    }
                    
                    Text("\(pack.iconCount) icons")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .fill(AppTheme.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .stroke(
                        isHovering ? Color(hex: pack.accentColorHex).opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(isHovering ? 1.03 : 1.0)
            .cardShadow()
            .animation(AppAnimations.quick, value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Recent Folder Row

struct RecentFolderRow: View {
    let url: URL
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(.primary)
                    
                    Text(url.deletingLastPathComponent().path)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .fill(isHovering ? AppTheme.Colors.cardBackground : .clear)
            )
            .animation(AppAnimations.fade, value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
