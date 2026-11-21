//! Custom pack builder — the file-system half of `PackBuilderView`.
//!
//! Creates a pack directory under the custom packs directory, copies the
//! chosen icon files in, and writes `metadata.json` in the same shape
//! `IconPackLoader` reads. The Swift view also previews and renames icons;
//! those UI steps are in the GUI crate, this is the part that touches disk.

use crate::models::IconPackMetadata;
use crate::pack_loader::custom_packs_directory;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct PackBuilderInput {
    pub id: String,
    pub name: String,
    pub description: String,
    pub emoji: String,
    pub accent_color_hex: String,
    /// Source icon files to copy into the pack.
    pub icon_files: Vec<PathBuf>,
}

/// Slug rule from `PackBuilderView`: lowercase, every run of
/// non-`[a-z0-9]` becomes one `-`, leading/trailing `-` trimmed.
/// Empty input → `"custom-pack"` (the live slug pill fallback).
pub fn slugify(name: &str) -> String {
    let mut out = String::new();
    let mut last_dash = true; // trims leading dashes
    for ch in name.to_lowercase().chars() {
        if ch.is_ascii_alphanumeric() {
            out.push(ch);
            last_dash = false;
        } else if !last_dash {
            out.push('-');
            last_dash = true;
        }
    }
    while out.ends_with('-') {
        out.pop();
    }
    if out.is_empty() {
        "custom-pack".to_string()
    } else {
        out
    }
}

/// Emoji presets from `PackBuilderView` (only the first 8 are shown).
pub const EMOJI_PRESETS: [&str; 15] = [
    "📁", "🚀", "💻", "🎨", "⚡", "🎮", "🦄", "🌟", "👾", "🛠️", "📦", "🏷️", "🔥", "🔮", "✨",
];

impl PackBuilderInput {
    /// Normalise the id the way the loader expects it — the PackBuilder
    /// slug rule (see `slugify`).
    pub fn normalised_id(&self) -> String {
        slugify(&self.id)
    }
}

/// Build a custom pack on disk. Returns the pack directory.
pub fn build_custom_pack(input: &PackBuilderInput) -> std::io::Result<PathBuf> {
    let id = input.normalised_id();
    let dir = custom_packs_directory().join(&id);
    fs::create_dir_all(&dir)?;
    for src in &input.icon_files {
        let name = src
            .file_name()
            .ok_or_else(|| std::io::Error::other("bad file name"))?;
        fs::copy(src, dir.join(name))?;
    }
    let meta = IconPackMetadata {
        id,
        name: input.name.trim().to_string(),
        description: if input.description.trim().is_empty() {
            "Custom folder icon pack".to_string()
        } else {
            input.description.clone()
        },
        emoji: input.emoji.clone(),
        accent_color_hex: input.accent_color_hex.clone(),
    };
    let json = serde_json::to_string_pretty(&meta).map_err(std::io::Error::other)?;
    fs::write(dir.join("metadata.json"), json)?;
    Ok(dir)
}

/// Rename an icon file inside a pack (PackBuilder rename step).
pub fn rename_pack_icon(
    pack_dir: &Path,
    old_name: &str,
    new_name: &str,
) -> std::io::Result<PathBuf> {
    let old_file = Path::new(old_name)
        .file_name()
        .ok_or_else(|| std::io::Error::other("invalid old filename"))?;
    let new_file = Path::new(new_name)
        .file_name()
        .ok_or_else(|| std::io::Error::other("invalid new filename"))?;
    let from = pack_dir.join(old_file);
    let to = pack_dir.join(new_file);
    fs::rename(&from, &to)?;
    Ok(to)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn slug_matches_pack_builder_rule() {
        assert_eq!(
            slugify("My Minimalist Workspace"),
            "my-minimalist-workspace"
        );
        assert_eq!(slugify("  Hello!! World  "), "hello-world");
        assert_eq!(slugify(""), "custom-pack");
        assert_eq!(slugify("a_b c"), "a-b-c");
    }
}
