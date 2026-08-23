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
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .stroke(AppTheme.Colors.border, lineWidth: 1)
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
        .background(AppTheme.Colors.background)
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
                let nsImage = icon.thumbnailImage(size: 76)
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
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
                let nsImage = icon.thumbnailImage()
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 76, height: 76)
                    .scaleEffect(isHovered ? 1.06 : 1.0)
                    .shadow(
                        color: isSelected
                            ? Color(hex: accentHex).opacity(0.5)
                            : (isHovered ? Color(hex: accentHex).opacity(0.3) : Color.black.opacity(0.2)),
                        radius: isSelected ? 8 : (isHovered ? 6 : 3),
                        y: isSelected ? 4 : 2
                    )
                    .animation(AppAnimations.quick, value: isHovered)
                
                Text(icon.name)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(isSelected ? .primary : (isHovered ? .primary : .secondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .fill(
                        isSelected
                            ? Color(hex: accentHex).opacity(0.18)
                            : (isHovered ? AppTheme.Colors.cardElevated : AppTheme.Colors.cardBackground.opacity(0.6))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .stroke(
                        isSelected
                            ? Color(hex: accentHex).opacity(0.85)
                            : (isHovered ? Color(hex: accentHex).opacity(0.4) : AppTheme.Colors.border),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
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
