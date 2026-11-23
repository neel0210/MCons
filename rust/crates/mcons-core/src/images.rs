//! Image loading, tinting and trimming — the pixel-level half of
//! `IconService` and `FolderIcon.loadImage()` in Swift.
//!
//! * Raster files (PNG/JPEG) decode with the `image` crate.
//! * SVG files rasterise with `resvg`/`usvg` (Swift used CoreSVG/NSImage).
//! * `.icns` has no pure-Rust decoder in this port yet — it returns
//!   `InvalidImage`, matching the Swift failure path when `NSImage` cannot
//!   load a file.
//! * Tinting is source-atop, exactly as `IconService.tintImage`.
//! * `non_transparent_bounds` uses Swift's alpha threshold of 13 (~0.05×255).

use crate::color::Rgb;
use crate::error::{IconServiceError, Result};
use image::{Rgba, RgbaImage};
use std::path::Path;

pub const ALPHA_THRESHOLD: u8 = 13;
/// Swift `prepareIconImage` fill ratio: icon fills ~96% of the canvas.
pub const FILL_RATIO: f64 = 0.96;

/// Decode an image file. SVG is rasterised at `raster_size` px.
pub fn load_image_file(path: &Path, raster_size: u32) -> Result<RgbaImage> {
    let ext = path
        .extension()
        .map(|e| e.to_string_lossy().to_lowercase())
        .unwrap_or_default();
    match ext.as_str() {
        "svg" => rasterize_svg(path, raster_size),
        "png" | "jpg" | "jpeg" | "tiff" | "tif" => {
            let img = image::open(path).map_err(|_| IconServiceError::InvalidImage)?;
            Ok(img.to_rgba8())
        }
        _ => Err(IconServiceError::InvalidImage),
    }
}

pub fn rasterize_svg(path: &Path, size: u32) -> Result<RgbaImage> {
    let data = std::fs::read(path).map_err(|_| IconServiceError::InvalidImage)?;
    rasterize_svg_bytes(&data, size)
}

pub fn rasterize_svg_bytes(data: &[u8], size: u32) -> Result<RgbaImage> {
    let opt = usvg::Options::default();
    let tree = usvg::Tree::from_data(data, &opt).map_err(|_| IconServiceError::InvalidImage)?;
    let svg_size = tree.size();
    let scale =
        (size as f32 / svg_size.width().max(1.0)).min(size as f32 / svg_size.height().max(1.0));
    let mut pixmap = tiny_skia::Pixmap::new(size, size).ok_or(IconServiceError::InvalidImage)?;
    let transform = tiny_skia::Transform::from_scale(scale, scale);
    resvg::render(&tree, transform, &mut pixmap.as_mut());
    let mut img = RgbaImage::new(size, size);
    for (pixel, p) in img.pixels_mut().zip(pixmap.pixels()) {
        let a = p.alpha();
        if a == 0 {
            *pixel = Rgba([0, 0, 0, 0]);
        } else {
            let un = |v: u8| ((v as u32 * 255 / a as u32).min(255)) as u8;
            *pixel = Rgba([un(p.red()), un(p.green()), un(p.blue()), a]);
        }
    }
    Ok(img)
}

/// Source-atop tint: the tint colour is painted only where the source
/// image is opaque, preserving alpha and detail. Port of
/// `IconService.tintImage`.
pub fn tint_image(image: &RgbaImage, tint: Rgb) -> RgbaImage {
    let [tr, tg, tb, _] = tint.to_rgba8();
    let mut out = image.clone();
    for pixel in out.pixels_mut() {
        if pixel[3] > 0 {
            pixel[0] = tr;
            pixel[1] = tg;
            pixel[2] = tb;
            // Alpha untouched — source-atop keeps the source alpha.
        }
    }
    out
}

