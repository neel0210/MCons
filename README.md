<div align="center">
  <img src="assets/icon.png" width="128" height="128" alt="MCons App Icon" />
  <h1>MCons</h1>
  <h3>Icons for MacOS</h3>

  <p>A native macOS utility for creating folders with custom icons. Built with <b>Swift 6</b> and <b>SwiftUI</b>.</p>

  <p>Developed by <b>Neel0210</b></p>

  <p>
    <img src="https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple" alt="macOS" />
    <img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift" alt="Swift" />
    <img src="https://img.shields.io/badge/License-MIT-green" alt="License" />
  </p>

  <p>
    <a href="https://t.me/MConsOfficial">📢 <b>Telegram Channel (@MConsOfficial)</b></a> &nbsp;|&nbsp; 
    <a href="https://t.me/MConsupport">💬 <b>Telegram Support Group (@MConsupport)</b></a>
  </p>
</div>

---

## ✨ Features

- 🎨 **Curated Vector & Anime Icon Packs** — High-resolution (1024×1024) SVG vector icons across popular series and modern desktop themes.
- 📁 **Create & Style** — Create new directories and apply icons in a single atomic workflow.
- 🖱️ **Drag & Drop** — Drop folders or image files directly into the window to apply instantly.
- ✏️ **Smart Folder Renaming** — Option to rename target folder, use icon name, or keep original name with real-time preview.
- ↩️ **Full Undo / Redo (Cmd+Z / Shift+Cmd+Z)** — Complete macOS `UndoManager` integration with automatic rollback if operations fail.
- 🖼️ **Multi-Format Custom Import** — Import `.svg`, `.png`, `.jpg`, `.icns`, and `.tiff` files to use as custom folder icons.
- 🔙 **Seamless Navigation** — Back button support across views with automatic state and pack detail restoration.
- 🔄 **Reset to Default** — One-click restore to native macOS folder icon.
- ⚡ **Silky Performance** — Dynamic icon loading, asynchronous cache preheating, and 120fps ProMotion animations.
- 🌙 **Dark & Light Mode** — Sleek macOS design with Glassmorphism, card elevation, and responsive design tokens.

---

## 📦 Bundled Icon Packs

| Pack | Theme | Icons | Format | Featured Characters / Styles |
|:---|:---|:---:|:---:|:---|
| **Attack on Titan** | *Shingeki no Kyojin* Scouts & Titans | 10 | 1024×1024 SVG | Eren Yeager, Mikasa, Armin, Levi, Erwin, Hange, Reiner, Annie, Attack Titan, Colossal Titan |
| **Demon Slayer** | *Kimetsu no Yaiba* Hashira & Demons | 10 | 1024×1024 SVG | Tanjiro, Rengoku, Akaza, Douma, Gyomei, Kokushibo, Muichiro, Muzan, Sanemi, Yoriichi |
| **One Piece** | Straw Hat Pirates & Legends | 10 | 1024×1024 SVG | Luffy, Zoro, Sanji, Nami, Robin, Chopper, Ace, Law, Shanks, Whitebeard |
| **Pokémon** | Iconic & Legendary Pokémon | 10 | 1024×1024 SVG | Pikachu, Mewtwo, Rayquaza, Charizard, Charizard X, Charizard Y, Greninja, Snorlax, Tyranitar, Salamence |
| **Solo Leveling** | *Na Honjaman Rebeleob* Hunters & Shadows | 10 | 1024×1024 SVG | Sung Jinwoo, Igris, Beru, Iron, Tank, Cha Hae-In, Baek Yoonho, Choi Jong-In, Go Gunhee, Thomas Andre |
| **macOS Native+** | Enhanced Apple system colors | 12 | CoreGraphics Vector | Cupertino Blue, Deep Purple, Rose Pink, Crimson Red, Sunset Orange, Emerald Green, etc. |

---

## 🛠️ Adding Custom Icon Packs & Icons

Want to add your own custom icon packs to MCons? Follow this simple guide:

### 1. Icon Specifications
- **Recommended Resolution**: **1024×1024** or **512×512** pixels (1:1 square ratio)
- **Supported Formats**: `.svg` (recommended vector format), `.png` (transparent background), `.jpg`, `.icns`, or `.tiff`
- **Color Profile**: sRGB or Display P3 with alpha channel transparency

### 2. File Structure
Create a subfolder for your pack inside `MCons/Resources/IconPacks/`:

```text
MCons/Resources/IconPacks/my-pack/
├── metadata.json
├── Icon1.svg
├── Icon2.svg
└── Icon3.svg
```

### 3. Add `metadata.json`
Inside your pack folder, create a `metadata.json` file:

```json
{
    "id": "my-pack",
    "name": "My Custom Pack",
    "description": "My awesome custom folder icons",
    "emoji": "🎨",
    "accentColorHex": "#6C5CE7"
}
```

### 4. Automatic Discovery
No Swift code changes are needed! The dynamic `IconPackLoader` automatically scans and registers all pack folders:
1. Run `./build_app.sh` (or `swift build`)
2. Launch MCons — your new icon pack will automatically appear in the **Icon Packs** tab!

