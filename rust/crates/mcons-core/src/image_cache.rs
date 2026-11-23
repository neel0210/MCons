//! In-memory image cache — port of `IconImageCache` in
//! `MCons/Core/Services/IconImageCache.swift`.
//!
//! Same limits (300 entries, 64 MiB total cost, cost = w×h×4 bytes),
//! same key scheme (`"<path>"`, `"<path>_<size>"`, `"<hex>_<size>"`),
//! same 128×128 standard thumbnail size, same preheat behaviour.
//! Swift used `NSCache` (evicts under memory pressure); this port evicts
//! the oldest-inserted entry when a limit would be exceeded.

use crate::images::{load_image_file, thumbnail};
use crate::renderer;
use image::RgbaImage;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

pub const COUNT_LIMIT: usize = 300;
pub const TOTAL_COST_LIMIT: usize = 64 * 1024 * 1024;
pub const THUMBNAIL_SIZE: u32 = 128;

pub struct IconImageCache {
    inner: Mutex<CacheInner>,
}

struct CacheInner {
    map: HashMap<String, RgbaImage>,
    order: Vec<String>,
    total_cost: usize,
}

impl Default for IconImageCache {
    fn default() -> Self {
        Self::new()
    }
}

impl IconImageCache {
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(CacheInner {
                map: HashMap::new(),
                order: Vec::new(),
                total_cost: 0,
            }),
        }
    }

    pub fn image_for_key(&self, key: &str) -> Option<RgbaImage> {
        self.inner.lock().ok()?.map.get(key).cloned()
    }

    pub fn set_image(&self, image: RgbaImage, key: &str) {
        let cost = image_cost(&image);
        let mut inner = match self.inner.lock() {
            Ok(g) => g,
            Err(_) => return,
        };
        if let Some(old) = inner.map.get(key) {
            inner.total_cost -= image_cost(old);
            inner.order.retain(|k| k != key);
        }
        while (inner.map.len() >= COUNT_LIMIT || inner.total_cost + cost > TOTAL_COST_LIMIT)
            && !inner.order.is_empty()
        {
            let oldest = inner.order.remove(0);
            if let Some(old) = inner.map.remove(&oldest) {
                inner.total_cost -= image_cost(&old);
            }
        }
        inner.total_cost += cost;
        inner.order.push(key.to_string());
        inner.map.insert(key.to_string(), image);
    }

    /// Load (or reuse) an image for a file URL, optionally scaled to
    /// `target_size`. Port of `image(for:targetSize:)`.
    pub fn image_for_url(&self, url: &Path, target_size: Option<u32>) -> Option<RgbaImage> {
        let key = match target_size {
            Some(s) => format!("{}_{}", url.display(), s),
            None => url.display().to_string(),
        };
        if let Some(cached) = self.image_for_key(&key) {
            return Some(cached);
        }
        // SVG thumbnails rasterise directly at the target size: loading
        // at 1024 then downscaling made the pack grid paint 80+ SVGs at
        // full size on its first frame (tens of seconds of blocked UI).
        let is_svg = url
            .extension()
            .map(|e| e.to_string_lossy().to_lowercase() == "svg")
            .unwrap_or(false);
        let base = if let Some(cached) = self.image_for_key(&url.display().to_string()) {
            cached
        } else if let (true, Some(size)) = (is_svg, target_size) {
            let loaded = load_image_file(url, size).ok()?;
            self.set_image(loaded.clone(), &key);
            return Some(loaded);
        } else {
            let loaded = load_image_file(url, 1024).ok()?;
            if target_size.is_none() {
                self.set_image(loaded.clone(), &url.display().to_string());
            }
            loaded
        };
        match target_size {
            Some(size) if base.dimensions() != (size, size) => {
                let scaled = thumbnail(&base, size);
                self.set_image(scaled.clone(), &key);
                Some(scaled)
            }
            _ => {
                self.set_image(base.clone(), &key);
                Some(base)
            }
        }
    }

    /// Instant thumbnail lookup, no disk read. Port of `cachedThumbnail(for:)`.
    pub fn cached_thumbnail(
        &self,
        file_url: Option<&Path>,
        color_hex: Option<&str>,
    ) -> Option<RgbaImage> {
        if let Some(url) = file_url {
            let key = format!("{}_128", url.display());
            return self.image_for_key(&key);
        }
        if let Some(hex) = color_hex {
            return self.image_for_key(&format!("{hex}_128"));
        }
        None
    }

    /// Pre-warm 128×128 thumbnails for every icon in the packs.
    /// Swift did this in parallel on a utility queue; this port warms
    /// sequentially (same result, same cache keys).
    pub fn preheat(&self, packs: &[crate::models::IconPack]) {
        for icon in packs.iter().flat_map(|p| &p.icons) {
            if let Some(url) = &icon.file_url {
                let _ = self.image_for_url(url, Some(THUMBNAIL_SIZE));
            } else if let Some(hex) = &icon.color_hex {
                let key = format!("{hex}_128");
                if self.image_for_key(&key).is_none() {
                    let img = renderer::render_folder_icon(hex, THUMBNAIL_SIZE);
                    self.set_image(img, &key);
                }
            }
        }
    }

    pub fn clear(&self) {
        if let Ok(mut inner) = self.inner.lock() {
            inner.map.clear();
            inner.order.clear();
            inner.total_cost = 0;
        }
    }

    pub fn len(&self) -> usize {
        self.inner.lock().map(|g| g.map.len()).unwrap_or(0)
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

fn image_cost(image: &RgbaImage) -> usize {
    let (w, h) = image.dimensions();
    (w as usize) * (h as usize) * 4
}

#[allow(dead_code)]
fn _pathbuf(_p: PathBuf) {}
