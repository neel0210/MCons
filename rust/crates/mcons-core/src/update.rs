//! Update checking — port of `UpdateService` in
//! `MCons/Core/Services/UpdateService.swift`.
//!
//! Same repo (`neel0210/MCons`), same GitHub Releases API URL and headers
//! (`Accept: application/vnd.github.v3+json`, `User-Agent: MCons-App`),
//! same `ReleaseInfo` fields, same version comparison (strip leading
//! `v`/`V`, compare numeric components, append the local build number
//! when the remote tag has more components), same installer script
//! (`/tmp/mcons_update.command` piping `install.sh` from `main`).

use serde::{Deserialize, Serialize};

pub const REPO: &str = "neel0210/MCons";
pub const CURRENT_VERSION: &str = "1.0.0";
pub const CURRENT_BUILD: &str = "1";
/// Stale hardcoded fallback zip in Swift's `installUpdateDirectly`
/// (`MCons-v1.0.4-release.zip`) — kept as-is, see `install_update_directly`.
pub const FALLBACK_ZIP_NAME: &str = "MCons-v1.0.4-release.zip";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ReleaseInfo {
    pub id: String,
    #[serde(rename = "tagName")]
    pub tag_name: String,
    pub name: String,
    pub body: String,
    #[serde(rename = "publishedAt")]
    pub published_at: String,
    #[serde(rename = "htmlURL")]
    pub html_url: Option<String>,
    #[serde(rename = "downloadURL")]
    pub download_url: Option<String>,
    #[serde(rename = "isPrerelease")]
    pub is_prerelease: bool,
}