---

## 💻 Requirements

- **macOS**: 14.0 (Sonoma) or later (compatible with macOS 15 Sequoia)
- **Architecture**: Apple Silicon (M1/M2/M3/M4) or Intel Mac
- **Xcode**: 15.0+ / Swift 6.0+ (for building from source)

---

## 🚀 Installation & Quick Start

### 1-Line Installer (Recommended)
Run in Terminal to auto-download, install to `/Applications`, remove Gatekeeper quarantine, and launch:
```bash
curl -fsSL https://raw.githubusercontent.com/neel0210/MCons/main/install.sh | bash
```

### Manual Build & Run (Debug via Swift CLI)
```bash
swift build
.build/debug/MCons
```

### Release Build (.app Bundle)
```bash
chmod +x build_app.sh
./build_app.sh
open "output/MCons.app"
```

### Open in Xcode
The project includes both a `Package.swift` (SPM) and an `.xcodeproj` (generated via XcodeGen):
```bash
# Regenerate the Xcode project
xcodegen generate

# Open in Xcode
open MCons.xcodeproj
```

### macOS Gatekeeper Note (Downloaded Builds)
If macOS blocks opening a downloaded release build due to Gatekeeper quarantine:
```bash
# Remove quarantine attribute
xattr -cr /Applications/MCons.app
```
Or right-click `MCons.app` in Finder and select **Open**.

---

## 📂 Project Structure

```text
MCons/
├── App/                        # Application lifecycle & AppState (MConsApp.swift)
├── Features/
│   ├── Home/                   # Dashboard, quick actions, recent folders (HomeView.swift)
│   ├── IconPacks/              # Pack browsing, search, and detail grid (IconPacksView.swift)
│   ├── IconApply/              # Icon selection, folder drop zone, atomic apply (IconApplyView.swift)
│   └── Settings/               # Preferences, cache controls, and about info (SettingsView.swift)
├── Core/
│   ├── Services/               # IconService, FolderService, IconPackLoader, IconImageCache, SecurityBookmarkManager
│   ├── Models/                 # IconPack, FolderIcon, AppFolder, FolderIconRenderer
│   ├── Extensions/             # Color hex helpers, NSImage utilities, View modifiers
│   └── Theme/                  # Design tokens, typography, gradients, and animations
└── Resources/
    ├── Assets.xcassets/        # App icons & asset catalogs
    └── IconPacks/              # Bundled icon pack SVG vectors & metadata
```

---

## ⚙️ How It Works

**MCons** uses Apple's native `NSWorkspace.setIcon(_:forFile:options:)` API to apply custom folder icons. This is the official macOS method that:

- ✅ Persists across system reboots and Finder restarts
- ✅ Renders smoothly across Finder, Dock, Quick Look, and Spotlight
- ✅ Supports clean one-click restoration to default macOS folder icons
- ✅ Handles atomic folder rename and icon application with complete `UndoManager` rollback support (Cmd+Z)
- ✅ Employs `SecurityBookmarkManager` to preserve sandboxed folder access permissions

---

## ⚖️ Fair Use & Intellectual Property Notice

All character designs, vector artwork, logos, and trademarks bundled or referenced in MCons remain the intellectual property and copyright of their respective owners and creators:

- **⚡ Pokémon**: © Nintendo / Creatures Inc. / GAME FREAK inc. / The Pokémon Company
- **⚔️ Attack on Titan (*Shingeki no Kyojin*)**: © Hajime Isayama / Kodansha / "ATTACK ON TITAN" Production Committee / MAPPA / WIT Studio
- **⚔️ Demon Slayer (*Kimetsu no Yaiba*)**: © Koyoharu Gotouge / SHUEISHA / Aniplex / ufotable
- **🏴‍☠️ One Piece**: © Eiichiro Oda / SHUEISHA / Toei Animation
- **🗡️ Solo Leveling (*Na Honjaman Rebeleob*)**: Story by Chugong, Art by DUBU (REDICE STUDIO), © D&C Media / KakaoPage / A-1 Pictures
- **Apple & macOS**: macOS, SF Symbols, Finder, and Dock are trademarks of Apple Inc.

### Fair Use Statement
> **Fair Use Notice:** MCons is a free, non-profit, open-source personal customization utility provided for personal desktop aesthetics, non-commercial commentary, fan tribute, and organizational use.
>
> In accordance with **Title 17 U.S.C. Section 107 (Fair Use Doctrine)** and international copyright exceptions:
> - The software is distributed free of charge with **zero monetization, advertising, or commercial intent**.
> - Icons and vector assets are included for **transformative desktop interface customization** by individual end-users.
> - No copyright or trademark infringement is intended. If you are a copyright holder and wish to have specific material removed, please contact the author or open an issue on GitHub.

---

## 📄 License

Distributed under the **MIT License**. See [LICENSE](LICENSE) for more information.

---

## 👨‍💻 Author

Made with ❤️ by **Neel0210** while vibe coding.

- Telegram Channel: [@MConsOfficial](https://t.me/MConsOfficial)
- Telegram Support: [@MConsupport](https://t.me/MConsupport)