/// Non-transparent bounding box, in pixel coordinates. Returns the full
/// image bounds when nothing is above the threshold — same as Swift.
pub fn non_transparent_bounds(image: &RgbaImage) -> (u32, u32, u32, u32) {
    let (w, h) = image.dimensions();
    let mut min_x = w;
    let mut max_x = 0u32;
    let mut min_y = h;
    let mut max_y = 0u32;
    let mut found = false;
    for (x, y, pixel) in image.enumerate_pixels() {
        if pixel[3] > ALPHA_THRESHOLD {
            min_x = min_x.min(x);
            max_x = max_x.max(x);
            min_y = min_y.min(y);
            max_y = max_y.max(y);
            found = true;
        }
    }
    if !found || max_x < min_x || max_y < min_y {
        return (0, 0, w, h);
    }
    (min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
}

/// Scale `image` onto a square canvas of `canvas_px`, trimming transparent
/// margins first and filling `FILL_RATIO` of the canvas — port of
/// `IconService.prepareIconImage` (Swift used a 1024pt canvas, pixel dim
/// clamped to 2048..=4096; callers pass the pixel dimension they want).
pub fn prepare_icon_image(image: &RgbaImage, canvas_px: u32) -> RgbaImage {
    let (cx, cy, cw, ch) = non_transparent_bounds(image);
    let cropped: RgbaImage = if cw == image.width() && ch == image.height() {
        image.clone()
    } else {
        image::imageops::crop_imm(image, cx, cy, cw, ch).to_image()
    };
    let aspect = cw as f64 / ch.max(1) as f64;
    let max_dim = canvas_px as f64 * FILL_RATIO;
    let (dest_w, dest_h) = if aspect > 1.0 {
        (max_dim, max_dim / aspect)
    } else {
        (max_dim * aspect, max_dim)
    };
    let resized = image::imageops::resize(
        &cropped,
        dest_w.round() as u32,
        dest_h.round() as u32,
        image::imageops::FilterType::Lanczos3,
    );
    let mut canvas = RgbaImage::new(canvas_px, canvas_px);
    let ox = ((canvas_px as f64 - dest_w) / 2.0).round() as i64;
    let oy = ((canvas_px as f64 - dest_h) / 2.0).round() as i64;
    image::imageops::overlay(&mut canvas, &resized, ox, oy);
    canvas
}

/// Encode an image as PNG bytes (Swift: `NSImage.pngData`).
pub fn to_png_bytes(image: &RgbaImage) -> Result<Vec<u8>> {
    let mut buf = Vec::new();
    let encoder = image::codecs::png::PngEncoder::new(&mut buf);
    image::ImageEncoder::write_image(
        encoder,
        image.as_raw(),
        image.width(),
        image.height(),
        image::ExtendedColorType::Rgba8,
    )
    .map_err(|_| IconServiceError::InvalidImage)?;
    Ok(buf)
}

/// Resize to a square thumbnail (Swift `IconImageCache` scales to 128×128).
pub fn thumbnail(image: &RgbaImage, size: u32) -> RgbaImage {
    image::imageops::resize(image, size, size, image::imageops::FilterType::Lanczos3)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn trim_and_fill() {
        // 100×100, opaque 20×20 square in the middle.
        let mut img = RgbaImage::new(100, 100);
        for y in 40..60 {
            for x in 40..60 {
                img.put_pixel(x, y, Rgba([255, 0, 0, 255]));
            }
        }
        let (x, y, w, h) = non_transparent_bounds(&img);
        assert_eq!((x, y, w, h), (40, 40, 20, 20));
        let prepared = prepare_icon_image(&img, 128);
        assert_eq!(prepared.dimensions(), (128, 128));
        // Centre pixel should be red (the icon fills 96% of the canvas).
        assert_eq!(prepared.get_pixel(64, 64)[0], 255);
        assert!(prepared.get_pixel(0, 0)[3] == 0);
    }

    #[test]
    fn tint_keeps_alpha() {
        let mut img = RgbaImage::new(2, 1);
        img.put_pixel(0, 0, Rgba([10, 20, 30, 255]));
        img.put_pixel(1, 0, Rgba([0, 0, 0, 0]));
        let tinted = tint_image(&img, Rgb::from_hex("#00FF00").unwrap());
        assert_eq!(tinted.get_pixel(0, 0), &Rgba([0, 255, 0, 255]));
        assert_eq!(tinted.get_pixel(1, 0)[3], 0);
    }

    #[test]
    fn svg_rasterizes() {
        // Note: `fill="#ff0000"` contains `"#`, so this cannot be a
        // `r#"..."#` raw string — use a plain byte string.
        let svg = b"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\"><rect width=\"100\" height=\"100\" fill=\"#ff0000\"/></svg>";
        let img = rasterize_svg_bytes(svg, 64).unwrap();
        assert_eq!(img.dimensions(), (64, 64));
        assert_eq!(img.get_pixel(32, 32)[0], 255);
    }

    #[test]
    fn to_png_bytes_round_trip() {
        let mut img = RgbaImage::new(16, 16);
        img.put_pixel(8, 8, Rgba([255, 0, 0, 255]));
        let bytes = to_png_bytes(&img).expect("encode PNG");
        assert!(bytes.starts_with(b"\x89PNG\r\n\x1a\n"));
        let decoded = image::load_from_memory(&bytes)
            .expect("decode PNG")
            .to_rgba8();
        assert_eq!(decoded.dimensions(), (16, 16));
        assert_eq!(decoded.get_pixel(8, 8), &Rgba([255, 0, 0, 255]));
    }
}