impl ReleaseInfo {
    /// Swift `formattedDate`: ISO-8601 → medium date, or the raw string
    /// when it does not parse.
    pub fn formatted_date(&self) -> String {
        // ISO-8601 like 2026-11-01T12:00:00Z → "Nov 1, 2026".
        let date = self.published_at.get(..10).unwrap_or("");
        let parts: Vec<&str> = date.split('-').collect();
        if parts.len() == 3 {
            let months = [
                "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
            ];
            if let (Ok(y), Ok(m), Ok(d)) = (
                parts[0].parse::<u32>(),
                parts[1].parse::<usize>(),
                parts[2].parse::<u32>(),
            ) {
                if (1..=12).contains(&m) {
                    return format!("{} {}, {}", months[m - 1], d, y);
                }
            }
        }
        self.published_at.clone()
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum UpdateStatus {
    Idle,
    Checking,
    UpdateAvailable(ReleaseInfo),
    UpToDate,
    Error(String),
}

#[derive(Debug, Deserialize)]
struct GithubRelease {
    tag_name: String,
    name: Option<String>,
    body: Option<String>,
    published_at: Option<String>,
    html_url: Option<String>,
    prerelease: Option<bool>,
    assets: Option<Vec<GithubAsset>>,
}

#[derive(Debug, Deserialize)]
struct GithubAsset {
    browser_download_url: Option<String>,
}

pub fn is_version_newer(remote_tag: &str, current_version: &str, current_build: &str) -> bool {
    let clean_tag = remote_tag.trim_matches(|c| c == 'v' || c == 'V');
    let remote_parts: Vec<i64> = clean_tag
        .split('.')
        .filter_map(|p| p.parse().ok())
        .collect();
    let clean_current = current_version.trim_matches(|c| c == 'v' || c == 'V');
    let mut current_parts: Vec<i64> = clean_current
        .split('.')
        .filter_map(|p| p.parse().ok())
        .collect();
    if remote_parts.len() > current_parts.len() {
        current_parts.push(current_build.parse().unwrap_or(0));
    }
    for i in 0..remote_parts.len().max(current_parts.len()) {
        let r = remote_parts.get(i).copied().unwrap_or(0);
        let c = current_parts.get(i).copied().unwrap_or(0);
        if r > c {
            return true;
        }
        if r < c {
            return false;
        }
    }
    false
}

pub struct UpdateService {
    pub current_version: String,
    pub current_build: String,
}

impl Default for UpdateService {
    fn default() -> Self {
        Self {
            current_version: CURRENT_VERSION.to_string(),
            current_build: CURRENT_BUILD.to_string(),
        }
    }
}

impl UpdateService {
    pub fn current_full_version(&self) -> String {
        format!("v{}.{}", self.current_version, self.current_build)
    }

    /// Check GitHub Releases for a newer version. Returns the status and,
    /// when a release was found, its info. `silent` mirrors Swift: on
    /// failure a silent check returns `Idle` instead of `Error`.
    pub fn check_for_updates(&self, silent: bool) -> (UpdateStatus, Option<ReleaseInfo>) {
        let url = format!("https://api.github.com/repos/{REPO}/releases/latest");
        let response = ureq::get(&url)
            .set("Accept", "application/vnd.github.v3+json")
            .set("User-Agent", "MCons-App")
            .call();
        let response = match response {
            Ok(r) => r,
            Err(_) => {
                return if silent {
                    (UpdateStatus::Idle, None)
                } else {
                    (
                        UpdateStatus::Error("Failed to connect to update server".to_string()),
                        None,
                    )
                };
            }
        };
        if response.status() != 200 {
            return if silent {
                (UpdateStatus::Idle, None)
            } else {
                (
                    UpdateStatus::Error("Failed to connect to update server".to_string()),
                    None,
                )
            };
        }
        let release: GithubRelease = match response.into_json() {
            Ok(r) => r,
            Err(_) => {
                return (
                    UpdateStatus::Error("Malformed release metadata".to_string()),
                    None,
                );
            }
        };
        let info = ReleaseInfo {
            id: release.tag_name.clone(),
            tag_name: release.tag_name.clone(),
            name: release.name.unwrap_or_else(|| release.tag_name.clone()),
            body: release
                .body
                .unwrap_or_else(|| "No release notes provided.".to_string()),
            published_at: release.published_at.unwrap_or_default(),
            html_url: release.html_url,
            download_url: release
                .assets
                .and_then(|a| a.into_iter().next())
                .and_then(|a| a.browser_download_url),
            is_prerelease: release.prerelease.unwrap_or(false),
        };
        if is_version_newer(&info.tag_name, &self.current_version, &self.current_build) {
            (UpdateStatus::UpdateAvailable(info.clone()), Some(info))
        } else {
            (UpdateStatus::UpToDate, Some(info))
        }
    }

    /// Download the release zip and install it directly — port of
    /// `installUpdateDirectly()`. macOS only: `ditto -x -k` to extract,
    /// copy `MCons.app` to `/Applications` (else `~/Applications`),
    /// `xattr -cr`, then a relaunch script that waits for this process
    /// to exit and reopens the app. Progress is reported through `on_progress`
    /// with Swift's exact strings ("Downloading <tag>...", "Extracting...",
    /// "Installing...", "Relaunching MCons..."). On failure the caller
    /// should fall back to `write_installer_script` — Swift showed
    /// "Direct install failed. Opening Terminal...".
    pub fn install_update_directly(
        &self,
        release: &ReleaseInfo,
        mut on_progress: impl FnMut(&str),
    ) -> Result<(), String> {
        if !cfg!(target_os = "macos") {
            return Err("Direct install needs macOS".to_string());
        }
        let download_url = release.download_url.clone().unwrap_or_else(|| {
            format!(
                "https://github.com/{REPO}/releases/download/{}/{FALLBACK_ZIP_NAME}",
                release.tag_name
            )
        });
        on_progress(&format!("Downloading {}...", release.tag_name));
        let response = ureq::get(&download_url).call().map_err(|e| e.to_string())?;
        let mut zip_bytes = Vec::new();
        use std::io::Read;
        response
            .into_reader()
            .read_to_end(&mut zip_bytes)
            .map_err(|e| e.to_string())?;
        on_progress("Extracting...");
        let tmp_zip = std::env::temp_dir().join(format!("mcons-update-{}.zip", std::process::id()));
        std::fs::write(&tmp_zip, &zip_bytes).map_err(|e| e.to_string())?;
        let tmp_dir = std::env::temp_dir().join(format!("mcons-update-{}", std::process::id()));
        std::fs::create_dir_all(&tmp_dir).map_err(|e| e.to_string())?;
        let status = std::process::Command::new("/usr/bin/ditto")
            .args(["-x", "-k"])
            .arg(&tmp_zip)
            .arg(&tmp_dir)
            .status()
            .map_err(|e| e.to_string())?;
        if !status.success() {
            return Err("ditto failed to extract the update".to_string());
        }
        on_progress("Installing...");
        let mut extracted = tmp_dir.join("MCons.app");
        if !extracted.exists() {
            let found = std::fs::read_dir(&tmp_dir).ok().and_then(|mut it| {
                it.find_map(|e| {
                    let p = e.ok()?.path();
                    (p.file_name().map(|n| n == "MCons.app").unwrap_or(false)).then_some(p)
                })
            });
            extracted = found.ok_or("Extracted app not found")?;
        }
        let mut target_dir = std::path::PathBuf::from("/Applications");
        if std::fs::metadata(&target_dir)
            .map(|m| m.permissions().readonly())
            .unwrap_or(true)
        {
            target_dir = std::env::var("HOME")
                .map(|h| std::path::PathBuf::from(h).join("Applications"))
                .unwrap_or(target_dir);
            let _ = std::fs::create_dir_all(&target_dir);
        }
        let target_app = target_dir.join("MCons.app");
        let _ = std::fs::remove_dir_all(&target_app);
        std::fs::rename(&extracted, &target_app)
            .or_else(|_| {
                // Cross-device fallback: copy.
                copy_dir(&extracted, &target_app)
            })
            .map_err(|e| e.to_string())?;
        let _ = std::process::Command::new("/usr/bin/xattr")
            .args(["-cr"])
            .arg(&target_app)
            .status();
        on_progress("Relaunching MCons...");
        let pid = std::process::id();
        let target_path = target_app.to_string_lossy().replace('\'', "'\\''");
        let script = format!(
            "while kill -0 {pid} 2>/dev/null; do sleep 0.1; done; sleep 0.2; /usr/bin/xattr -cr '{target_path}' 2>/dev/null || true; /usr/bin/open '{target_path}'"
        );
        let _ = std::process::Command::new("/bin/sh")
            .args(["-c", &script])
            .spawn();
        std::process::exit(0);
    }

    /// Write `/tmp/mcons_update.command` (Swift's `launchInstallerInTerminal`)
    /// and return its path. The caller opens it in Terminal.
    pub fn installer_script_path() -> std::path::PathBuf {
        std::path::PathBuf::from("/tmp/mcons_update.command")
    }

    pub fn write_installer_script(&self) -> std::io::Result<std::path::PathBuf> {
        let path = Self::installer_script_path();
        let script = "echo \"==========================================\"\n\
            echo \"          \u{1f680} Updating MCons...            \"\n\
            echo \"==========================================\"\n\
            echo \"\"\n\
            curl -fsSL https://raw.githubusercontent.com/neel0210/MCons/main/install.sh | bash\n";
        std::fs::write(&path, format!("#!/bin/bash\n{script}"))?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755))?;
        }
        Ok(path)
    }
}

fn copy_dir(from: &std::path::Path, to: &std::path::Path) -> std::io::Result<()> {
    std::fs::create_dir_all(to)?;
    for entry in std::fs::read_dir(from)? {
        let entry = entry?;
        let dest = to.join(entry.file_name());
        if entry.file_type()?.is_dir() {
            copy_dir(&entry.path(), &dest)?;
        } else {
            std::fs::copy(entry.path(), dest)?;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_compare_matches_swift() {
        assert!(is_version_newer("v1.2.0", "1.1.0", "1"));
        assert!(!is_version_newer("v1.1.0", "1.1.0", "1"));
        assert!(!is_version_newer("v1.0.9", "1.1.0", "1"));
        // Remote 1.0.2.21 vs local 1.0.2 build 1 → newer.
        assert!(is_version_newer("1.0.2.21", "1.0.2", "1"));
        assert!(!is_version_newer("V1.1.0", "1.1.0", "1"));
    }
}
