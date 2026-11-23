import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Batch Folder Apply: Applies custom icons to multiple folders simultaneously
struct BatchApplyView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.undoManager) var undoManager
    
    @State private var targetFolders: [URL] = []
    @State private var selectedIcon: FolderIcon?
    @State private var enableTint: Bool = false
    @State private var tintColor: Color = Color(hex: "#007AFF")
    @State private var showIconPickerSheet: Bool = false
    @State private var isDragTargeted: Bool = false
    @State private var iconSearchText: String = ""
    @State private var selectedPackFilter: String = "All"
    
    private let tintPresets: [(Color, String)] = [
        (Color(hex: "#007AFF"), "Blue"),
        (Color(hex: "#5856D6"), "Indigo"),
        (Color(hex: "#AF52DE"), "Purple"),
        (Color(hex: "#FF2D55"), "Pink"),
        (Color(hex: "#FF3B30"), "Red"),
        (Color(hex: "#FF9500"), "Orange"),
        (Color(hex: "#FFCC00"), "Yellow"),
        (Color(hex: "#34C759"), "Green"),
        (Color(hex: "#00C7BE"), "Teal"),
        (Color(hex: "#8E8E93"), "Graphite")
    ]
    
    // Processing state
    @State private var isProcessing: Bool = false
    @State private var progressCount: Int = 0
    @State private var folderStatuses: [URL: BatchStatus] = [:]
    @State private var statusMessage: String = ""
    @State private var showSuccessSummary: Bool = false
    
    enum BatchStatus {
        case pending
        case success
        case failed(String)
        
        var text: String {
            switch self {
            case .pending: return "Pending"
            case .success: return "Applied"
            case .failed(let err): return "Failed: \(err)"
            }
        }
        
        var color: Color {
            switch self {
            case .pending: return .secondary
            case .success: return .green
            case .failed: return .red
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
                // Header
                header
                
                // Layout
                HStack(alignment: .top, spacing: AppTheme.Spacing.xxl) {
                    // Left: Folders list
                    foldersPanel
                    
                    // Right: Icon & Settings Panel
                    iconAndActionPanel
                }
                
                Spacer(minLength: AppTheme.Spacing.xxxl)
            }
            .padding(AppTheme.Spacing.xxl)
        }
        .background(AppTheme.Colors.background)
        .sheet(isPresented: $showIconPickerSheet) {
            batchIconPickerSheet
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Text("📁")
                    .font(.system(size: 26))
                Text("Batch Folder Apply")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(.primary)
                
                Text("BULK")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.2))
                    )
                    .foregroundStyle(Color.blue)
            }
            
            Text("Drag multiple folders and style them simultaneously with custom vector icons")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Folders Panel
    
    private var foldersPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack {
                Text("Target Folders (\(targetFolders.count))")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    selectMultipleFolders()
                } label: {
                    Label("Add Folders...", systemImage: "folder.badge.plus")
                        .font(AppTheme.Typography.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                        .foregroundStyle(Color.blue)
                }
                .buttonStyle(.plain)
                
                if !targetFolders.isEmpty {
                    Button {
                        targetFolders.removeAll()
                        folderStatuses.removeAll()
                    } label: {
                        Text("Clear")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
            
            // Drop Zone
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .strokeBorder(
                        isDragTargeted ? Color.blue : AppTheme.Colors.border,
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .fill(isDragTargeted ? Color.blue.opacity(0.08) : AppTheme.Colors.surface)
                    )
                
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "folder.fill.badge.plus")
                        .font(.system(size: 28))
                        .foregroundStyle(isDragTargeted ? Color.blue : .secondary)
                    
                    Text("Drop Folders Here")
                        .font(AppTheme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text("Select multiple folders from Finder and drop them together")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(AppTheme.Spacing.md)
            }
            .frame(height: 110)
            .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
                handleDroppedFolders(providers: providers)
                return true
            }
            
            // Folders Table / List
            if targetFolders.isEmpty {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("No folders added yet.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.xl)
            } else {
                VStack(spacing: 8) {
                    ForEach(targetFolders, id: \.self) { url in
                        folderRow(for: url)
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
    
    // MARK: - Folder Row
    
    private func folderRow(for url: URL) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color.blue)
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(AppTheme.Typography.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(url.path)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            let status = folderStatuses[url] ?? .pending
            Text(status.text)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(status.color.opacity(0.15)))
                .foregroundStyle(status.color)
            
            Button {
                targetFolders.removeAll { $0 == url }
                folderStatuses.removeValue(forKey: url)
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
        }
        .padding(AppTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                .fill(AppTheme.Colors.surface)
        )
    }
    
    // MARK: - Icon & Action Panel
    
    private var iconAndActionPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
            // Selected Icon Card
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Selected Icon")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.primary)
                
                Divider()
                
                if let icon = selectedIcon {
                    HStack(spacing: AppTheme.Spacing.lg) {
                        Image(nsImage: icon.thumbnailImage())
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                    .fill(AppTheme.Colors.surface)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(icon.name)
                                .font(AppTheme.Typography.body)
                                .fontWeight(.semibold)
                            Text(icon.packId)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                showIconPickerSheet = true
                            } label: {
                                Text("Change Icon...")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(Color.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Button {
                        showIconPickerSheet = true
                    } label: {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: "plus.circle.fill")
                            Text("Choose Icon from Packs...")
                        }
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                .fill(AppTheme.Colors.surface)
                        )
                    }
                    .buttonStyle(.plain)
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
            
            // Dynamic Tinting Options
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Toggle("Dynamic Color Tint", isOn: $enableTint)
                    .font(AppTheme.Typography.headline)
                
                if enableTint {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Presets:")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                            
                            ForEach(tintPresets, id: \.1) { preset in
                                Circle()
                                    .fill(preset.0)
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Circle()
                                            .stroke(tintColor == preset.0 ? Color.white : Color.clear, lineWidth: 2)
                                    )
                                    .shadow(color: preset.0.opacity(0.3), radius: 2)
                                    .onTapGesture {
                                        tintColor = preset.0
                                    }
                            }
                            
                            Spacer()
                            
                            ColorPicker("Custom", selection: $tintColor, supportsOpacity: false)
                                .labelsHidden()
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
            
            // Action Button & Progress
            VStack(spacing: AppTheme.Spacing.md) {
                if isProcessing {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: Double(progressCount), total: Double(max(targetFolders.count, 1)))
                        Text("Processing \(progressCount) of \(targetFolders.count)...")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    applyBatch()
                } label: {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(isProcessing ? "Applying..." : "Apply to \(targetFolders.count) Folders")
                            .fontWeight(.semibold)
                    }
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .fill(canApply ? Color.blue : Color.gray.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canApply || isProcessing)
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.green)
                }
            }
        }
        .frame(minWidth: 320, maxWidth: 380)
    }
    
    private var canApply: Bool {
        !targetFolders.isEmpty && selectedIcon != nil
    }
    
    // MARK: - Actions
    
    private func selectMultipleFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.title = "Select Folders to Style"
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                if !targetFolders.contains(url) {
                    targetFolders.append(url)
                    folderStatuses[url] = .pending
                }
            }
        }
    }
    
    private func handleDroppedFolders(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    DispatchQueue.main.async {
                        if !targetFolders.contains(url) {
                            targetFolders.append(url)
                            folderStatuses[url] = .pending
                        }
                    }
                }
            }
        }
    }
    
    private func applyBatch() {
        guard let icon = selectedIcon, !targetFolders.isEmpty else { return }
        
        isProcessing = true
        progressCount = 0
        statusMessage = ""
        
        let tint = enableTint ? NSColor(tintColor) : nil
        
        Task {
            for folder in targetFolders {
                if Task.isCancelled { break }
                let success = appState.applyAtomicOperation(
                    icon: icon,
                    targetFolder: folder,
                    desiredName: folder.lastPathComponent,
                    tintColor: tint,
                    undoManager: undoManager
                )
                
                folderStatuses[folder] = success ? .success : .failed("Apply failed")
                progressCount += 1
                await Task.yield()
            }
            
            isProcessing = false
            statusMessage = "Successfully applied icons to \(progressCount) folders!"
        }
    }
    
    // MARK: - Icon Picker Sheet
    
    private var filteredPickerIcons: [FolderIcon] {
        var icons = appState.cachedIconPacks.flatMap { $0.icons }
        if selectedPackFilter != "All" {
            icons = icons.filter { $0.packId == selectedPackFilter }
        }
        if !iconSearchText.isEmpty {
            icons = icons.filter { $0.name.localizedCaseInsensitiveContains(iconSearchText) || $0.packId.localizedCaseInsensitiveContains(iconSearchText) }
        }
        return icons
    }
    
    private var batchIconPickerSheet: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: AppTheme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose Icon")
                            .font(AppTheme.Typography.headline)
                        Text("Select an icon to apply to all target folders")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Done") {
                        showIconPickerSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search icons...", text: $iconSearchText)
                        .textFieldStyle(.plain)
                    if !iconSearchText.isEmpty {
                        Button {
                            iconSearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .fill(AppTheme.Colors.surface)
                )
                
                // Pack filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        packChip(title: "All", id: "All")
                        ForEach(appState.cachedIconPacks) { pack in
                            packChip(title: pack.name, id: pack.id)
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.lg)
            
            Divider()
            
            ScrollView {
                if filteredPickerIcons.isEmpty {
                    VStack(spacing: 8) {
                        Text("No matching icons found")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 12)], spacing: 12) {
                        ForEach(filteredPickerIcons) { icon in
                            VStack(spacing: 4) {
                                Image(nsImage: icon.thumbnailImage())
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 56, height: 56)
                                    .padding(4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedIcon == icon ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                
                                Text(icon.name)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedIcon = icon
                                showIconPickerSheet = false
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.lg)
                }
            }
        }
        .frame(minWidth: 540, minHeight: 460)
    }
    
    private func packChip(title: String, id: String) -> some View {
        Button {
            selectedPackFilter = id
        } label: {
            Text(title)
                .font(.system(size: 11, weight: selectedPackFilter == id ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(selectedPackFilter == id ? Color.blue.opacity(0.2) : AppTheme.Colors.surface)
                )
                .foregroundStyle(selectedPackFilter == id ? Color.blue : .primary)
        }
        .buttonStyle(.plain)
    }
}
