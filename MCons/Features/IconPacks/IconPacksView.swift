import SwiftUI

/// Browse and select from available icon packs with global search and category filtering
struct IconPacksView: View {
    @EnvironmentObject var appState: AppState
    @State private var iconPacks: [IconPack] = []
    @State private var selectedPack: IconPack?
    @State private var searchText = ""
    @State private var showPackDetail = false
    @State private var selectedCategory: String = "All"
    @State private var searchScope: SearchScope = .packs
    @State private var packToDelete: IconPack?
    @State private var showDeleteConfirmation = false
    
    enum SearchScope: String, CaseIterable, Identifiable {
        case packs = "Packs"
        case allIcons = "All Icons"
        var id: String { rawValue }
    }
    
    private let categories = ["All", "Anime", "Dev & Tech", "Apps", "System", "Custom"]
    
    private var filteredPacks: [IconPack] {
        var packs = iconPacks
        if selectedCategory != "All" {
            packs = packs.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            packs = packs.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.icons.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) })
            }
        }
        return packs
    }
    
    private var globalMatchingIcons: [FolderIcon] {
        guard !searchText.isEmpty else {
            return iconPacks.flatMap { $0.icons }
        }
        return iconPacks.flatMap { $0.icons }.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.packId.localizedCaseInsensitiveContains(searchText)
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
            if let preselected = appState.selectedIconPack {
                selectedPack = preselected
                showPackDetail = true
                appState.selectedIconPack = nil
            }
        }
        .confirmationDialog(
            "Delete Custom Pack",
            isPresented: $showDeleteConfirmation,
            presenting: packToDelete
        ) { pack in
            Button("Delete '\(pack.name)'", role: .destructive) {
                _ = appState.deleteCustomPack(pack)
                iconPacks = appState.loadIconPacks()
            }
            Button("Cancel", role: .cancel) { }
        } message: { pack in
            Text("Are you sure you want to delete this custom pack? The files in Application Support will be removed.")
        }
    }
    
    // MARK: - Packs Grid & Global Search
    
    private var packsGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                // Header
                header
                
                // Search bar & Scopes
                searchSection
                
                // Category Filter Chips (shown when in Packs scope)
                if searchScope == .packs {
                    categoryFilterRow
                }
                
                // Content View based on scope
                if searchScope == .allIcons || (!searchText.isEmpty && searchScope == .allIcons) {
                    allIconsGrid
                } else {
                    packsCardsGrid
                }
            }
            .padding(AppTheme.Spacing.xxl)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Icon Packs")
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(.primary)
                    
                    Text("Choose a pack or search across \(iconPacks.flatMap { $0.icons }.count)+ vector desktop icons")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    appState.selectedSidebarItem = .packBuilder
                } label: {
                    Label("Create Pack", systemImage: "plus.square.fill")
                        .font(AppTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField(searchScope == .packs ? "Search packs or characters..." : "Search all individual icons (e.g. Gojo, Python, Chrome)...", text: $searchText)
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
                
                Divider()
                    .frame(height: 18)
                
                // Scope picker
                Picker("Scope", selection: $searchScope) {
                    ForEach(SearchScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
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
        }
    }
    
    // MARK: - Category Filter Chips
    
    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(categories, id: \.self) { cat in
                    Button {
                        selectedCategory = cat
                    } label: {
                        Text(cat)
                            .font(AppTheme.Typography.caption)
                            .fontWeight(selectedCategory == cat ? .bold : .medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == cat ? Color.accentColor : AppTheme.Colors.surface)
                            )
                            .foregroundStyle(selectedCategory == cat ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Packs Cards Grid
    
    private var packsCardsGrid: some View {
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
                .contextMenu {
                    if pack.isCustom {
                        Button(role: .destructive) {
                            packToDelete = pack
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Pack", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - All Icons Grid (Global Search Results)
    
    private var allIconsGrid: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Matching Icons (\(globalMatchingIcons.count))")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 110, maximum: 140), spacing: AppTheme.Spacing.lg)
            ], spacing: AppTheme.Spacing.lg) {
                ForEach(globalMatchingIcons) { icon in
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                .fill(AppTheme.Colors.cardBackground)
                                .frame(height: 100)
                                .overlay(
                                    Image(nsImage: icon.previewImage())
                                        .resizable()
                                        .interpolation(.high)
                                        .aspectRatio(contentMode: .fit)
                                        .padding(10)
                                )
                        }
                        
                        Text(icon.name)
                            .font(AppTheme.Typography.captionBold)
                            .lineLimit(1)
                        
                        Text(icon.packId)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .fill(AppTheme.Colors.surface)
                    )
                    .contextMenu {
                        Button {
                            appState.selectedIcon = icon
                            appState.selectedSidebarItem = .applyIcon
                        } label: {
                            Label("Apply to Folder", systemImage: "folder.badge.plus")
                        }
                        
                        Button {
                            appState.toggleFavorite(icon: icon)
                        } label: {
                            Label(
                                appState.isFavorite(icon: icon) ? "Remove Favorite" : "Add to Favorites",
                                systemImage: appState.isFavorite(icon: icon) ? "star.slash" : "star.fill"
                            )
                        }
                        
                        Divider()
                        
                        Button {
                            IconExportService.shared.export(icon: icon, format: .png)
                        } label: {
                            Label("Export PNG (1024×1024)...", systemImage: "photo")
                        }
                        
                        Button {
                            IconExportService.shared.export(icon: icon, format: .icns)
                        } label: {
                            Label("Export macOS Icon (.icns)...", systemImage: "app.badge")
                        }
                        
                        Button {
                            IconExportService.shared.export(icon: icon, format: .svg)
                        } label: {
                            Label("Export Original Vector (.svg)...", systemImage: "square.and.arrow.up")
                        }
                    }
                    .onTapGesture {
                        appState.selectedIcon = icon
                        appState.selectedSidebarItem = .applyIcon
                    }
                }
            }
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
                        if pack.isCustom {
                            Text("USER")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.purple.opacity(0.2)))
                                .foregroundStyle(Color.purple)
                        }
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
