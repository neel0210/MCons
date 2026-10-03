import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// In-App Custom Pack Builder: Allows users to create custom icon packs without touching code
struct PackBuilderView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var packName: String = ""
    @State private var packDescription: String = ""
    @State private var selectedEmoji: String = "📁"
    @State private var accentColor: Color = Color(hex: "#6C5CE7")
    @State private var addedIconURLs: [URL] = []
    
    @State private var isDragTargeted: Bool = false
    @State private var isCreating: Bool = false
    @State private var statusMessage: String?
    @State private var showSuccessAlert: Bool = false
    @State private var errorMessage: String?
    
    private let emojiPresets = ["📁", "🚀", "💻", "🎨", "⚡", "🎮", "🦄", "🌟", "👾", "🛠️", "📦", "🏷️", "🔥", "🔮", "✨"]
    
    private var packSlug: String {
        let trimmed = packName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
                // Header
                header
                
                // Form Cards
                VStack(spacing: AppTheme.Spacing.xl) {
                    packMetadataCard
                    iconsCard
                }
                
                // Create Pack Button
                createActionCard
                
                Spacer(minLength: AppTheme.Spacing.xxxl)
            }
            .padding(AppTheme.Spacing.xxl)
        }
        .background(AppTheme.Colors.background)
        .alert("Pack Created!", isPresented: $showSuccessAlert) {
            Button("View in Icon Packs") {
                appState.selectedSidebarItem = .iconPacks
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your custom icon pack '\(packName)' was installed to Application Support and is ready to use.")
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Text("🛠️")
                    .font(.system(size: 26))
                Text("Pack Builder")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(.primary)
                
                Text("NEW")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.purple.opacity(0.2))
                    )
                    .foregroundStyle(Color.purple)
            }
            
            Text("Create, package, and install custom folder icon collections into MCons")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Metadata Card
    
    private var packMetadataCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack {
                Text("Pack Information")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("Slug: \(packSlug.isEmpty ? "custom-pack" : packSlug)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AppTheme.Colors.surface))
            }
            
            Divider()
            
            // Name Field
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Pack Name")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                
                TextField("e.g. My Minimalist Workspace", text: $packName)
                    .textFieldStyle(.plain)
                    .font(AppTheme.Typography.body)
                    .padding(AppTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .fill(AppTheme.Colors.surface)
                    )
            }
            
            // Description Field
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Description")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                
                TextField("e.g. Curated vector icons for developer workspaces", text: $packDescription)
                    .textFieldStyle(.plain)
                    .font(AppTheme.Typography.body)
                    .padding(AppTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .fill(AppTheme.Colors.surface)
                    )
            }
            
            // Emoji & Accent Color Row
            HStack(spacing: AppTheme.Spacing.xl) {
                // Emoji Picker
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Pack Emoji")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 6) {
                        ForEach(emojiPresets.prefix(8), id: \.self) { emoji in
                            Button {
                                selectedEmoji = emoji
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 18))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedEmoji == emoji ? accentColor.opacity(0.25) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedEmoji == emoji ? accentColor : Color.clear, lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
                
                // Accent Color
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Accent Color")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                    
                    ColorPicker("Choose Accent", selection: $accentColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(height: 32)
                }
            }
        }
        .padding(AppTheme.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                .fill(AppTheme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Icons Drop & List Card
    
    private var iconsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pack Icons (\(addedIconURLs.count))")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.primary)
                    Text("Supports SVG, PNG, ICNS, JPG, and TIFF (1024×1024 recommended)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    selectFiles()
                } label: {
                    Label("Add Images...", systemImage: "photo.badge.plus")
                        .font(AppTheme.Typography.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(accentColor.opacity(0.15)))
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Drag and Drop Zone
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .strokeBorder(
                        isDragTargeted ? accentColor : AppTheme.Colors.border,
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .fill(isDragTargeted ? accentColor.opacity(0.08) : AppTheme.Colors.surface)
                    )
                
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "square.and.arrow.down.on.square.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(isDragTargeted ? accentColor : .secondary)
                    
                    Text("Drop Icon Files Here")
                        .font(AppTheme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text("Drop .svg vector or transparent .png files")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(AppTheme.Spacing.lg)
            }
            .frame(height: 120)
            .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
                handleDroppedFiles(providers: providers)
                return true
            }
            
            // Icon List Grid
            if !addedIconURLs.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)], spacing: 12) {
                    ForEach(addedIconURLs, id: \.self) { url in
                        iconPreviewCell(for: url)
                    }
                }
            }
        }
        .padding(AppTheme.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                .fill(AppTheme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Icon Preview Cell
    
    private func iconPreviewCell(for url: URL) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                    .fill(AppTheme.Colors.surface)
                    .frame(height: 72)
                    .overlay(
                        Group {
                            if let img = NSImage(contentsOf: url) {
                                Image(nsImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(8)
                            } else {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    )
                
                Button {
                    addedIconURLs.removeAll { $0 == url }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
                .padding(4)
            }
            
            Text(url.deletingPathExtension().lastPathComponent)
                .font(AppTheme.Typography.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Create Action Card
    
    private var createActionCard: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            if let err = errorMessage {
                Text(err)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.red)
            }
            
            Button {
                buildAndInstallPack()
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    if isCreating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                    }
                    
                    Text(isCreating ? "Building Pack..." : "Create & Install Pack")
                        .fontWeight(.semibold)
                }
                .font(AppTheme.Typography.body)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .fill(isValidForm ? accentColor : Color.gray.opacity(0.4))
                )
            }
            .buttonStyle(.plain)
            .disabled(!isValidForm || isCreating)
        }
    }
    
    private var isValidForm: Bool {
        !packName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !addedIconURLs.isEmpty &&
        !packSlug.isEmpty
    }
    
    // MARK: - Actions
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.svg, .png, .jpeg, .icns, .tiff]
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                if !addedIconURLs.contains(url) {
                    addedIconURLs.append(url)
                }
            }
        }
    }
    
    private func handleDroppedFiles(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                let ext = url.pathExtension.lowercased()
                if ["svg", "png", "jpg", "jpeg", "icns", "tiff"].contains(ext) {
                    DispatchQueue.main.async {
                        if !addedIconURLs.contains(url) {
                            addedIconURLs.append(url)
                        }
                    }
                }
            }
        }
    }
    
    private func buildAndInstallPack() {
        guard isValidForm else { return }
        isCreating = true
        errorMessage = nil
        
        let targetSlug = packSlug
        let customPacksDir = IconPackLoader.customPacksDirectory
        let packDir = customPacksDir.appendingPathComponent(targetSlug)
        
        do {
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: packDir, withIntermediateDirectories: true)
            
            // 1. Convert accent color to Hex
            let hexColor = accentColor.toHex() ?? "#6C5CE7"
            
            // 2. Write metadata.json
            let metadata = IconPackMetadata(
                id: targetSlug,
                name: packName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: packDescription.isEmpty ? "Custom folder icon pack" : packDescription,
                emoji: selectedEmoji,
                accentColorHex: hexColor
            )
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let metaData = try encoder.encode(metadata)
            try metaData.write(to: packDir.appendingPathComponent("metadata.json"))
            
            // 3. Copy image files
            for sourceURL in addedIconURLs {
                let destURL = packDir.appendingPathComponent(sourceURL.lastPathComponent)
                if fileManager.fileExists(atPath: destURL.path) {
                    try? fileManager.removeItem(at: destURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destURL)
            }
            
            // 4. Refresh AppState packs
            appState.refreshIconPacks()
            
            isCreating = false
            showSuccessAlert = true
        } catch {
            isCreating = false
            errorMessage = "Failed to create pack: \(error.localizedDescription)"
        }
    }
}

// MARK: - Color Hex Extension

private extension Color {
    func toHex() -> String? {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
