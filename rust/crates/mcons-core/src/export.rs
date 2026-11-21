//! Icon export — port of `IconExportService` in
//! `MCons/Core/Services/IconExportService.swift`.
//!
//! Same formats and file names: PNG 1024×1024, `.icns` via a temp
//! `icon.iconset` + `/usr/bin/iconutil` on macOS (fallback: 1024 PNG with
//! an `.icns` extension, exactly as Swift), and original SVG copy with a
//! PNG fallback for non-SVG icons. The Swift save-panel UI is the GUI
//! crate's job; this module does the file writing.

use crate::color::Rgb;
use crate::error::{IconServiceError, Result};
use crate::images::{load_image_file, thumbnail, tint_image, to_png_bytes};
use crate::models::FolderIcon;
use crate::renderer;
use image::RgbaImage;
use std::path::Path;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExportFormat {
    Png,
    Icns,
    Svg,
}

impl ExportFormat {
    /// Swift `rawValue`, e.g. `"PNG Image (1024×1024)"`.
    pub fn label(self) -> &'static str {
        match self {
            ExportFormat::Png => "PNG Image (1024×1024)",
            ExportFormat::Icns => "macOS Icon (.icns)",
            ExportFormat::Svg => "Original Vector (.svg)",
        }
    }

    pub fn file_extension(self) -> &'static str {
        match self {
            ExportFormat::Png => "png",
            ExportFormat::Icns => "icns",
            ExportFormat::Svg => "svg",
        }
    }

    pub fn all() -> &'static [ExportFormat] {
        &[ExportFormat::Png, ExportFormat::Icns, ExportFormat::Svg]
    }
}

/// The standard macOS iconset sizes, same list as Swift.
pub const ICONSET_SIZES: [(&str, u32); 10] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
];

pub fn load_icon_raster(icon: &FolderIcon) -> Result<RgbaImage> {
    if let Some(url) = &icon.file_url {
        return load_image_file(url, 1024);
    }
    if let Some(hex) = &icon.color_hex {
        return Ok(renderer::render_folder_icon(hex, 1024));
    }
    Err(IconServiceError::InvalidImage)
}

pub fn export_as_png(icon: &FolderIcon, dest: &Path, tint: Option<Rgb>) -> Result<()> {
    let mut image = load_icon_raster(icon)?;
    if let Some(tint) = tint {
        image = tint_image(&image, tint);
    }
    // Crisp 1024×1024 bitmap, same as Swift.
    let rendered = thumbnail(&image, 1024);
    let png = to_png_bytes(&rendered)?;
    std::fs::write(dest, png).map_err(|_| IconServiceError::InvalidImage)
}

static ICNS_TMP_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

pub fn export_as_icns(icon: &FolderIcon, dest: &Path, tint: Option<Rgb>) -> Result<()> {
    let mut image = load_icon_raster(icon)?;
    if let Some(tint) = tint {
        image = tint_image(&image, tint);
    }
    let seq = ICNS_TMP_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    let tmp = std::env::temp_dir().join(format!("MCons_icns_{}_{}", std::process::id(), seq));
    let iconset = tmp.join("icon.iconset");
    std::fs::create_dir_all(&iconset).map_err(|_| IconServiceError::InvalidImage)?;
    let result = (|| -> Result<()> {
        for (filename, px) in ICONSET_SIZES {
            let scaled = thumbnail(&image, px);
            let png = to_png_bytes(&scaled)?;
            std::fs::write(iconset.join(filename), png)
                .map_err(|_| IconServiceError::InvalidImage)?;
        }
        Ok(())
    })();
    if result.is_err() {
        let _ = std::fs::remove_dir_all(&tmp);
        return result;
    }
    // macOS native iconutil; elsewhere (or on failure) fall back to a
    // 1024 PNG with the .icns extension — Swift's exact fallback.
    let converted = if cfg!(target_os = "macos") {
        std::process::Command::new("/usr/bin/iconutil")
            .args(["-c", "icns"])
            .arg(iconset.as_os_str())
            .args(["-o"])
            .arg(dest.as_os_str())
            .status()
            .map(|s| s.success())
            .unwrap_or(false)
    } else {
        false
    };
    let _ = std::fs::remove_dir_all(&tmp);
    if !converted {
        return export_as_png(icon, dest, tint);
    }
    Ok(())
}

pub fn export_as_original_vector(icon: &FolderIcon, dest: &Path) -> Result<()> {
    if let Some(url) = &icon.file_url {
        if url
            .extension()
            .map(|e| e.eq_ignore_ascii_case("svg"))
            .unwrap_or(false)
        {
            let data = std::fs::read(url).map_err(|_| IconServiceError::InvalidImage)?;
            std::fs::write(dest, data).map_err(|_| IconServiceError::InvalidImage)?;
            return Ok(());
        }
    }
    export_as_png(icon, dest, None)
}

pub fn export(
    icon: &FolderIcon,
    format: ExportFormat,
    dest: &Path,
    tint: Option<Rgb>,
) -> Result<()> {
    match format {
        ExportFormat::Png => export_as_png(icon, dest, tint),
        ExportFormat::Icns => export_as_icns(icon, dest, tint),
        ExportFormat::Svg => export_as_original_vector(icon, dest),
    }
}
