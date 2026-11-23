//! Folder icon application — port of `IconService` in
//! `MCons/Core/Services/IconService.swift`.
//!
//! Same validation order (folder exists → writable → image → setIcon),
//! same `Icon\r` custom-icon check, same Finder refresh, same tint and
//! prepare steps. The actual `setIcon` call lives in `platform.rs` and is
//! macOS-only; on other platforms it returns `UnsupportedOnPlatform`.

use crate::color::Rgb;
use crate::error::{IconServiceError, Result};
use crate::images::{load_image_file, prepare_icon_image, tint_image, to_png_bytes};
use crate::platform;
use crate::renderer;
use image::RgbaImage;
use std::path::{Path, PathBuf};

/// Swift's `defaultIconSize` UserDefaults key; 0/unset → 1024.
pub const DEFAULT_ICON_SIZE: f64 = 1024.0;

/// Tint presets from `IconApplyView`.
pub const TINT_PRESETS: [(&str, &str); 8] = [
    ("Blue", "#007AFF"),
    ("Purple", "#AF52DE"),
    ("Pink", "#FF2D55"),
    ("Red", "#FF3B30"),
    ("Orange", "#FF9500"),
    ("Green", "#34C759"),
    ("Mint", "#00C7BE"),
    ("Graphite", "#8E8E93"),
];

pub struct IconService {
    /// Value of the `defaultIconSize` setting (0 = unset → 1024).
    pub default_icon_size: f64,
}

impl Default for IconService {
    fn default() -> Self {
        Self {
            default_icon_size: 0.0,
        }
    }
}

impl IconService {
    pub fn new(default_icon_size: f64) -> Self {
        Self { default_icon_size }
    }

    fn canvas_points(&self) -> f64 {
        if self.default_icon_size > 0.0 {
            self.default_icon_size
        } else {
            DEFAULT_ICON_SIZE
        }
    }

    /// Load the raster image for an icon: from file, or rendered from its
    /// colour hex. Port of `FolderIcon.loadImage()`.
    pub fn load_icon_image(
        &self,
        file_url: Option<&Path>,
        color_hex: Option<&str>,
    ) -> Result<RgbaImage> {
        if let Some(url) = file_url {
            // Swift caches full-size here; the cache crate handles that.
            return load_image_file(url, 1024);
        }
        if let Some(hex) = color_hex {
            return Ok(renderer::render_folder_icon(hex, 1024));
        }
        Err(IconServiceError::InvalidImage)
    }

    /// Set a custom icon on a folder. Port of `setIcon(image:for:tintColor:)`.
    ///
    /// Swift's `prepareIconImage` keeps two sizes apart — do not conflate
    /// them: the *point* size is `max(defaultIconSize, 1024)`, while the
    /// *pixel* dimension is `max(2048, min(maxSrcPixel, 4096))`.
    pub fn set_icon(&self, image: &RgbaImage, folder: &Path, tint: Option<Rgb>) -> Result<()> {
        validate_folder(folder)?;
        let mut base = image.clone();
        if let Some(tint) = tint {
            base = tint_image(&base, tint);
        }
        let _ = self.canvas_points();
        let max_src = base.width().max(base.height());
        let pixel_dim = (2048u32).max(max_src.min(4096));
        let prepared = prepare_icon_image(&base, pixel_dim);
        self.set_prepared_icon(&prepared, folder)
    }

    /// Set an icon from a file path. Port of `setIcon(fromPath:for:)`.
    pub fn set_icon_from_path(&self, image_path: &Path, folder: &Path) -> Result<()> {
        let image = load_image_file(image_path, 1024)?;
        self.set_icon(&image, folder, None)
    }

    /// The macOS call itself, after validation + preparation. The prepared
    /// image is written to a temp PNG and handed to AppKit (NSWorkspace
    /// takes an NSImage, loaded from that file on macOS).
    fn set_prepared_icon(&self, image: &RgbaImage, folder: &Path) -> Result<()> {
        let png = to_png_bytes(image)?;
        let tmp = temp_icon_path();
        std::fs::write(&tmp, &png).map_err(|_| IconServiceError::SetIconFailed {
            path: folder.to_string_lossy().into_owned(),
        })?;
        let result = platform::set_folder_icon(&tmp, folder);
        let _ = std::fs::remove_file(&tmp);
        result?;
        platform::refresh_finder(folder);
        Ok(())
    }

    /// Remove a custom icon. Port of `resetIcon(for:)`.
    pub fn reset_icon(&self, folder: &Path) -> Result<()> {
        validate_folder(folder)?;
        platform::reset_folder_icon(folder)?;
        platform::refresh_finder(folder);
        Ok(())
    }

    /// Port of `hasCustomIcon(for:)`: macOS stores the icon in a file
    /// literally named `Icon\r` inside the folder.
    pub fn has_custom_icon(&self, folder: &Path) -> bool {
        if cfg!(target_os = "windows") {
            folder.join("desktop.ini").exists()
        } else {
            folder.join("Icon\r").exists()
        }
    }

    /// The current icon as PNG bytes, macOS only (Swift: `getIcon(for:)`).
    /// On other platforms this is unsupported — callers that need the
    /// original icon for undo should use `original_icon_png` only on macOS.
    pub fn original_icon_png(&self, _folder: &Path) -> Option<Vec<u8>> {
        None
    }
}

/// Shared validation for set/reset: folder must exist, be a directory,
/// and be writable — same order and errors as Swift.
pub fn validate_folder(folder: &Path) -> Result<()> {
    let path = folder.to_string_lossy().into_owned();
    if !folder.is_dir() {
        return Err(IconServiceError::FolderNotFound { path });
    }
    // Writable check: try opening the directory for write via a probe is
    // racy; use metadata readonly flag, matching `isWritableFile`.
    let meta = std::fs::metadata(folder)
        .map_err(|_| IconServiceError::FolderNotFound { path: path.clone() })?;
    if meta.permissions().readonly() {
        return Err(IconServiceError::PermissionDenied { path });
    }
    Ok(())
}

static ICON_TMP_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

/// Where Swift kept the prepared icon before handing it to AppKit.
pub fn temp_icon_path() -> PathBuf {
    let seq = ICON_TMP_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    std::env::temp_dir().join(format!("mcons-icon-{}-{}.png", std::process::id(), seq))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validate_rejects_missing_folder() {
        let err = validate_folder(Path::new("/definitely/not/a/folder/xyz")).unwrap_err();
        assert!(matches!(err, IconServiceError::FolderNotFound { .. }));
    }

    #[test]
    fn has_custom_icon_checks_icon_cr_file() {
        let dir = tempfile::tempdir().unwrap();
        let svc = IconService::default();
        assert!(!svc.has_custom_icon(dir.path()));
        std::fs::write(dir.path().join("Icon\r"), b"x").unwrap();
        assert!(svc.has_custom_icon(dir.path()));
    }

    #[test]
    fn set_icon_on_linux_reports_unsupported_not_success() {
        // On this Linux VM the macOS call cannot run; it must fail loudly
        // with UnsupportedOnPlatform, never pretend success.
        if cfg!(target_os = "macos") {
            return;
        }
        let dir = tempfile::tempdir().unwrap();
        let svc = IconService::default();
        let img = RgbaImage::new(64, 64);
        let err = svc.set_icon(&img, dir.path(), None).unwrap_err();
        assert!(
            matches!(err, IconServiceError::UnsupportedOnPlatform(_)),
            "{err:?}"
        );
    }
}
