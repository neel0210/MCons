//! Central app state — port of `AppState` in `MCons/App/AppState.swift`.
//!
//! Same fields, same flows: favourites in `MCons_Favorites`, cached packs
//! loaded once, recent folders capped at 10, and the atomic
//! rename-then-apply operation with rollback on failure.
//!
//! Undo: Swift registered the inverse operation with AppKit's
//! `UndoManager` (Cmd+Z / Shift+Cmd+Z). Rust keeps an explicit undo/redo
//! stack of `UndoEntry`s holding everything needed to reverse an apply:
//! the original URL/name, whether it was renamed, whether it had a custom
//! icon, and the original icon's PNG bytes (macOS only — on Linux the
//! original icon cannot be read back, so undo resets to the default icon).

use crate::error::IconServiceError;
use crate::folder::FolderService;
use crate::icon_service::IconService;
use crate::models::{FolderIcon, IconPack, SidebarItem};
use crate::pack_loader::IconPackLoader;
use crate::settings::Settings;
use std::path::{Path, PathBuf};

/// One reversible apply operation.
#[derive(Debug, Clone)]
pub struct UndoEntry {
    pub current_url: PathBuf,
    pub original_url: PathBuf,
    pub did_rename: bool,
    pub original_name: String,
    pub had_custom_icon: bool,
    /// PNG bytes of the icon that was on the folder before the apply
    /// (macOS only; `None` elsewhere).
    pub original_icon_png: Option<Vec<u8>>,
    pub redo_icon: FolderIcon,
    pub redo_desired_name: String,
    pub redo_tint_hex: Option<String>,
}

pub struct AppState {
    pub previous_sidebar_item: Option<SidebarItem>,
    pub selected_sidebar_item: SidebarItem,
    pub selected_icon_pack: Option<IconPack>,
    pub selected_icon: Option<FolderIcon>,
    pub target_folder_url: Option<PathBuf>,
    pub recent_folders: Vec<PathBuf>,
    pub status_message: String,
    pub current_error: Option<IconServiceError>,
    pub show_error_alert: bool,
    pub show_success_animation: bool,
    pub cached_icon_packs: Vec<IconPack>,
    pub settings: Settings,
    pub undo_stack: Vec<UndoEntry>,
    pub redo_stack: Vec<UndoEntry>,
    pub icon_service: IconService,
    pub folder_service: FolderService,
    pub icon_pack_loader: IconPackLoader,
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}

impl AppState {
    pub fn new() -> Self {
        let settings = Settings::load();
        let icon_service = IconService::new(settings.default_icon_size);
        let loader = IconPackLoader;
        let packs = loader.load_all_packs();
        Self {
            previous_sidebar_item: None,
            selected_sidebar_item: SidebarItem::Home,
            selected_icon_pack: None,
            selected_icon: None,
            target_folder_url: None,
            recent_folders: Vec::new(),
            status_message: String::new(),
            current_error: None,
            show_error_alert: false,
            show_success_animation: false,
            cached_icon_packs: packs,
            settings,
            undo_stack: Vec::new(),
            redo_stack: Vec::new(),
            icon_service,
            folder_service: FolderService,
            icon_pack_loader: loader,
        }
    }

    pub fn select_sidebar(&mut self, item: SidebarItem) {
        if self.selected_sidebar_item != item {
            self.previous_sidebar_item = Some(self.selected_sidebar_item);
            self.selected_sidebar_item = item;
        }
    }

    // MARK: - Favourites

    pub fn is_favorite(&self, icon: &FolderIcon) -> bool {
        self.settings.is_favorite(&icon.id)
    }

    pub fn toggle_favorite(&mut self, icon: &FolderIcon) {
        self.settings.toggle_favorite(&icon.id);
    }

    pub fn favorite_icons(&self) -> Vec<FolderIcon> {
        self.cached_icon_packs
            .iter()
            .flat_map(|p| p.icons.iter().cloned())
            .filter(|i| self.settings.is_favorite(&i.id))
            .collect()
    }

    // MARK: - Packs

    pub fn load_icon_packs(&mut self) -> Vec<IconPack> {
        if !self.cached_icon_packs.is_empty() {
            return self.cached_icon_packs.clone();
        }
        self.refresh_icon_packs();
        self.cached_icon_packs.clone()
    }

    pub fn refresh_icon_packs(&mut self) {
        self.cached_icon_packs = self.icon_pack_loader.load_all_packs();
    }

    pub fn delete_custom_pack(&mut self, pack: &IconPack) -> bool {
        if !pack.is_custom {
            return false;
        }
        let ok = self.icon_pack_loader.delete_custom_pack(&pack.id);
        if ok {
            self.refresh_icon_packs();
        }
        ok
    }

    // MARK: - Atomic folder operations & rollback

