//! Icon pack discovery — port of `IconPackLoader` in
//! `MCons/Core/Services/IconPackLoader.swift`.
//!
//! Same candidate directories, same first-wins de-duplication by pack id,
//! same metadata fallbacks (`<dir name>.capitalized`, "Custom folder icon
//! pack", 📁, `#6C5CE7`), same extension priority
//! `svg > png > icns > jpg > jpeg > tiff`, same name display
//! (`_`/`-` → space, title-cased), same sort by pack name, and the same
//! programmatic macOS Native+ defaults appended when absent.

use crate::models::{default_packs, FolderIcon, IconPack, IconPackMetadata};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};

pub const IMAGE_EXTENSIONS: [&str; 6] = ["svg", "png", "jpg", "jpeg", "icns", "tiff"];
/// Priority order used when several files share a base name.
pub const EXT_PRIORITY: [&str; 6] = ["svg", "png", "icns", "jpg", "jpeg", "tiff"];

/// `~/Library/Application Support/MCons/CustomPacks` on macOS; on other
/// platforms the XDG data dir equivalent. Swift creates the directory.
pub fn custom_packs_directory() -> PathBuf {
    if cfg!(target_os = "macos") {
        let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
        let dir = PathBuf::from(home).join("Library/Application Support/MCons/CustomPacks");
        let _ = fs::create_dir_all(&dir);
        dir
    } else if let Ok(xdg) = std::env::var("XDG_DATA_HOME") {
        let dir = PathBuf::from(xdg).join("MCons/CustomPacks");
        let _ = fs::create_dir_all(&dir);
        dir
    } else {
        let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
        let dir = PathBuf::from(home).join(".local/share/MCons/CustomPacks");
        let _ = fs::create_dir_all(&dir);
        dir
    }
}

/// Candidate pack roots, in Swift's order: bundle resources, the
/// development checkout (`MCons/Resources/IconPacks` under the current
/// directory), then the user's custom packs directory.
pub fn candidate_pack_roots() -> Vec<PathBuf> {
    let mut roots = Vec::new();
    if let Ok(exe) = std::env::current_exe() {
        if let Some(parent) = exe.parent() {
            roots.push(parent.join("IconPacks"));
            roots.push(parent.join("Resources/IconPacks"));
        }
        // <app>.app/Contents/Resources/IconPacks, best-effort mirror of
        // Bundle.main.resourceURL.
        if let Some(resources) = exe.parent().and_then(|p| p.parent()) {
            roots.push(resources.join("Resources/IconPacks"));
        }
    }
    if let Ok(cwd) = std::env::current_dir() {
        roots.push(cwd.join("MCons/Resources/IconPacks"));
        // Also work when run from the repo root's rust/ directory, or
        // from a crate directory (cargo test runs there: 3 levels up).
        roots.push(cwd.join("../MCons/Resources/IconPacks"));
        roots.push(cwd.join("../../MCons/Resources/IconPacks"));
        roots.push(cwd.join("../../../MCons/Resources/IconPacks"));
    }
    // Relative to the executable: the built app lives at
    // <repo>/rust/target/debug/mcons-app (or a .app bundle's
    // Contents/MacOS/), so walking up from the exe finds the repo's
    // MCons/Resources/IconPacks regardless of the working directory.
    if let Ok(exe) = std::env::current_exe() {
        for ancestor in exe.ancestors().skip(1).take(6) {
            roots.push(ancestor.join("MCons/Resources/IconPacks"));
            roots.push(ancestor.join("Resources/IconPacks"));
        }
    }
    roots.push(custom_packs_directory());
    roots
}

pub struct IconPackLoader;

impl IconPackLoader {
    pub fn load_all_packs(&self) -> Vec<IconPack> {
        self.load_all_packs_from(&candidate_pack_roots())
    }

    pub fn load_all_packs_from(&self, roots: &[PathBuf]) -> Vec<IconPack> {
        let mut loaded: HashMap<String, IconPack> = HashMap::new();
        let mut checked: HashSet<PathBuf> = HashSet::new();

        for root in roots {
            let Ok(canonical) = dunce_canonical(root) else {
                continue;
            };
            if !checked.insert(canonical) {
                continue;
            }
            if !root.is_dir() {
                continue;
            }
            let Ok(entries) = fs::read_dir(root) else {
                continue;
            };
            for entry in entries.flatten() {
                let dir = entry.path();
                if !dir.is_dir() {
                    continue;
                }
                let Some(pack) = load_pack_dir(&dir) else {
                    continue;
                };
                loaded.entry(pack.id.clone()).or_insert(pack);
            }
        }

        let mut all: Vec<IconPack> = loaded.into_values().collect();
        for default in default_packs() {
            if !all.iter().any(|p| p.id == default.id) {
                all.push(default);
            }
        }
        all.sort_by(|a, b| a.name.cmp(&b.name));
        all
    }

    /// Deletes a custom pack. Port of `deleteCustomPack(id:)`.
    pub fn delete_custom_pack(&self, id: &str) -> bool {
        let dir = custom_packs_directory().join(id);
        if dir.exists() {
            fs::remove_dir_all(&dir).is_ok()
        } else {
            false
        }
    }
}

