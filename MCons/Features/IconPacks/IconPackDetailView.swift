import SwiftUI

/// Detail view showing all icons in a pack with selection
struct IconPackDetailView: View {
    let pack: IconPack
    let onBack: () -> Void
    
    @EnvironmentObject var appState: AppState
    @State private var selectedIcon: FolderIcon?
    @State private var hoveredIcon: FolderIcon?
    @State private var searchText = ""
    
    private var filteredIcons: [FolderIcon] {
        if searchText.isEmpty {
            return pack.icons
        }
        return pack.icons.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            header
                .padding(AppTheme.Spacing.xl)
                .background(.ultraThinMaterial)
            
            Divider()
            
            // Icon Grid
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {
                    // Search bar
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search icons in \(pack.name)...", text: $searchText)
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
                    
                    // Icons grid
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 110, maximum: 140), spacing: AppTheme.Spacing.lg)
                    ], spacing: AppTheme.Spacing.lg) {
                        ForEach(filteredIcons) { icon in
                            IconCell(
                                icon: icon,
                                isSelected: selectedIcon == icon,
                                isHovered: hoveredIcon == icon,
                                accentHex: pack.accentColorHex
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
                    .drawingGroup()
                    
                    Spacer(minLength: AppTheme.Spacing.xxxl)
                }
                .padding(AppTheme.Spacing.xl)
            }
            
            // Bottom action bar
            if selectedIcon != nil {
                actionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(AppAnimations.smooth, value: selectedIcon)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            Button(action: onBack) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Packs")
                        .font(AppTheme.Typography.body)
                }
                .foregroundStyle(Color(hex: pack.accentColorHex))
            }
            .buttonStyle(.plain)
            .hoverScale(1.05)
            
            Divider()
                .frame(height: 20)
            
            Text(pack.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(pack.name)
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(.primary)
                
                Text(pack.description)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("\(pack.iconCount) icons")
                .font(AppTheme.Typography.captionBold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.quaternary))
        }
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            if let icon = selectedIcon {
                let nsImage = icon.previewImage()
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .shadow(color: Color(hex: pack.accentColorHex).opacity(0.4), radius: 6, y: 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(icon.name)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.primary)
                    Text("Selected Icon")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color(hex: pack.accentColorHex))
                }
            }
            
            Spacer()
            
            Button("Apply to Folder") {
                if let icon = selectedIcon {
                    appState.selectedIcon = icon
                    appState.selectedIconPack = pack
                    appState.selectedSidebarItem = .applyIcon
                }
            }
            .buttonStyle(PrimaryButtonStyle(accentHex: pack.accentColorHex))
        }
        .padding(AppTheme.Spacing.lg)
        .background(.ultraThickMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - Icon Cell

struct IconCell: View {
    let icon: FolderIcon
    let isSelected: Bool
    let isHovered: Bool
    let accentHex: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.sm) {
                let nsImage = icon.previewImage()
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 76, height: 76)
                    .shadow(
                        color: isSelected ? Color(hex: accentHex).opacity(0.45) : (isHovered ? .black.opacity(0.25) : .black.opacity(0.12)),
                        radius: isSelected ? 8 : (isHovered ? 6 : 3),
                        y: isSelected ? 4 : 2
                    )
                
                Text(icon.name)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .fill(
                        isSelected
                            ? Color(hex: accentHex).opacity(0.15)
                            : isHovered
                                ? AppTheme.Colors.cardBackground
                                : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .stroke(
                        isSelected
                            ? Color(hex: accentHex).opacity(0.8)
                            : isHovered
                                ? Color(hex: accentHex).opacity(0.3)
                                : Color.clear,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isHovered && !isSelected ? 1.04 : 1.0)
            .animation(AppAnimations.quick, value: isHovered)
            .animation(AppAnimations.bouncy, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    let accentHex: String
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .fill(Color(hex: accentHex))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(AppAnimations.quick, value: configuration.isPressed)
    }
}
