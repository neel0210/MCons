//! Data models — port of `MCons/Core/Models/`.
//!
//! * `IconPack` / `FolderIcon` / `AppFolder` — same fields, same derived
//!   values (`category`, `preview_icons`, `icon_count`), same JSON shape.
//! * Hash / equality in Swift is by `id` only; Rust mirrors that with
//!   manual `PartialEq`/`Hash` impls.

use serde::{Deserialize, Serialize};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::path::PathBuf;

/// The per-pack `metadata.json` on disk.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct IconPackMetadata {
    pub id: String,
    pub name: String,
    pub description: String,
    pub emoji: String,
    #[serde(rename = "accentColorHex")]
    pub accent_color_hex: String,
}

/// A single folder icon inside a pack. Port of `FolderIcon`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FolderIcon {
    pub id: String,
    pub name: String,
    #[serde(rename = "packId")]
    pub pack_id: String,
    #[serde(rename = "fileURL", skip_serializing_if = "Option::is_none")]
    pub file_url: Option<PathBuf>,
    #[serde(rename = "colorHex", skip_serializing_if = "Option::is_none")]
    pub color_hex: Option<String>,
}

impl PartialEq for FolderIcon {
    fn eq(&self, other: &Self) -> bool {
        self.id == other.id
    }
}
impl Eq for FolderIcon {}
impl Hash for FolderIcon {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.id.hash(state);
    }
}

impl FolderIcon {
    pub fn new(id: impl Into<String>, name: impl Into<String>, pack_id: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            pack_id: pack_id.into(),
            file_url: None,
            color_hex: None,
        }
    }

    pub fn with_file(mut self, path: PathBuf) -> Self {
        self.file_url = Some(path);
        self
    }

    pub fn with_color(mut self, hex: impl Into<String>) -> Self {
        self.color_hex = Some(hex.into());
        self
    }
}

/// A collection of themed folder icons. Port of `IconPack`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IconPack {
    pub id: String,
    pub name: String,
    pub description: String,
    pub emoji: String,
    #[serde(rename = "accentColorHex")]
    pub accent_color_hex: String,
    #[serde(default)]
    pub icons: Vec<FolderIcon>,
    #[serde(rename = "isCustom", default)]
    pub is_custom: bool,
}

impl PartialEq for IconPack {
    fn eq(&self, other: &Self) -> bool {
        self.id == other.id
    }
}
impl Eq for IconPack {}
impl Hash for IconPack {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.id.hash(state);
    }
}

impl IconPack {
    pub fn icon_count(&self) -> usize {
        self.icons.len()
    }

    /// Category tag for filtering — same switch as Swift.
    pub fn category(&self) -> &'static str {
        if self.is_custom {
            return "Custom";
        }
        match self.id.as_str() {
            "attack-on-titan"
            | "black-clover"
            | "chainsaw-man"
            | "dandadan"
            | "death-note"
            | "demon-slayer"
            | "dragon-ball-super"
            | "fullmetal-alchemist-brotherhood"
            | "jujutsu-kaisen"
            | "kaiju-no-8"
            | "my-hero-academia"
            | "naruto"
            | "one-piece"
            | "pokemon"
            | "solo-leveling" => "Anime",
            "dev-tech" | "developer-tech" => "Dev & Tech",
            "google" => "Apps",
            "macos-native-plus" => "System",
            _ => "Other",
        }
    }

    /// Preview icons (first 4) for grid thumbnails.
    pub fn preview_icons(&self) -> &[FolderIcon] {
        &self.icons[..self.icons.len().min(4)]
    }
}

/// A folder on disk the user wants to customise. Port of `AppFolder`.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct AppFolder {
    pub id: String,
    pub url: PathBuf,
    pub name: String,
    pub has_custom_icon: bool,
}

impl AppFolder {
    pub fn new(url: PathBuf, has_custom_icon: bool) -> Self {
        let name = url
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_default();
        Self {
            id: uuid_string(),
            url,
            name,
            has_custom_icon,
        }
    }
}

fn uuid_string() -> String {
    // No uuid crate needed: a 128-bit random value rendered as a UUID.
    use std::time::{SystemTime, UNIX_EPOCH};
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    let mut h = DefaultHasher::new();
    std::process::id().hash(&mut h);
    nanos.hash(&mut h);
    let a = h.finish();
    let mut h2 = DefaultHasher::new();
    a.hash(&mut h2);
    let b = h2.finish();
    let g1 = (b >> 48) as u16;
    let g2 = ((b >> 32) as u16 & 0x0fff) | 0x4000;
    let g3 = ((b >> 16) as u16 & 0x3fff) | 0x8000;
    let g4 = b & 0xffff_ffff_ffff;
    format!("{a:08x}-{g1:04x}-{g2:04x}-{g3:04x}-{g4:012x}")
}

