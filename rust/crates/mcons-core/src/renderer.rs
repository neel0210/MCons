//! Programmatic folder icon rendering — port of `FolderIconRenderer` in
//! `MCons/Core/Models/FolderIconRenderer.swift`.
//!
//! Same geometry, same colours (Swift proportions, in fractions of `size`):
//! padding 2.5%, body 95% wide × 68% high at y=8%, corner radius 4.5%,
//! tab 38% wide × 12% high, back panel darkened 25% towards black, tab
//! darkened 10%, highlight lightened 30% towards white at 30% alpha over
//! the top 42% of the front panel, edge line lightened 15% at 50% alpha.
//!
//! Coordinate flip: CoreGraphics (Swift) has y=0 at the BOTTOM, y growing
//! upward; the `image` crate has y=0 at the TOP. Every rect is therefore
//! flipped: `y_rust = h - y_swift - rect_h`. Get this wrong and the folder
//! renders upside down (tab at the bottom).
//!
//! Deviation: Swift draws a blurred drop shadow via CoreGraphics; this port
//! draws a soft offset translucent silhouette instead (no blur kernel yet).
//! The shape, proportions and colours are identical.

use crate::color::Rgb;
use image::{Rgba, RgbaImage};

/// Render a coloured folder icon at `size`×`size` px. Cached by callers
/// (Swift kept an `NSCache` keyed `"<hex>_<size>"`).
pub fn render_folder_icon(color_hex: &str, size: u32) -> RgbaImage {
    let color = Rgb::from_hex(color_hex).unwrap_or_else(Rgb::system_blue);
    render_folder_icon_color(color, size)
}

pub fn render_folder_icon_color(color: Rgb, size: u32) -> RgbaImage {
    let w = size as f64;
    let h = size as f64;
    let mut img = RgbaImage::new(size, size);

    let padding = w * 0.025;
    let body_x = padding;
    let body_y = h * 0.08;
    let body_w = w - padding * 2.0;
    let body_h = h * 0.68;
    let radius = w * 0.045;
    let tab_w = body_w * 0.38;
    let tab_h = h * 0.12;
    let tab_radius = w * 0.035;

    let back = color.blended(0.25, Rgb::black());
    let tab = color.blended(0.10, Rgb::black());
    let highlight = color.blended(0.30, Rgb::white());
    let edge = color.blended(0.15, Rgb::white());

    // Swift (CoreGraphics) y values, y=0 at the bottom. `flip` converts
    // them to top-down image coordinates.
    let flip = |y: f64, rh: f64| h - y - rh;

    // Soft shadow silhouette under the body (Swift shadow offset (0, -2%w)
    // sits below the folder, i.e. further down the image).
    let shadow = Rgb::new(0.0, 0.0, 0.0, 0.25);
    fill_rounded_rect(
        &mut img,
        body_x,
        flip(body_y + body_h * 0.02, body_h + tab_h) + h * 0.02,
        body_w,
        body_h + tab_h,
        radius,
        shadow,
    );

    // Back panel (slightly darker, extends up behind the tab).
    fill_rounded_rect(
        &mut img,
        body_x,
        flip(body_y + body_h * 0.02, body_h + tab_h),
        body_w,
        body_h + tab_h,
        radius,
        back,
    );
    // Tab.
    fill_rounded_rect(
        &mut img,
        body_x + w * 0.04,
        flip(body_y + body_h - radius * 0.5, tab_h),
        tab_w,
        tab_h,
        tab_radius,
        tab,
    );
    // Front panel (main colour).
    fill_rounded_rect(
        &mut img,
        body_x,
        flip(body_y, body_h),
        body_w,
        body_h,
        radius,
        color,
    );
    // Highlight over the top of the front panel, 30% alpha.
    let mut hl = highlight;
    hl.a = 0.3;
    fill_rounded_rect(
        &mut img,
        body_x + w * 0.02,
        flip(body_y + body_h * 0.55, body_h * 0.42),
        body_w - w * 0.04,
        body_h * 0.42,
        radius * 0.8,
        hl,
    );
    // Subtle inner edge line, 50% alpha.
    let mut eg = edge;
    eg.a = 0.5;
    stroke_rounded_rect(
        &mut img,
        RoundedRect {
            x: body_x,
            y: flip(body_y, body_h),
            w: body_w,
            h: body_h,
            r: radius,
        },
        eg,
        (w * 0.004).max(1.0),
    );

    img
}

