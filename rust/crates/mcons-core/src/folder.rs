//! Folder operations — port of `FolderService` in
//! `MCons/Core/Services/FolderService.swift`.

use std::fs;
use std::path::{Path, PathBuf};

pub struct FolderService;

impl FolderService {
    /// Creates a folder, with intermediate directories. Port of
    /// `createFolder(named:at:)` (bookmark saving is a no-op in Rust —
    /// see `bookmarks.rs`).
    pub fn create_folder(&self, name: &str, parent: &Path) -> Option<PathBuf> {
        let clean = Path::new(name).file_name()?.to_str()?;
        if clean.is_empty() || clean == "." || clean == ".." {
            return None;
        }
        let folder = parent.join(clean);
        fs::create_dir_all(&folder).ok().map(|_| folder)
    }

    pub fn folder_exists(&self, url: &Path) -> bool {
        url.is_dir()
    }

    /// Folders only, hidden files skipped.
    pub fn folders_in_directory(&self, url: &Path) -> Vec<PathBuf> {
        let Ok(entries) = fs::read_dir(url) else {
            return Vec::new();
        };
        entries
            .flatten()
            .map(|e| e.path())
            .filter(|p| {
                p.is_dir()
                    && !p
                        .file_name()
                        .map(|n| n.to_string_lossy().starts_with('.'))
                        .unwrap_or(false)
            })
            .collect()
    }

    pub fn display_name(&self, url: &Path) -> String {
        url.file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_default()
    }

    pub fn home_directory(&self) -> PathBuf {
        std::env::var("HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("/"))
    }

    pub fn desktop_directory(&self) -> Option<PathBuf> {
        Some(self.home_directory().join("Desktop"))
    }

    pub fn documents_directory(&self) -> Option<PathBuf> {
        Some(self.home_directory().join("Documents"))
    }

    /// Rename, keeping the `.app` suffix for applications — port of
    /// `renameFolder(at:to:)`.
    pub fn rename_folder(&self, url: &Path, new_name: &str) -> Option<PathBuf> {
        let clean = Path::new(new_name).file_name()?.to_str()?;
        if clean.is_empty() || clean == "." || clean == ".." {
            return None;
        }
        let mut target_name = clean.to_string();
        if self.is_application(url) && !target_name.to_lowercase().ends_with(".app") {
            target_name.push_str(".app");
        }
        let parent = url.parent()?;
        let new_url = parent.join(target_name);
        fs::rename(url, &new_url).ok().map(|_| new_url)
    }

    pub fn is_application(&self, url: &Path) -> bool {
        url.extension()
            .map(|e| e.eq_ignore_ascii_case("app"))
            .unwrap_or(false)
    }

    /// `/Applications`, `/System/Applications`, `~/Applications`, deduped
    /// by name, sorted case-insensitively by name without extension.
    pub fn installed_applications(&self) -> Vec<PathBuf> {
        let mut apps: Vec<PathBuf> = Vec::new();
        let dirs = [
            PathBuf::from("/Applications"),
            PathBuf::from("/System/Applications"),
            self.home_directory().join("Applications"),
        ];
        for dir in dirs {
            let Ok(entries) = fs::read_dir(&dir) else {
                continue;
            };
            for entry in entries.flatten() {
                let path = entry.path();
                if !self.is_application(&path) {
                    continue;
                }
                let name = path.file_name().map(|n| n.to_string_lossy().into_owned());
                if !apps
                    .iter()
                    .any(|a| a.file_name().map(|n| n.to_string_lossy().into_owned()) == name)
                {
                    apps.push(path);
                }
            }
        }
        apps.sort_by(|a, b| {
            let an = a
                .file_stem()
                .map(|s| s.to_string_lossy().to_lowercase())
                .unwrap_or_default();
            let bn = b
                .file_stem()
                .map(|s| s.to_string_lossy().to_lowercase())
                .unwrap_or_default();
            an.cmp(&bn)
        });
        apps
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn home_directory_resolves() {
        let svc = FolderService;
        let home = svc.home_directory();
        assert!(home.is_absolute());
    }

    #[test]
    fn path_traversal_is_blocked() {
        let svc = FolderService;
        let dir = tempfile::tempdir().unwrap();
        assert!(
            svc.create_folder("../escaped", dir.path()).is_none() || {
                let res = svc.create_folder("../escaped", dir.path()).unwrap();
                res.starts_with(dir.path())
            }
        );
        assert!(svc.create_folder("..", dir.path()).is_none());
        assert!(svc.create_folder(".", dir.path()).is_none());
    }
}