/// The 12 programmatic macOS Native+ colours from `IconPackLoader.defaultPacks()`.
pub const MACOS_NATIVE_PLUS_COLORS: [(&str, &str); 12] = [
    ("System Blue", "#007AFF"),
    ("System Purple", "#AF52DE"),
    ("System Pink", "#FF2D55"),
    ("System Red", "#FF3B30"),
    ("System Orange", "#FF9500"),
    ("System Yellow", "#FFCC00"),
    ("System Green", "#34C759"),
    ("System Teal", "#5AC8FA"),
    ("System Indigo", "#5856D6"),
    ("System Brown", "#A2845E"),
    ("System Mint", "#00C7BE"),
    ("System Graphite", "#8E8E93"),
];

pub fn default_packs() -> Vec<IconPack> {
    vec![IconPack {
        id: "macos-native-plus".to_string(),
        name: "macOS Native+".to_string(),
        description: "Enhanced versions of Apple's native folder colors".to_string(),
        emoji: "🍎".to_string(),
        accent_color_hex: "#007AFF".to_string(),
        icons: MACOS_NATIVE_PLUS_COLORS
            .iter()
            .map(|(name, hex)| {
                FolderIcon::new(
                    format!(
                        "macos-native-plus_{}",
                        name.to_lowercase().replace(' ', "-")
                    ),
                    *name,
                    "macos-native-plus",
                )
                .with_color(*hex)
            })
            .collect(),
        is_custom: false,
    }]
}

/// Sidebar destinations — port of `SidebarItem` in `MCons/App/SidebarItem.swift`.
/// Order is Swift's `CaseIterable` order, grouped in the UI as DISCOVER
/// (Home, Icon Packs, Favorites, Apply Icon, Batch Apply, Pack Builder)
/// and PREFERENCES (Updates, Settings, About).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum SidebarItem {
    Home,
    IconPacks,
    Favorites,
    IconApply,
    BatchApply,
    PackBuilder,
    Updates,
    Settings,
    About,
}

impl SidebarItem {
    pub fn all() -> &'static [SidebarItem] {
        &[
            SidebarItem::Home,
            SidebarItem::IconPacks,
            SidebarItem::Favorites,
            SidebarItem::IconApply,
            SidebarItem::BatchApply,
            SidebarItem::PackBuilder,
            SidebarItem::Updates,
            SidebarItem::Settings,
            SidebarItem::About,
        ]
    }

    pub fn title(self) -> &'static str {
        match self {
            SidebarItem::Home => "Home",
            SidebarItem::IconPacks => "Icon Packs",
            SidebarItem::Favorites => "Favorites",
            SidebarItem::IconApply => "Apply Icon",
            SidebarItem::BatchApply => "Batch Apply",
            SidebarItem::PackBuilder => "Pack Builder",
            SidebarItem::Updates => "Updates",
            SidebarItem::Settings => "Settings",
            SidebarItem::About => "About",
        }
    }

    /// SF Symbol name from Swift (`SidebarItem.icon`).
    pub fn sf_symbol(self) -> &'static str {
        match self {
            SidebarItem::Home => "house.fill",
            SidebarItem::IconPacks => "square.grid.3x3.fill",
            SidebarItem::Favorites => "star.fill",
            SidebarItem::IconApply => "folder.badge.plus",
            SidebarItem::BatchApply => "square.stack.3d.up.fill",
            SidebarItem::PackBuilder => "wrench.and.screwdriver.fill",
            SidebarItem::Updates => "arrow.triangle.2.circlepath",
            SidebarItem::Settings => "gearshape.fill",
            SidebarItem::About => "info.circle.fill",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn category_matches_swift_switch() {
        let pack = |id: &str| IconPack {
            id: id.to_string(),
            name: id.to_string(),
            description: String::new(),
            emoji: String::new(),
            accent_color_hex: "#000000".to_string(),
            icons: vec![],
            is_custom: false,
        };
        assert_eq!(pack("demon-slayer").category(), "Anime");
        assert_eq!(pack("dev-tech").category(), "Dev & Tech");
        assert_eq!(pack("google").category(), "Apps");
        assert_eq!(pack("macos-native-plus").category(), "System");
        assert_eq!(pack("marvel").category(), "Other");
        assert_eq!(pack("cameras").category(), "Other");
        let mut custom = pack("demon-slayer");
        custom.is_custom = true;
        assert_eq!(custom.category(), "Custom");
    }

    #[test]
    fn default_packs_have_twelve_colours() {
        let packs = default_packs();
        assert_eq!(packs.len(), 1);
        assert_eq!(packs[0].icon_count(), 12);
        assert_eq!(packs[0].icons[0].color_hex.as_deref(), Some("#007AFF"));
    }
}
