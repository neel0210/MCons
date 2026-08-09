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
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search icons...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(AppTheme.Typography.body)
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .fill(AppTheme.Colors.cardBackground)
                    )
                    
                    // Icons grid
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100, maximum: 130), spacing: AppTheme.Spacing.lg)
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
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(icon.name)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.primary)
                    Text("Selected")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button("Apply to Folder") {
                if let icon = selectedIcon {
                    appState.selectedIcon = icon
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
                    .frame(width: 64, height: 64)
                    .shadow(
                        color: isSelected ? Color(hex: accentHex).opacity(0.4) : .clear,
                        radius: isSelected ? 8 : 0
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
                            ? Color(hex: accentHex).opacity(0.12)
                            : isHovered
                                ? AppTheme.Colors.cardBackground
                                : .clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .stroke(
                        isSelected ? Color(hex: accentHex).opacity(0.6) : .clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(isHovered && !isSelected ? 1.05 : 1.0)
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
