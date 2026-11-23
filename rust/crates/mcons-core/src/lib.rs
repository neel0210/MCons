//! # mcons-core
//!
//! MCons ported as-is from Swift to Rust. The Swift app is a native macOS
//! (Swift 6 + SwiftUI) utility that applies custom icons to Finder folders
//! and apps, ships 20 bundled icon packs, builds custom packs, and checks
//! GitHub Releases for updates. This crate is the whole non-UI half of
//! that app, plus the state machine the UI drives.
//!
//! Module map (Swift → Rust):
//!
//! | Swift | Rust |
//! |---|---|
//! | `Core/Models/IconPack.swift`, `FolderIcon.swift`, `AppFolder.swift` | [`models`] |
//! | `Core/Extensions/Extensions.swift` (hex colour) | [`color`] |
//! | `Core/Models/FolderIconRenderer.swift` | [`renderer`] |
//! | `Core/Services/IconPackLoader.swift` | [`pack_loader`] |
//! | `Core/Services/FolderService.swift` | [`folder`] |
//! | `Core/Services/IconService.swift` | [`icon_service`], [`images`], [`platform`] |
//! | `Core/Services/IconImageCache.swift` | [`image_cache`] |
//! | `Core/Services/IconExportService.swift` | [`export`] |
//! | `Core/Services/SecurityBookmarkManager.swift` | [`bookmarks`] |
//! | `Core/Services/UpdateService.swift` | [`update`] |
//! | `App/AppState.swift` (+ favourites/settings keys) | [`app_state`], [`settings`] |
//! | `Features/PackBuilder` (disk half) | [`pack_builder`] |
//!
//! macOS-only behaviour (`NSWorkspace.setIcon`, `iconutil`, security
//! bookmarks) is gated with `cfg(target_os = "macos")`; on other platforms
//! those calls return `IconServiceError::UnsupportedOnPlatform` instead of
//! pretending to work.

pub mod app_state;
pub mod bookmarks;
pub mod color;
pub mod error;
pub mod export;
pub mod folder;
pub mod icon_service;
pub mod image_cache;
pub mod images;
pub mod models;
pub mod pack_builder;
pub mod pack_loader;
pub mod platform;
pub mod renderer;
pub mod settings;
pub mod update;

pub use app_state::AppState;
pub use error::{IconServiceError, Result};
pub use models::{FolderIcon, IconPack, SidebarItem};
pub use pack_loader::IconPackLoader;
pub use settings::Settings;

/// The Rust release version (v1.0.0). The Swift original this ports was
/// `MARKETING_VERSION 1.1.0` (see `PORT_SPEC.md`).
pub const VERSION: &str = "1.0.0";
