# MCons (Brain & Architecture Map)

> **Tagline:** Icons for MacOS  
> **Developer:** Neel0210  
> **Platform:** macOS 14.0+ (Sonoma)  
> **Tech Stack:** Swift 6, SwiftUI, AppKit (`NSWorkspace`), Core Graphics  
> **Primary Output:** `output/MCons.app`

---

## 1. Directory & File Structure

```
Mac_ICOns/
├── .github/
│   └── workflows/
│       └── build.yml                    # Manual dispatch workflow for Beta & Production builds
├── .gitignore                           # Git ignore rules for SPM, Xcode, macOS, & output/
├── brain.md                             # Architecture map & system logic reference (this file)
├── README.md                            # Public repository documentation
├── project.yml                          # XcodeGen specification
├── Package.swift                         # Swift Package Manager manifest
├── build_app.sh                         # Release packaging & instance management script
├── MCons.xcodeproj/                     # Xcode project (generated via XcodeGen)
├── output/                              # Target directory for release builds
│   └── MCons.app                        # Standalone macOS app bundle
│
├── assets/                              # Brand assets & master images (losslessly compressed)
│   ├── icon.png                         # Master 2048x2048 App Icon image (losslessly compressed)
│   └── icon.svg                         # High-res 1024x1024 vector SVG master
│
└── MCons/                               # Main source directory
    ├── App/
    │   └── MConsApp.swift               # @main entry point & global AppState
    │
    ├── Core/
    │   ├── Models/
    │   │   ├── IconPack.swift           # Model for themed icon collections
    │   │   ├── FolderIcon.swift         # Model for individual folder icons
    │   │   ├── FolderIconRenderer.swift # Vector graphics 3D folder renderer & cache
    │   │   └── AppFolder.swift          # Model for target folder objects
    │   │
    │   ├── Services/
    │   │   ├── IconService.swift        # NSWorkspace.setIcon() wrapper & Finder refresh
    │   │   ├── FolderService.swift      # FileManager operations & folder rename logic
    │   │   └── IconPackLoader.swift     # Multi-path resource loader & metadata parser (SVG/PNG)
    │   │
    │   ├── Theme/
    │   │   ├── AppTheme.swift           # Design tokens (colors, typography, spacing)
    │   │   └── AppAnimations.swift      # Spring animation presets & view modifiers
    │   │
    │   └── Extensions/
    │       └── Extensions.swift         # NSColor/Color hex, NSImage, View modifiers
    │
    ├── Features/
    │   ├── Home/
    │   │   ├── ContentView.swift        # NavigationSplitView shell & sidebar
    │   │   └── HomeView.swift           # Dashboard, hero banner, quick actions
    │   │
    │   ├── IconPacks/
    │   │   ├── IconPacksView.swift      # Icon pack browser grid & search
    │   │   └── IconPackDetailView.swift # Detailed pack icon grid & action bar
    │   │
    │   ├── IconApply/
    │   │   └── IconApplyView.swift      # Icon selector, target folder, folder rename, preview
    │   │
    │   └── Settings/
    │       └── SettingsView.swift       # Preferences & developer credits
    │
    └── Resources/
        ├── Info.plist                   # App configuration & bundle metadata
        ├── MCons.entitlements           # Sandbox entitlement flags
        ├── AppIcon.icns                 # Compiled macOS app icon (from icon.png)
        ├── Assets.xcassets/             # AppIcon.appiconset (all macOS scales) & AccentColor
        └── IconPacks/                   # Bundled icon packs & metadata.json files
            ├── dark-mode-pro/
            ├── macos-native-plus/
            ├── demon-slayer/
            ├── one-piece/
            ├── solo-leveling/
            ├── pokemon/
            └── attack-on-titan/
```

---

## 2. Core Architecture & Logic

### Global State (`MConsApp.swift`)
- **`AppState`** (Observable Object):
  - Manages `selectedSidebarItem`, `selectedIconPack`, `selectedIcon`, `targetFolderURL`, `recentFolders`, and `statusMessage`.
  - Instantiates `IconService`, `FolderService`, and `IconPackLoader`.
  - Exposes `applyIcon(_:to:)` and `resetIcon(for:)` methods.

### Icon Service (`IconService.swift`)
- Wraps Apple's `NSWorkspace.shared.setIcon(_:forFile:options:)`.
- **Security-Scoped Access**: Executes `setIcon` and `resetIcon` inside `SecurityBookmarkManager.shared.withSecurityScopedAccess(to: folderURL)` for App Sandbox security compliance.
- **Lazy 512×512 Image Scaling Cache**: `prepareIconImage(_:)` uses thread-safe `NSCache<NSString, NSImage>` keying on pointer identity and dimensions. Skips re-scaling if the image is already 512×512 or cached.
- **`IconServiceError`**: Custom error enum conforming to `LocalizedError` (`folderNotFound`, `permissionDenied`, `invalidImage`, `setIconFailed`, `resetIconFailed`, `unknown`).

### Security-Scoped Bookmark Manager (`SecurityBookmarkManager.swift`)
- **App Sandbox Audit & Entitlements**:
  - `com.apple.security.files.user-selected.read-write`: `true`
  - `com.apple.security.files.bookmarks.app-scope`: `true`
