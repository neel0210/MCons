# MCons in Rust

The whole MCons app, as it is, ported from Swift to Rust. Same packs, same
flows, same strings and limits — just a different language.

Branch: `rust`, based on `origin/MAC` @ `7d3b416` (v1.1.0, Mac-only).
The Swift code stays in the tree untouched as the reference implementation;
the Rust workspace lives in `rust/`.

## Layout

```
rust/
  Cargo.toml                  workspace (mcons-core, mcons-cli, mcons-app)
  crates/mcons-core/          all non-UI logic, ported 1:1 from Swift
  crates/mcons-cli/           `mcons` binary — every operation, no GUI
  crates/mcons-app/           `mcons-app` binary — local Web UI (std-only HTTP
                              server + single-page app) reproducing the SwiftUI
                              views pixel-for-pixel: same JetBlack tokens,
                              sidebar, and copy
```

### Swift → Rust map

| Swift | Rust |
|---|---|
| `Core/Models/IconPack.swift`, `FolderIcon.swift`, `AppFolder.swift` | `mcons-core/src/models.rs` |
| `Core/Extensions/Extensions.swift` (hex colour) | `color.rs` |
| `Core/Models/FolderIconRenderer.swift` | `renderer.rs` |
| `Core/Services/IconPackLoader.swift` | `pack_loader.rs` |
| `Core/Services/FolderService.swift` | `folder.rs` |
| `Core/Services/IconService.swift` | `icon_service.rs`, `images.rs`, `platform.rs` |
| `Core/Services/IconImageCache.swift` | `image_cache.rs` |
| `Core/Services/IconExportService.swift` | `export.rs` |
| `Core/Services/SecurityBookmarkManager.swift` | `bookmarks.rs` |
| `Core/Services/UpdateService.swift` | `update.rs` |
| `App/AppState.swift` | `app_state.rs`, `settings.rs` |
| `Features/PackBuilder` (disk half) | `pack_builder.rs` |
| `App/MConsApp.swift`, `Features/*/…View.swift` | `mcons-app/src/main.rs` |

## Build & test

```sh
cargo test --workspace
cargo run -p mcons-cli -- packs
cargo run -p mcons-cli -- icons demon-slayer
cargo run -p mcons-cli -- render-color '#007AFF' /tmp/folder.png
cargo run -p mcons-app   # Web UI at http://127.0.0.1:8795/
```

The Web UI is a single-page app (`crates/mcons-app/web/index.html`,
embedded in the binary) served by a std-only `TcpListener` HTTP server —
no new network crates. Hash routes `#/home`, `#/packs` (+ `#/packs/<id>`
detail), `#/favorites`, `#/apply`, `#/batch`, `#/builder`, `#/updates`,
`#/settings`, `#/about`, `#/quick` (the MenuBarExtra quick-apply view).
JSON API under `/api/*` backed by `mcons-core`; thumbnails at
`/api/thumb?id=…&size=128` via the 128px image cache; the real app icon
(extracted from `AppIcon.icns`) at `/appicon.png`. SF Symbols do not
exist outside Apple, so the sidebar/view icons are hand-drawn inline
SVGs matching the Swift symbols. Folder picking is a browse modal plus
a paste-a-path field (the web app has no Finder drag-in); everything
else — tint presets, rename, import, batch statuses, pack builder slug,
updates terminal installer — follows the Swift files exactly. On Linux,
apply/reset return the core's macOS-only error instead of pretending
to work.

UI polish (iOS 26 Liquid Glass): the Web UI uses the Glisse glass recipe
from the GitGems WebUI — frosted surfaces (`blur(20px) saturate(180%)`),
specular top edges, gradient rims, cursor-tracked highlight on cards,
frosted sticky headers and action bar, iOS switches (51×31, accent fill),
a segmented control with a sliding frosted thumb, bottom-sheet modals
with drag handle and spring close, spring physics
(`cubic-bezier(0.32,0.72,0,1)` / bouncy `cubic-bezier(0.34,1.56,0.64,1)`),
staggered card/icon entrances, skeleton shimmer + thumbnail fade-in,
and `prefers-reduced-motion` support. Under 700px wide the sidebar is
replaced by a floating glass tab bar (Home / Packs / Favorites / Apply /
More, the rest in a sheet). True displacement-map refraction (Glisse's
canvas lens) is not ported — CSS glass only, which is the visible 90%.