    /// Rename (if the name changed) then apply the icon; on any failure
    /// the rename is rolled back. Port of `applyAtomicOperation`.
    /// Returns `true` on success.
    pub fn apply_atomic_operation(
        &mut self,
        icon: &FolderIcon,
        target_folder: &Path,
        desired_name: &str,
        tint_hex: Option<&str>,
    ) -> bool {
        let original_url = target_folder.to_path_buf();
        let original_name = target_folder
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_default();
        let is_app = self.folder_service.is_application(&original_url);
        let target_type = if is_app { "App" } else { "Folder" };
        let had_custom_icon = self.icon_service.has_custom_icon(&original_url);
        let original_icon_png = self.icon_service.original_icon_png(&original_url);

        let mut clean_name = desired_name.trim().to_string();
        if is_app && !clean_name.is_empty() && !clean_name.to_lowercase().ends_with(".app") {
            clean_name.push_str(".app");
        }
        let new_name = if clean_name.is_empty() {
            original_name.clone()
        } else {
            clean_name.clone()
        };

        let mut current_url = original_url.clone();
        let mut did_rename = false;
        if new_name != original_name {
            match self.folder_service.rename_folder(&original_url, &new_name) {
                Some(renamed) => {
                    current_url = renamed;
                    did_rename = true;
                }
                None => {
                    self.fail(
                        IconServiceError::Unknown(format!(
                            "Failed to rename {} from '{original_name}' to '{new_name}'.",
                            target_type.to_lowercase()
                        )),
                        "Rename failed",
                    );
                    return false;
                }
            }
        }

        let image = match self
            .icon_service
            .load_icon_image(icon.file_url.as_deref(), icon.color_hex.as_deref())
        {
            Ok(img) => img,
            Err(_) => {
                if did_rename {
                    let _ = self
                        .folder_service
                        .rename_folder(&current_url, &original_name);
                }
                self.fail(IconServiceError::InvalidImage, "Failed to load icon");
                return false;
            }
        };

        let tint = tint_hex.and_then(crate::color::Rgb::from_hex);
        if let Err(err) = self.icon_service.set_icon(&image, &current_url, tint) {
            if did_rename {
                let _ = self
                    .folder_service
                    .rename_folder(&current_url, &original_name);
            }
            let msg = err.to_string();
            self.fail(err, &msg);
            return false;
        }

        self.target_folder_url = Some(current_url.clone());
        self.status_message = if did_rename {
            format!("{target_type} renamed & icon applied!")
        } else {
            format!("{target_type} icon applied successfully!")
        };
        self.show_success_animation = true;
        if !self.recent_folders.contains(&current_url) {
            self.recent_folders.insert(0, current_url.clone());
            self.recent_folders.truncate(10);
        }
        self.undo_stack.push(UndoEntry {
            current_url,
            original_url,
            did_rename,
            original_name,
            had_custom_icon,
            original_icon_png,
            redo_icon: icon.clone(),
            redo_desired_name: desired_name.to_string(),
            redo_tint_hex: tint_hex.map(|s| s.to_string()),
        });
        self.redo_stack.clear();
        true
    }

    fn fail(&mut self, err: IconServiceError, status: &str) {
        self.current_error = Some(err);
        self.show_error_alert = true;
        self.status_message = status.to_string();
    }

    /// Undo the last apply (Cmd+Z). Returns `false` when there is nothing
    /// to undo. Port of `performRollback` + the UndoManager registration.
    pub fn undo(&mut self) -> bool {
        let Some(entry) = self.undo_stack.pop() else {
            return false;
        };
        // 1. Restore the previous icon.
        if entry.had_custom_icon {
            if let Some(png) = &entry.original_icon_png {
                // Re-apply the saved PNG bytes via a temp file.
                let tmp =
                    std::env::temp_dir().join(format!("mcons-undo-{}.png", std::process::id()));
                if std::fs::write(&tmp, png).is_ok() {
                    let _ = self
                        .icon_service
                        .set_icon_from_path(&tmp, &entry.current_url);
                    let _ = std::fs::remove_file(&tmp);
                }
            } else {
                let _ = self.icon_service.reset_icon(&entry.current_url);
            }
        } else {
            let _ = self.icon_service.reset_icon(&entry.current_url);
        }
        // 2. Restore the original name.
        let mut restored = entry.current_url.clone();
        if entry.did_rename {
            if let Some(url) = self
                .folder_service
                .rename_folder(&entry.current_url, &entry.original_name)
            {
                restored = url;
            }
        }
        self.target_folder_url = Some(restored);
        self.status_message = "Undid icon & rename operation (Cmd+Z)".to_string();
        self.redo_stack.push(entry);
        true
    }

    /// Redo the last undone apply (Shift+Cmd+Z).
    pub fn redo(&mut self) -> bool {
        let Some(entry) = self.redo_stack.pop() else {
            return false;
        };
        let icon = entry.redo_icon.clone();
        let name = entry.redo_desired_name.clone();
        let tint = entry.redo_tint_hex.clone();
        // Apply against the restored (original) URL.
        let target = entry.original_url.clone();
        self.apply_atomic_operation(&icon, &target, &name, tint.as_deref())
    }

    pub fn apply_icon(&mut self, icon: &FolderIcon, folder: &Path) -> bool {
        let name = folder
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_default();
        self.apply_atomic_operation(icon, folder, &name, None)
    }

    pub fn reset_icon(&mut self, folder: &Path) -> bool {
        match self.icon_service.reset_icon(folder) {
            Ok(()) => {
                self.status_message = "Icon reset to default".to_string();
                true
            }
            Err(err) => {
                let msg = err.to_string();
                self.fail(err, &msg);
                false
            }
        }
    }
}
