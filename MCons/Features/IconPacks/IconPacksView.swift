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
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.97)),
                    removal: .opacity
                ))
            } else {
                packsGrid
                    .transition(.opacity)
            }
        }
        .background(AppTheme.Colors.background)
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
                
                // Search
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search packs...", text: $searchText)
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
                
                // Pack Cards Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: AppTheme.Spacing.lg),
                    GridItem(.flexible(), spacing: AppTheme.Spacing.lg),
                ], spacing: AppTheme.Spacing.lg) {
                    ForEach(filteredPacks) { pack in
                        IconPackCard(pack: pack) {
                            withAnimation(AppAnimations.smooth) {
                                selectedPack = pack
                                showPackDetail = true
                            }
                        }
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
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Preview area with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                        .fill(AppTheme.Colors.packGradient(hex: pack.accentColorHex))
                        .frame(height: 150)
                    
                    // Icon samples filling 90% of banner space
                    HStack(spacing: AppTheme.Spacing.md) {
                        ForEach(pack.previewIcons.prefix(4)) { icon in
                            let nsImage = icon.thumbnailImage(size: 128)
                            Image(nsImage: nsImage)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .frame(height: 108)
                                .shadow(color: .black.opacity(0.28), radius: 6, y: 3)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
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
            .cardLift(accentHex: pack.accentColorHex)
        }
        .buttonStyle(.plain)
    }
}
