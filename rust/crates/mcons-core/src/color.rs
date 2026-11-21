//! Hex colour parsing and blending.
//!
//! Port of the `NSColor(hex:)` extension in
//! `MCons/Core/Extensions/Extensions.swift` plus the `blended(withFraction:of:)`
//! calls in `FolderIconRenderer`. Swift accepts 6-digit RGB and 8-digit RGBA
//! hex (with or without a leading `#`); anything else returns `None`.

/// An sRGB colour with components in `0.0..=1.0`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Rgb {
    pub r: f64,
    pub g: f64,
    pub b: f64,
    pub a: f64,
}

impl Rgb {
    pub const fn new(r: f64, g: f64, b: f64, a: f64) -> Self {
        Self { r, g, b, a }
    }

    /// Parse `#RRGGBB` / `RRGGBB` / `#RRGGBBAA` / `RRGGBBAA`.
    /// Mirrors `NSColor(hex:)`: whitespace trimmed, `#` stripped, then a
    /// hex scan; 6 or 8 digits only.
    pub fn from_hex(hex: &str) -> Option<Self> {
        let s = hex.trim().trim_start_matches('#');
        let v = u64::from_str_radix(s, 16).ok()?;
        match s.len() {
            6 => Some(Self {
                r: ((v & 0xFF0000) >> 16) as f64 / 255.0,
                g: ((v & 0x00FF00) >> 8) as f64 / 255.0,
                b: (v & 0x0000FF) as f64 / 255.0,
                a: 1.0,
            }),
            8 => Some(Self {
                r: ((v & 0xFF000000) >> 24) as f64 / 255.0,
                g: ((v & 0x00FF0000) >> 16) as f64 / 255.0,
                b: ((v & 0x0000FF00) >> 8) as f64 / 255.0,
                a: (v & 0x000000FF) as f64 / 255.0,
            }),
            _ => None,
        }
    }

    /// `self` blended towards `other` by `fraction` (Swift:
    /// `blended(withFraction:of:)`).
    pub fn blended(self, fraction: f64, other: Rgb) -> Rgb {
        let f = fraction.clamp(0.0, 1.0);
        Self {
            r: self.r + (other.r - self.r) * f,
            g: self.g + (other.g - self.g) * f,
            b: self.b + (other.b - self.b) * f,
            a: self.a + (other.a - self.a) * f,
        }
    }

    pub fn black() -> Self {
        Self::new(0.0, 0.0, 0.0, 1.0)
    }
    pub fn white() -> Self {
        Self::new(1.0, 1.0, 1.0, 1.0)
    }
    pub fn system_blue() -> Self {
        Self::from_hex("#007AFF").unwrap()
    }

    pub fn to_rgba8(self) -> [u8; 4] {
        [
            (self.r.clamp(0.0, 1.0) * 255.0).round() as u8,
            (self.g.clamp(0.0, 1.0) * 255.0).round() as u8,
            (self.b.clamp(0.0, 1.0) * 255.0).round() as u8,
            (self.a.clamp(0.0, 1.0) * 255.0).round() as u8,
        ]
    }

    pub fn to_hex(self) -> String {
        let [r, g, b, _] = self.to_rgba8();
        format!("#{r:02X}{g:02X}{b:02X}")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hex_rgb_and_rgba() {
        assert_eq!(Rgb::from_hex("#FF5733").unwrap().to_hex(), "#FF5733");
        assert_eq!(Rgb::from_hex("007AFF").unwrap().to_hex(), "#007AFF");
        let c = Rgb::from_hex("#FF000080").unwrap();
        assert!((c.a - 128.0 / 255.0).abs() < 0.01);
        assert!(Rgb::from_hex("#FFF").is_none());
        assert!(Rgb::from_hex("not-a-colour").is_none());
    }

    #[test]
    fn blend_matches_swift_semantics() {
        // #007AFF has r=0 already, so only g/b can fall when blending to black.
        let blue = Rgb::system_blue();
        let darker = blue.blended(0.25, Rgb::black());
        assert!(darker.g < blue.g && darker.b < blue.b);
        assert!((darker.g - 122.0 * 0.75 / 255.0).abs() < 0.01);
    }
}
