import SwiftUI

/// Browse and select from available icon packs
struct IconPacksView: View {
    @EnvironmentObject var appState: AppState
    @State private var iconPacks: [IconPack] = []
    @State private var selectedPack: IconPack?
    @State private var searchText = ""
    @State private var showPackDetail = false
    
    private var filteredPacks: [IconPack] {
        if searchText.isEmpty {
            return iconPacks
        }
        return iconPacks.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showPackDetail, let pack = selectedPack {
                IconPackDetailView(pack: pack, onBack: {
                    withAnimation(AppAnimations.smooth) {
                        showPackDetail = false
                        selectedPack = nil
                    }
                })
            } else {
                packsGrid
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            iconPacks = appState.loadIconPacks()
            // If a pack was pre-selected (from home), show it
            if let preselected = appState.selectedIconPack {
                selectedPack = preselected
                showPackDetail = true
                appState.selectedIconPack = nil
            }
        }
    }
    
    // MARK: - Packs Grid
    
    private var packsGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                // Header
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Icon Packs")
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(.primary)
                    
                    Text("Choose a pack and apply stunning icons to your folders")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(.secondary)
                }
                .fadeInUp()
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search packs...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(AppTheme.Typography.body)
                }
                .padding(AppTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .fill(AppTheme.Colors.cardBackground)
                )
                .fadeInUp(delay: 0.05)
                
                // Pack Cards Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: AppTheme.Spacing.lg),
                    GridItem(.flexible(), spacing: AppTheme.Spacing.lg),
                ], spacing: AppTheme.Spacing.lg) {
                    ForEach(Array(filteredPacks.enumerated()), id: \.element.id) { index, pack in
                        IconPackCard(pack: pack) {
                            withAnimation(AppAnimations.smooth) {
                                selectedPack = pack
                                showPackDetail = true
                            }
                        }
                        .fadeInUp(delay: Double(index) * 0.05 + 0.1)
                    }
                }
            }
            .padding(AppTheme.Spacing.xxl)
        }
    }
}

// MARK: - Icon Pack Card (Large)

struct IconPackCard: View {
    let pack: IconPack
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Preview area with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                        .fill(AppTheme.Colors.packGradient(hex: pack.accentColorHex))
                        .frame(height: 140)
                    
                    // Icon samples
                    HStack(spacing: AppTheme.Spacing.lg) {
                        ForEach(pack.previewIcons.prefix(4)) { icon in
                            let nsImage = icon.previewImage()
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 52, height: 52)
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        }
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: AppTheme.CornerRadius.lg,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: AppTheme.CornerRadius.lg
                    )
                )
                
                // Info area
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack {
                        Text(pack.emoji)
                            .font(.title2)
                        Text(pack.name)
                            .font(AppTheme.Typography.title2)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(pack.iconCount)")
                            .font(AppTheme.Typography.captionBold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.quaternary))
                    }
                    
                    Text(pack.description)
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(AppTheme.Spacing.lg)
            }
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .fill(AppTheme.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .stroke(
                        isHovering
                            ? Color(hex: pack.accentColorHex).opacity(0.6)
                            : Color(nsColor: .separatorColor).opacity(0.3),
                        lineWidth: isHovering ? 2 : 1
                    )
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .cardShadow()
            .animation(AppAnimations.quick, value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
