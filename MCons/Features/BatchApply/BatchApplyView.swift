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
    @State private var tintColor: Color = Color(hex: "#007AFF") ?? .blue
    @State private var showIconPickerSheet: Bool = false
    @State private var isDragTargeted: Bool = false
    
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
                        Image(nsImage: icon.previewImage())
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
                    HStack {
                        Text("Tint Color:")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                        ColorPicker("Tint", selection: $tintColor, supportsOpacity: false)
                            .labelsHidden()
                        Spacer()
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
                let success = appState.applyAtomicOperation(
                    icon: icon,
                    targetFolder: folder,
                    desiredName: folder.lastPathComponent,
                    tintColor: tint,
                    undoManager: undoManager
                )
                
                await MainActor.run {
                    folderStatuses[folder] = success ? .success : .failed("Apply failed")
                    progressCount += 1
                }
            }
            
            await MainActor.run {
                isProcessing = false
                statusMessage = "Successfully applied icons to \(progressCount) folders!"
            }
        }
    }
    
    // MARK: - Icon Picker Sheet
    
    private var batchIconPickerSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose Icon")
                    .font(AppTheme.Typography.headline)
                Spacer()
                Button("Done") {
                    showIconPickerSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(AppTheme.Spacing.lg)
            
            Divider()
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 12)], spacing: 12) {
                    ForEach(appState.cachedIconPacks.flatMap { $0.icons }) { icon in
                        VStack(spacing: 4) {
                            Image(nsImage: icon.previewImage())
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
        .frame(minWidth: 500, minHeight: 400)
    }
}
