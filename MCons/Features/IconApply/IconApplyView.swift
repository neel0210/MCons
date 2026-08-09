import SwiftUI
import UniformTypeIdentifiers

/// The main workflow view for applying icons to folders
struct IconApplyView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.undoManager) var undoManager
    @State private var targetFolderURL: URL?
    @State private var customFolderName: String = ""
    @State private var selectedIcon: FolderIcon?
    @State private var customImageURL: URL?
    @State private var showFolderPicker = false
    @State private var showImagePicker = false
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var createFolderParentURL: URL?
    @State private var showSuccess = false
    @State private var isApplying = false
    @State private var isDragTargeted = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                // Header
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Apply Icon")
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(.primary)
                    
                    Text("Select an icon and a target folder, option to rename folder, then apply")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fadeInUp()
                
                // Two-column layout
                HStack(alignment: .top, spacing: AppTheme.Spacing.xxl) {
                    // Left: Icon selection
                    iconSelectionPanel
                        .fadeInUp(delay: 0.1)
                    
                    // Right: Folder selection + preview
                    VStack(spacing: AppTheme.Spacing.xl) {
                        folderSelectionPanel
                            .fadeInUp(delay: 0.15)
                        
                        previewPanel
                            .fadeInUp(delay: 0.2)
                    }
                }
                
                Spacer(minLength: AppTheme.Spacing.xxl)
            }
            .padding(AppTheme.Spacing.xxl)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // Pick up pre-selected values from app state
            if let icon = appState.selectedIcon {
                selectedIcon = icon
            }
            if let url = appState.targetFolderURL {
                targetFolderURL = url
                customFolderName = url.lastPathComponent
            }
        }
        .onChange(of: appState.selectedIcon) { _, newIcon in
            if let icon = newIcon {
                selectedIcon = icon
            }
        }
        .sheet(isPresented: $showCreateFolder) {
            createFolderSheet
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }
    
    // MARK: - Icon Selection Panel
    
    private var iconSelectionPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text("Selected Icon")
                .font(AppTheme.Typography.title2)
                .foregroundStyle(.primary)
            
            VStack(spacing: AppTheme.Spacing.lg) {
                // Current selection
                if let icon = selectedIcon {
                    VStack(spacing: AppTheme.Spacing.md) {
                        let nsImage = icon.previewImage()
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: AppTheme.IconSize.hero, height: AppTheme.IconSize.hero)
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        
                        Text(icon.name)
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(.primary)
                        
                        Text("From: \(icon.packId.replacingOccurrences(of: "-", with: " ").capitalized)")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(AppTheme.Spacing.xl)
                } else {
                    VStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(.quaternary)
                        
                        Text("No icon selected")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(.secondary)
                        
                        Text("Choose from Icon Packs or import your own")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(AppTheme.Spacing.xxl)
                }
                
                Divider()
                
                // Actions
                VStack(spacing: AppTheme.Spacing.sm) {
                    Button {
                        appState.selectedSidebarItem = .iconPacks
                    } label: {
                        Label("Browse Icon Packs", systemImage: "square.grid.3x3.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(AppTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                            .fill(AppTheme.Colors.cardBackground.opacity(0.5))
                    )
                    
                    Button {
                        showImagePicker = true
                    } label: {
                        Label("Import Custom Image", systemImage: "photo.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(AppTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                            .fill(AppTheme.Colors.cardBackground.opacity(0.5))
                    )
                    .fileImporter(
                        isPresented: $showImagePicker,
                        allowedContentTypes: [.png, .jpeg, .icns, .tiff],
                        allowsMultipleSelection: false
                    ) { result in
                        if case .success(let urls) = result, let url = urls.first {
                            _ = url.startAccessingSecurityScopedResource()
                            if NSImage(contentsOf: url) != nil {
                                let customIcon = FolderIcon(
                                    id: "custom_\(UUID().uuidString)",
                                    name: url.deletingPathExtension().lastPathComponent,
                                    packId: "custom",
                                    fileURL: url
                                )
                                withAnimation(AppAnimations.bouncy) {
                                    selectedIcon = customIcon
                                    appState.selectedIcon = customIcon
                                }
                            }
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.lg)
            }
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .fill(AppTheme.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
            )
            .cardShadow()
        }
        .frame(minWidth: 280, maxWidth: 320)
    }
    
    // MARK: - Folder Selection Panel
    
    private var folderSelectionPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text("Target Folder")
                .font(AppTheme.Typography.title2)
                .foregroundStyle(.primary)
            
            VStack(spacing: AppTheme.Spacing.lg) {
                // Drop zone
                VStack(spacing: AppTheme.Spacing.md) {
                    if let url = targetFolderURL {
                        VStack(spacing: AppTheme.Spacing.md) {
                            HStack(spacing: AppTheme.Spacing.md) {
                                let folderIcon = NSWorkspace.shared.icon(forFile: url.path)
                                Image(nsImage: folderIcon)
                                    .resizable()
                                    .frame(width: 48, height: 48)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(url.lastPathComponent)
                                        .font(AppTheme.Typography.headline)
                                        .foregroundStyle(.primary)
                                    
                                    Text(url.deletingLastPathComponent().path)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                
                                Spacer()
                                
                                Button {
                                    targetFolderURL = nil
                                    appState.targetFolderURL = nil
                                    customFolderName = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Divider()
                            
                            // Rename folder option
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                HStack {
                                    Text("Folder Name")
                                        .font(AppTheme.Typography.captionBold)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    if customFolderName != url.lastPathComponent {
                                        Button("Keep Original Name") {
                                            customFolderName = url.lastPathComponent
                                        }
                                        .buttonStyle(.plain)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(Color(hex: "#6C5CE7"))
                                    }
                                    
                                    if let icon = selectedIcon, customFolderName != icon.name {
                                        Button("Use Icon Name") {
                                            customFolderName = icon.name
                                        }
                                        .buttonStyle(.plain)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(Color(hex: "#00B894"))
                                    }
                                }
                                
                                HStack {
                                    Image(systemName: "pencil")
                                        .foregroundStyle(.secondary)
                                    
                                    TextField("Enter folder name", text: $customFolderName)
                                        .textFieldStyle(.plain)
                                        .font(AppTheme.Typography.body)
                                }
                                .padding(AppTheme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                        .fill(AppTheme.Colors.cardBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                        .stroke(
                                            customFolderName != url.lastPathComponent
                                                ? Color(hex: "#6C5CE7").opacity(0.8)
                                                : Color(nsColor: .separatorColor).opacity(0.3),
                                            lineWidth: customFolderName != url.lastPathComponent ? 1.5 : 1
                                        )
                                )
                                
                                if customFolderName != url.lastPathComponent && !customFolderName.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.caption)
                                        Text("Folder will be renamed from '\(url.lastPathComponent)' to '\(customFolderName)' upon applying")
                                            .font(AppTheme.Typography.caption)
                                    }
                                    .foregroundStyle(Color(hex: "#6C5CE7"))
                                    .padding(.horizontal, AppTheme.Spacing.xs)
                                }
                            }
                        }
                        .padding(AppTheme.Spacing.lg)
                    } else {
                        VStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(.quaternary)
                            
                            Text("Drop a folder here")
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(.secondary)
                            
                            Text("or use the buttons below")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(AppTheme.Spacing.xxl)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .strokeBorder(
                            isDragTargeted
                                ? Color(hex: "#6C5CE7")
                                : Color(nsColor: .separatorColor).opacity(0.3),
                            style: StrokeStyle(lineWidth: isDragTargeted ? 2 : 1, dash: [8, 4])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                .fill(isDragTargeted ? Color(hex: "#6C5CE7").opacity(0.05) : .clear)
                        )
                )
                .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
                    handleDrop(providers)
                }
                .animation(AppAnimations.quick, value: isDragTargeted)
                
                // Folder action buttons
                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        panel.message = "Select a folder to apply the icon to"
                        panel.prompt = "Select Folder"
                        
                        if panel.runModal() == .OK, let url = panel.url {
                            withAnimation(AppAnimations.smooth) {
                                targetFolderURL = url
                                appState.targetFolderURL = url
                                customFolderName = url.lastPathComponent
                            }
                        }
                    } label: {
                        Label("Choose Folder", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        // Show create folder sheet
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        panel.message = "Select where to create the new folder"
                        panel.prompt = "Select Location"
                        
                        if panel.runModal() == .OK, let url = panel.url {
                            createFolderParentURL = url
                            showCreateFolder = true
                        }
                    } label: {
                        Label("Create New", systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.lg)
            }
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .fill(AppTheme.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
            )
            .cardShadow()
        }
    }
    
    // MARK: - Preview Panel
    
    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text("Preview & Apply")
                .font(AppTheme.Typography.title2)
                .foregroundStyle(.primary)
            
            VStack(spacing: AppTheme.Spacing.xl) {
                // Before / After preview
                HStack(spacing: AppTheme.Spacing.xxl) {
                    // Before
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text("BEFORE")
                            .font(AppTheme.Typography.captionBold)
                            .foregroundStyle(.secondary)
                        
                        if let url = targetFolderURL {
                            let currentIcon = NSWorkspace.shared.icon(forFile: url.path)
                            Image(nsImage: currentIcon)
                                .resizable()
                                .frame(width: AppTheme.IconSize.preview, height: AppTheme.IconSize.preview)
                        } else {
                            let defaultIcon = NSWorkspace.shared.icon(for: .folder)
                            Image(nsImage: defaultIcon)
                                .resizable()
                                .frame(width: AppTheme.IconSize.preview, height: AppTheme.IconSize.preview)
                                .opacity(0.3)
                        }
                        
                        Text(targetFolderURL?.lastPathComponent ?? "No folder")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(AppTheme.Colors.accentGradient)
                    
                    // After
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text("AFTER")
                            .font(AppTheme.Typography.captionBold)
                            .foregroundStyle(.secondary)
                        
                        if let icon = selectedIcon {
                            let nsImage = icon.previewImage()
                            Image(nsImage: nsImage)
                                .resizable()
                                .frame(width: AppTheme.IconSize.preview, height: AppTheme.IconSize.preview)
                        } else {
                            Image(systemName: "questionmark.folder.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.quaternary)
                                .frame(width: AppTheme.IconSize.preview, height: AppTheme.IconSize.preview)
                        }
                        
                        Text(selectedIcon?.name ?? "No icon")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.xl)
                
                Divider()
                
                // Action buttons
                HStack(spacing: AppTheme.Spacing.md) {
                    // Reset button
                    if let url = targetFolderURL, appState.iconService.hasCustomIcon(for: url) {
                        Button {
                            _ = appState.resetIcon(for: url)
                        } label: {
                            Label("Reset to Default", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    // Apply button
                    Button {
                        applyIcon()
                    } label: {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            if isApplying {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            }
                            Text(isApplying ? "Applying..." : "Apply Icon")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(accentHex: "#6C5CE7"))
                    .disabled(selectedIcon == nil || targetFolderURL == nil || isApplying)
                    .opacity(selectedIcon != nil && targetFolderURL != nil ? 1 : 0.5)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.lg)
            }
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .fill(AppTheme.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
            )
            .cardShadow()
        }
    }
    
    // MARK: - Create Folder Sheet
    
    private var createFolderSheet: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Text("Create New Folder")
                .font(AppTheme.Typography.title)
            
            TextField("Folder name", text: $newFolderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            if let parentURL = createFolderParentURL {
                Text("Location: \(parentURL.path)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            HStack(spacing: AppTheme.Spacing.md) {
                Button("Cancel") {
                    showCreateFolder = false
                    newFolderName = ""
                }
                .buttonStyle(.bordered)
                
                Button("Create") {
                    if let parentURL = createFolderParentURL, !newFolderName.isEmpty {
                        if let newURL = appState.folderService.createFolder(named: newFolderName, at: parentURL) {
                            withAnimation(AppAnimations.smooth) {
                                targetFolderURL = newURL
                                appState.targetFolderURL = newURL
                                customFolderName = newURL.lastPathComponent
                            }
                        }
                    }
                    showCreateFolder = false
                    newFolderName = ""
                }
                .buttonStyle(PrimaryButtonStyle(accentHex: "#6C5CE7"))
                .disabled(newFolderName.isEmpty)
            }
        }
        .padding(AppTheme.Spacing.xxl)
        .frame(width: 400)
    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showSuccess = false
                    }
                }
            
            VStack(spacing: AppTheme.Spacing.xl) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.Colors.success)
                    .symbolEffect(.bounce, value: showSuccess)
                
                Text("Icon Applied!")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(.white)
                
                Text("Your folder now has a custom icon")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(.white.opacity(0.8))
                
                Button("Done") {
                    withAnimation {
                        showSuccess = false
                    }
                }
                .buttonStyle(PrimaryButtonStyle(accentHex: "#00B894"))
            }
            .padding(AppTheme.Spacing.xxxl)
            .glassMorphism(cornerRadius: AppTheme.CornerRadius.xxl)
            .scaleEffect(showSuccess ? 1 : 0.8)
            .animation(AppAnimations.success, value: showSuccess)
        }
    }
    
    // MARK: - Actions
    
    private func applyIcon() {
        guard let icon = selectedIcon, let folderURL = targetFolderURL else { return }
        
        isApplying = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let success = appState.applyAtomicOperation(
                icon: icon,
                targetFolder: folderURL,
                desiredName: customFolderName,
                undoManager: undoManager
            )
            isApplying = false
            
            if success {
                if let updatedURL = appState.targetFolderURL {
                    targetFolderURL = updatedURL
                    customFolderName = updatedURL.lastPathComponent
                }
                
                withAnimation(AppAnimations.success) {
                    showSuccess = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        showSuccess = false
                    }
                }
            }
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil),
               url.isDirectory {
                DispatchQueue.main.async {
                    withAnimation(AppAnimations.smooth) {
                        targetFolderURL = url
                        appState.targetFolderURL = url
                        customFolderName = url.lastPathComponent
                    }
                }
            }
        }
        return true
    }
}