- **`saveBookmark(for:)`**: Generates and persists security-scoped bookmark data in `UserDefaults`.
- **`resolveBookmark(for:)`**: Resolves saved security-scoped bookmarks (handling stale data renewal).
- **`withSecurityScopedAccess(to:block:)`**: Manages `startAccessingSecurityScopedResource()` and `stopAccessingSecurityScopedResource()` lifecycle safely around filesystem operations.

### Global State, Atomic Operations & Cmd+Z Undo (`MConsApp.swift` & `ContentView.swift`)
- **`applyAtomicOperation`**: Executes folder renaming and icon application as a single atomic operation. Rollbacks renaming if icon application fails.
- **`performRollback` & Undo Registration**: Registers inverse operations with `UndoManager` supporting full `Cmd+Z` (Undo) and `Cmd+Shift+Z` (Redo) for both icon changes and folder name changes.
- **UI Alerts**: `ContentView` displays native `.alert` dialogs bound to `appState.showErrorAlert`.

### Folder Operations (`FolderService.swift`)
- **`createFolder(named:at:)`**: Directory creation via `FileManager`.
- **`renameFolder(at:to:)`**: Renames target folder via `FileManager.moveItem(at:to:)`.
- **`folderExists(at:)`** & **`foldersInDirectory(at:)`**: Validation and navigation helpers.

### Dynamic Resource Loader (`IconPackLoader.swift`)
- Searches multiple locations for pack directories:
  1. `Bundle.main.resourceURL/MCons_MCons.bundle/IconPacks`
  2. `Bundle.main.resourceURL/IconPacks`
  3. `Bundle.module.resourceURL/IconPacks`
  4. Local project `MCons/Resources/IconPacks`
- Parses `metadata.json` (`id`, `name`, `description`, `emoji`, `accentColorHex`).
- Maps images into `FolderIcon` objects with `fileURL` or programmatically generated color fallbacks.

### Programmatic Folder Renderer (`FolderIconRenderer.swift` in `FolderIcon.swift`)
- Core Graphics vector rendering for default color packs.
- Draws folder tab, back panel, front panel, gradient highlights, and drop shadows matching macOS Sonoma aesthetics.

---

## 3. Features & UI Layout

| Feature | Screen / Component | Details |
|:---|:---|:---|
| **Sidebar Shell** | `ContentView.swift` | `NavigationSplitView` with custom MCons header and status notification bar. |
| **Home Dashboard** | `HomeView.swift` | Animated hero folder, quick action cards, pack previews, recent folder history. |
| **Pack Browser** | `IconPacksView.swift` | Searchable grid of icon packs with gradient cover cards. |
| **Pack Detail** | `IconPackDetailView.swift` | Icon grid selection, pack metadata header, bottom action bar. |
| **Icon Apply Workflow**| `IconApplyView.swift` | Icon picker, folder drag-and-drop zone, custom image import, before/after preview, reset icon. |
| **Folder Renaming** | `IconApplyView.swift` | Editable folder name field, **Keep Original Name** reset button, **Use Icon Name** shortcut, live preview sync, atomic rename + icon apply. |
| **Preferences** | `SettingsView.swift` | Icon size selector, Finder auto-refresh toggle, history limits, developer credit (`Neel0210`). |

---

## 4. Bundled Icon Packs Registry

1. 🌙 **Dark Mode Pro** (12 icons) — Sleek matte black folders with neon accent edges.
2. 🍎 **macOS Native+** (12 icons) — Enhanced Apple system folder colors.
3. ⚔️ **Demon Slayer** (10 custom 1024×1024 SVG icons):
   - Akaza, Douma, Gyomei, Kokushibo, Muichiro, Muzan, Rengoku, Sanemi, Tanjiro, Yoriichi.
4. 🏴‍☠️ **One Piece** (10 custom 1024×1024 SVG icons):
   - Ace, Chopper, Law, Luffy, Nami, Robin, Sanji, Shanks, Whitebeard, Zoro.
5. 🗡️ **Solo Leveling** (10 custom 1024×1024 SVG icons):
   - Baek Yoonho, Beru, Cha Hae In, Choi Jong In, Go Gunhee, Igris, Iron, Sung Jinwoo, Tank, Thomas Andre.
6. ⚡ **Pokémon** (10 custom 1024×1024 SVG icons):
   - Pikachu, Charizard, Charizard X, Charizard Y, Greninja, Mewtwo, Rayquaza, Salamence, Snorlax, Tyranitar.

---

## 5. Build & Distribution Workflows

### Release Build (`build_app.sh`)
```bash
./build_app.sh
```
- Stops running app instances.
- Compiles release binary with `swift build -c release`.
- Creates `output/MCons - Icons for MacOS.app` bundle structure.
- Copies `AppIcon.icns` and `IconPacks/` resources directly into `Contents/Resources/`.
- Generates `Contents/Info.plist` and `Contents/PkgInfo`.

### Instance Control
```bash
./build_app.sh --stop
```
- Gracefully (`pkill -f MCons`) and force-kills (`pkill -9`) any running process of `MCons`.

### Development Build
```bash
swift build && .build/debug/MCons
```

### Xcode Project Generation
```bash
xcodegen generate
```
- Regenerates `MCons.xcodeproj` from `project.yml`.
