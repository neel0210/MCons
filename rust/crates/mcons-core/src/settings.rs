//! Settings and favourites persistence.
//!
//! Swift kept these in `UserDefaults`: `defaultIconSize` (Double, 0 =
//! unset) and `MCons_Favorites` (array of icon ids). The Rust app stores
//! the same keys in a JSON file so the values survive on macOS and Linux
//! alike:
//! * macOS: `~/Library/Application Support/MCons/settings.json`
//! * elsewhere: `$XDG_CONFIG_HOME/mcons/settings.json` or
//!   `~/.config/mcons/settings.json`
//!
//! Other settings keys live in the SwiftUI views; the audit of those views
//! will extend this struct (see `rust/README.md`).

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::path::PathBuf;

pub const FAVORITES_KEY: &str = "MCons_Favorites";
pub const DEFAULT_ICON_SIZE_KEY: &str = "defaultIconSize";

pub fn settings_path() -> PathBuf {
    if cfg!(target_os = "macos") {
        let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
        PathBuf::from(home).join("Library/Application Support/MCons/settings.json")
    } else if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
        PathBuf::from(xdg).join("mcons/settings.json")
    } else {
        let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
        PathBuf::from(home).join(".config/mcons/settings.json")
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Settings {
    /// `defaultIconSize` — Swift `@AppStorage` default is 1024
    /// (segmented 512 / 1024 / 2048 in SettingsView). `IconService`
    /// reads it as a double and falls back to 1024 when it is 0.
    #[serde(default = "default_icon_size", rename = "defaultIconSize")]
    pub default_icon_size: f64,
    /// `MCons_Favorites` — favourite icon ids.
    #[serde(default, rename = "MCons_Favorites")]
    pub favorites: Vec<String>,
    /// `showIconNames` (default true). Dead setting in Swift: stored,
    /// read nowhere else.
    #[serde(default = "default_true", rename = "showIconNames")]
    pub show_icon_names: bool,
    /// `autoRefreshFinder` (default true). Dead setting in Swift:
    /// `IconService.refreshFinder` always touches the folder.
    #[serde(default = "default_true", rename = "autoRefreshFinder")]
    pub auto_refresh_finder: bool,
    /// `recentFolderLimit` (default 10, stepper 5–25 step 5). Dead
    /// setting in Swift: `AppState` hard-caps recents at 10.
    #[serde(default = "default_recent_limit", rename = "recentFolderLimit")]
    pub recent_folder_limit: i64,
}

fn default_icon_size() -> f64 {
    1024.0
}
fn default_true() -> bool {
    true
}
fn default_recent_limit() -> i64 {
    10
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            default_icon_size: 1024.0,
            favorites: Vec::new(),
            show_icon_names: true,
            auto_refresh_finder: true,
            recent_folder_limit: 10,
        }
    }
}

impl Settings {
    pub fn load() -> Self {
        let path = settings_path();
        std::fs::read_to_string(path)
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default()
    }

    pub fn save(&self) -> std::io::Result<()> {
        let path = settings_path();
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let json = serde_json::to_string_pretty(self).unwrap_or_default();
        std::fs::write(path, json)
    }

    pub fn favorite_ids(&self) -> HashSet<String> {
        self.favorites.iter().cloned().collect()
    }

    pub fn is_favorite(&self, icon_id: &str) -> bool {
        self.favorites.iter().any(|id| id == icon_id)
    }

    /// Toggle a favourite and persist — port of `AppState.toggleFavorite`.
    pub fn toggle_favorite(&mut self, icon_id: &str) {
        if let Some(pos) = self.favorites.iter().position(|id| id == icon_id) {
            self.favorites.remove(pos);
        } else {
            self.favorites.push(icon_id.to_string());
        }
        let _ = self.save();
    }
}
