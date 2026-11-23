//! Security-scoped bookmarks — port of `SecurityBookmarkManager` in
//! `MCons/Core/Services/SecurityBookmarkManager.swift`.
//!
//! Swift stored bookmark data in UserDefaults under
//! `mcons_sec_bookmark_<path>` so a sandboxed app could keep access to
//! folders the user picked. The Rust app is not sandboxed (Swift's own
//! entitlements set `com.apple.security.app-sandbox: false`), so there is
//! nothing to scope: `save_bookmark` / `remove_bookmark` are no-ops that
//! report success, `resolve_bookmark` returns the URL unchanged, and
//! `with_scoped_access` simply runs the closure. The API surface is kept
//! identical so callers port 1:1.

use std::path::{Path, PathBuf};

pub const KEY_PREFIX: &str = "mcons_sec_bookmark_";

#[derive(Default)]
pub struct SecurityBookmarkManager;

impl SecurityBookmarkManager {
    pub fn save_bookmark(&self, _url: &Path) -> bool {
        true
    }

    pub fn resolve_bookmark(&self, url: &Path) -> PathBuf {
        url.to_path_buf()
    }

    pub fn with_scoped_access<T, E, F>(&self, url: &Path, f: F) -> std::result::Result<T, E>
    where
        F: FnOnce(&Path) -> std::result::Result<T, E>,
    {
        f(&self.resolve_bookmark(url))
    }

    pub fn remove_bookmark(&self, _url: &Path) {}
}