fn dunce_canonical(p: &Path) -> std::io::Result<PathBuf> {
    // std::fs::canonicalize requires the path to exist; fall back to the
    // lexical path so missing roots are simply skipped by the caller.
    fs::canonicalize(p).or_else(|_| Ok(p.to_path_buf()))
}

fn load_pack_dir(dir: &Path) -> Option<IconPack> {
    let dir_name = dir
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();
    let mut pack_id = dir_name.to_lowercase();
    let mut name = title_case(&dir_name);
    let mut description = "Custom folder icon pack".to_string();
    let mut emoji = "📁".to_string();
    let mut accent = "#6C5CE7".to_string();

    let metadata_path = dir.join("metadata.json");
    if let Ok(data) = fs::read(&metadata_path) {
        if let Ok(meta) = serde_json::from_slice::<IconPackMetadata>(&data) {
            pack_id = meta.id;
            name = meta.name;
            description = meta.description;
            emoji = meta.emoji;
            accent = meta.accent_color_hex;
        }
    }

    let icons = load_icons(dir, &pack_id);
    if icons.is_empty() {
        return None;
    }
    let is_custom = dir.to_string_lossy().contains("CustomPacks");
    Some(IconPack {
        id: pack_id,
        name,
        description,
        emoji,
        accent_color_hex: accent,
        icons,
        is_custom,
    })
}

/// Group files by base name, keep the highest-priority extension, sort by
/// file name (Swift: `localizedStandardCompare`), build `FolderIcon`s.
pub fn load_icons(dir: &Path, pack_id: &str) -> Vec<FolderIcon> {
    let Ok(entries) = fs::read_dir(dir) else {
        return Vec::new();
    };
    let mut by_base: HashMap<String, PathBuf> = HashMap::new();
    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        let ext = path
            .extension()
            .map(|e| e.to_string_lossy().to_lowercase())
            .unwrap_or_default();
        if !IMAGE_EXTENSIONS.contains(&ext.as_str()) {
            continue;
        }
        let base = path
            .file_stem()
            .map(|s| s.to_string_lossy().into_owned())
            .unwrap_or_default();
        let rank = |p: &Path| {
            let e = p
                .extension()
                .map(|x| x.to_string_lossy().to_lowercase())
                .unwrap_or_default();
            EXT_PRIORITY.iter().position(|x| *x == e).unwrap_or(99)
        };
        match by_base.get(&base) {
            Some(existing) if rank(&path) >= rank(existing) => {}
            _ => {
                by_base.insert(base, path);
            }
        }
    }
    let mut files: Vec<PathBuf> = by_base.into_values().collect();
    files.sort_by(|a, b| {
        a.file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .cmp(&b.file_name().unwrap_or_default().to_string_lossy())
    });
    files
        .into_iter()
        .map(|file| {
            let stem = file
                .file_stem()
                .map(|s| s.to_string_lossy().into_owned())
                .unwrap_or_default();
            FolderIcon {
                id: format!("{pack_id}_{stem}"),
                name: title_case(&stem.replace(['_', '-'], " ")),
                pack_id: pack_id.to_string(),
                file_url: Some(file),
                color_hex: None,
            }
        })
        .collect()
}

/// Swift `String.capitalized`: first letter of each word upper-cased.
pub fn title_case(s: &str) -> String {
    s.split_whitespace()
        .map(|word| {
            let mut chars = word.chars();
            match chars.next() {
                Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
                None => String::new(),
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn loads_bundled_packs_from_repo_checkout() {
        // Tests run with cwd = crates/mcons-core; the repo checkout is two
        // levels up, covered by candidate_pack_roots().
        let loader = IconPackLoader;
        let packs = loader.load_all_packs();
        // 19 bundled packs with icon files + macOS Native+ (its dir holds
        // only metadata.json, so the 12 programmatic colour icons from
        // default_packs() fill it in) = 20.
        assert!(packs.len() >= 20, "got {} packs", packs.len());
        let native = packs
            .iter()
            .find(|p| p.id == "macos-native-plus")
            .expect("macos-native-plus");
        assert_eq!(native.icon_count(), 12);
        let demon = packs
            .iter()
            .find(|p| p.id == "demon-slayer")
            .expect("demon-slayer");
        assert_eq!(demon.name, "Demon Slayer");
        assert!(!demon.icons.is_empty());
        assert!(demon.icons.iter().all(|i| i.pack_id == "demon-slayer"));
        // Extension priority: an .svg wins over a same-named .png.
        assert!(demon.icons.iter().any(|i| i
            .file_url
            .as_ref()
            .map(|p| p.extension().map(|e| e == "svg").unwrap_or(false))
            .unwrap_or(false)));
        // Sorted by name.
        let names: Vec<_> = packs.iter().map(|p| p.name.clone()).collect();
        let mut sorted = names.clone();
        sorted.sort();
        assert_eq!(names, sorted);
    }

    #[test]
    fn title_case_matches_capitalized() {
        assert_eq!(title_case("eren yeager"), "Eren Yeager");
        assert_eq!(title_case("attack-on-titan"), "Attack-on-titan");
    }
}