macOS target check (verifies the AppKit code compiles, no Mac needed):

```sh
rustup target add x86_64-apple-darwin
cargo check -p mcons-core --target x86_64-apple-darwin
```

Caveat: the full workspace check fails on this Linux VM because `ring`
(a `ureq`/`rustls` dependency) compiles C with `-arch x86_64
-mmacosx-version-min=10.7`, which the Linux `cc` rejects — it needs a
macOS SDK. The AppKit code itself (`platform.rs`: `NSWorkspace.setIcon`
via `class!(NSWorkspace)` + `msg_send!`, `NSImage::initWithContentsOfFile_`)
was verified separately with a minimal cocoa+objc harness crate for
`x86_64-apple-darwin` — it type-checks clean (0 errors). That harness is
not in the repo; the check needs redoing on a Mac before shipping.

## Behaviour kept as-is

- Pack loading: `metadata.json` per pack dir, SVG > PNG > ICNS > JPG
  priority, title-cased icon names, sorted by pack name, custom packs in
  `~/Library/Application Support/MCons/CustomPacks`, macOS Native+ 12
  colours appended when absent.
- Apply: validate folder → writable → load image → trim transparent
  margins (alpha > 13) → fill 96% of a ≥1024pt canvas → `NSWorkspace.setIcon`
  → touch folder so Finder refreshes. Rename first when asked, roll the
  rename back if the icon fails. Recent folders capped at 10.
- Undo: Swift used AppKit `UndoManager` (Cmd+Z / Shift+Cmd+Z). Rust keeps
  an explicit undo/redo stack with the same entries (original URL/name,
  rename flag, previous-icon PNG on macOS).
- Cache: 300 entries / 64 MiB, 128×128 thumbnails, keys
  `"<path>"`, `"<path>_<size>"`, `"<hex>_<size>"`.
- Export: PNG 1024×1024, `.icns` via temp `icon.iconset` + `iconutil`
  (fallback: 1024 PNG with `.icns` extension), SVG copied as-is.
- Updates: GitHub Releases API for `neel0210/MCons`, same version compare,
  installer via `/tmp/mcons_update.command` running `install.sh`.
- Favourites: icon ids under the `MCons_Favorites` key.

## Deliberate deviations

- **Settings storage.** Swift used `UserDefaults` (macOS plist). Rust
  stores the same keys (`defaultIconSize` default 1024, `showIconNames`,
  `autoRefreshFinder`, `recentFolderLimit`, `MCons_Favorites`) in
  `~/Library/Application Support/MCons/settings.json` on macOS, and
  `$XDG_CONFIG_HOME/mcons/settings.json` elsewhere. The last three are
  dead settings in Swift too (stored, never consumed) — Rust keeps them
  for the same reason.
- **Security bookmarks.** Swift stored sandbox bookmark data; the Rust app
  is not sandboxed (the Swift entitlements already set app-sandbox off),
  so `bookmarks.rs` is a no-op pass-through with the same API.
- **Folder-icon shadow.** `FolderIconRenderer`'s CoreGraphics blurred drop
  shadow is a soft translucent silhouette in Rust (no blur kernel yet);
  shape, proportions and colours are identical.
- **`.icns` input.** Swift's `NSImage` decoded `.icns` files; the Rust
  loader returns `InvalidImage` for `.icns` sources until an ICNS decoder
  is added. SVG/PNG/JPEG all work (SVG via `resvg`).
- **Menu-bar extra.** Swift's `MenuBarView` is a macOS menu-bar popup, which
  a web UI cannot be; it is implemented as the `#/quick` "Quick Apply"
  view (same drop/browse, first-8-favourites 1-click, first-3-recents,
  Open/Quit adapted to the web app), reachable from the sidebar footer.
- **Non-macOS apply.** `NSWorkspace.setIcon` has no Linux equivalent, so
  `apply`/`reset` on Linux return `UnsupportedOnPlatform` loudly instead
  of pretending to work. Everything else (pack loading, rendering,
  export, CLI) runs on Linux and is tested there.