fn blend_pixel(dst: &mut Rgba<u8>, src: Rgb) {
    let [sr, sg, sb, sa] = src.to_rgba8();
    let a = sa as f64 / 255.0;
    if a <= 0.0 {
        return;
    }
    if a >= 1.0 {
        *dst = Rgba([sr, sg, sb, 255]);
        return;
    }
    for (i, v) in [sr, sg, sb].iter().enumerate() {
        dst[i] = ((*v as f64) * a + (dst[i] as f64) * (1.0 - a)).round() as u8;
    }
    dst[3] = 255;
}

fn in_rounded_rect(x: f64, y: f64, rx: f64, ry: f64, rw: f64, rh: f64, r: f64) -> bool {
    if x < rx || x >= rx + rw || y < ry || y >= ry + rh {
        return false;
    }
    let cx = (rx + r).min(rx + rw - r);
    let cy = (ry + r).min(ry + rh - r);
    let px = x.clamp(cx, rx + rw - r);
    let py = y.clamp(cy, ry + rh - r);
    let dx = x - px;
    let dy = y - py;
    dx * dx + dy * dy <= r * r
}

fn fill_rounded_rect(img: &mut RgbaImage, x: f64, y: f64, w: f64, h: f64, r: f64, color: Rgb) {
    let (iw, ih) = img.dimensions();
    let x0 = (x.floor() as i64).max(0);
    let y0 = (y.floor() as i64).max(0);
    let x1 = ((x + w).ceil() as i64).min(iw as i64);
    let y1 = ((y + h).ceil() as i64).min(ih as i64);
    for py in y0..y1 {
        for px in x0..x1 {
            if in_rounded_rect(px as f64 + 0.5, py as f64 + 0.5, x, y, w, h, r) {
                let pixel = img.get_pixel_mut(px as u32, py as u32);
                blend_pixel(pixel, color);
            }
        }
    }
}

struct RoundedRect {
    x: f64,
    y: f64,
    w: f64,
    h: f64,
    r: f64,
}

fn stroke_rounded_rect(img: &mut RgbaImage, rect: RoundedRect, color: Rgb, width: f64) {
    let (iw, ih) = img.dimensions();
    let x0 = (rect.x.floor() as i64).max(0);
    let y0 = (rect.y.floor() as i64).max(0);
    let x1 = ((rect.x + rect.w).ceil() as i64).min(iw as i64);
    let y1 = ((rect.y + rect.h).ceil() as i64).min(ih as i64);
    for py in y0..y1 {
        for px in x0..x1 {
            let cx = px as f64 + 0.5;
            let cy = py as f64 + 0.5;
            if in_rounded_rect(cx, cy, rect.x, rect.y, rect.w, rect.h, rect.r)
                && !in_rounded_rect(
                    cx,
                    cy,
                    rect.x + width,
                    rect.y + width,
                    rect.w - 2.0 * width,
                    rect.h - 2.0 * width,
                    (rect.r - width).max(0.0),
                )
            {
                let pixel = img.get_pixel_mut(px as u32, py as u32);
                blend_pixel(pixel, color);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn renders_blue_folder() {
        let img = render_folder_icon("#007AFF", 128);
        assert_eq!(img.dimensions(), (128, 128));
        // Centre of the front panel should be close to the base colour.
        let centre = img.get_pixel(64, 64);
        assert!(centre[2] > 200, "blue channel {centre:?}");
        assert!(centre[3] == 255);
        // Corners stay transparent.
        assert_eq!(img.get_pixel(0, 0)[3], 0);
        // Orientation (CoreGraphics y-flip): the tab sits at the TOP of
        // the icon, darker than the front panel below it.
        let tab = img.get_pixel(30, 25);
        let front = img.get_pixel(64, 100);
        assert!(
            tab[1] < front[1],
            "tab {tab:?} should be darker than front {front:?}"
        );
        assert!(front[2] > 200);
        // Highlight over the upper part of the front panel is lighter.
        let highlight = img.get_pixel(64, 40);
        assert!(
            highlight[1] > front[1],
            "highlight {highlight:?} vs front {front:?}"
        );
    }

    #[test]
    fn bad_hex_falls_back_to_blue() {
        let img = render_folder_icon("not-a-colour", 64);
        assert_eq!(img.dimensions(), (64, 64));
    }
}
