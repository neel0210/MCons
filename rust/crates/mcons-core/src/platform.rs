//! OS-specific folder-icon calls.
//!
//! macOS: `NSWorkspace.setIcon(_:forFile:options:)` — the same call Swift
//! uses. Implemented with the `cocoa` crate (AppKit bindings).
//! Other platforms: applying a Finder icon has no equivalent, so the
//! operation returns `IconServiceError::UnsupportedOnPlatform` with a clear
//! message instead of silently pretending it worked.

#![allow(unexpected_cfgs)]
#![allow(deprecated)]

use crate::error::{IconServiceError, Result};
use std::path::Path;

#[cfg(target_os = "macos")]
pub fn set_folder_icon(image_path: &Path, folder: &Path) -> Result<()> {
    use cocoa::appkit::NSImage;
    use cocoa::base::{id, nil};
    use cocoa::foundation::NSString;
    // `msg_send!` expands via `sel!`, so both macros must be in scope.
    use objc::{class, msg_send, sel, sel_impl};

    unsafe {
        let ns_path = NSString::alloc(nil).init_str(&image_path.to_string_lossy());
        let image: id = NSImage::alloc(nil).initWithContentsOfFile_(ns_path);
        if image == nil {
            return Err(IconServiceError::InvalidImage);
        }
        let ns_folder = NSString::alloc(nil).init_str(&folder.to_string_lossy());
        // cocoa 0.26 has no NSWorkspace binding, so call it directly:
        // [NSWorkspace.sharedWorkspace setIcon:forFile:options:].
        let workspace: id = msg_send![class!(NSWorkspace), sharedWorkspace];
        let ok: bool = msg_send![workspace, setIcon: image forFile: ns_folder options: 0usize];
        if ok {
            Ok(())
        } else {
            Err(IconServiceError::SetIconFailed {
                path: folder.to_string_lossy().into_owned(),
            })
        }
    }
}

#[cfg(target_os = "macos")]
pub fn reset_folder_icon(folder: &Path) -> Result<()> {
    use cocoa::base::{id, nil};
    use cocoa::foundation::NSString;
    use objc::{class, msg_send, sel, sel_impl};

    unsafe {
        let ns_folder = NSString::alloc(nil).init_str(&folder.to_string_lossy());
        let workspace: id = msg_send![class!(NSWorkspace), sharedWorkspace];
        let ok: bool = msg_send![workspace, setIcon: nil forFile: ns_folder options: 0usize];
        if ok {
            Ok(())
        } else {
            Err(IconServiceError::ResetIconFailed {
                path: folder.to_string_lossy().into_owned(),
            })
        }
    }
}

#[cfg(target_os = "windows")]
pub fn set_folder_icon(image_path: &Path, folder: &Path) -> Result<()> {
    let img = crate::images::load_image_file(image_path, 256)?;
    let ico_path = folder.join("custom_icon.ico");
    let mut ico_buf = Vec::new();
    let dyn_img = image::DynamicImage::ImageRgba8(img);
    dyn_img
        .write_to(
            &mut std::io::Cursor::new(&mut ico_buf),
            image::ImageFormat::Ico,
        )
        .map_err(|_| IconServiceError::InvalidImage)?;
    std::fs::write(&ico_path, &ico_buf).map_err(|_| IconServiceError::SetIconFailed {
        path: folder.to_string_lossy().into_owned(),
    })?;

    let ini_path = folder.join("desktop.ini");
    let ini_content = "[.ShellClassInfo]\r\nIconResource=custom_icon.ico,0\r\n[ViewState]\r\nMode=\r\nVid=\r\nFolderType=Generic\r\n";
    std::fs::write(&ini_path, ini_content).map_err(|_| IconServiceError::SetIconFailed {
        path: folder.to_string_lossy().into_owned(),
    })?;

    let _ = std::process::Command::new("attrib")
        .args(["+h", "+s"])
        .arg(&ini_path)
        .status();
    let _ = std::process::Command::new("attrib")
        .args(["+h"])
        .arg(&ico_path)
        .status();
    let _ = std::process::Command::new("attrib")
        .args(["+r"])
        .arg(folder)
        .status();

    refresh_finder(folder);
    Ok(())
}

#[cfg(target_os = "windows")]
pub fn reset_folder_icon(folder: &Path) -> Result<()> {
    let ini_path = folder.join("desktop.ini");
    let ico_path = folder.join("custom_icon.ico");
    let _ = std::process::Command::new("attrib")
        .args(["-h", "-s"])
        .arg(&ini_path)
        .status();
    let _ = std::fs::remove_file(&ini_path);
    let _ = std::fs::remove_file(&ico_path);
    let _ = std::process::Command::new("attrib")
        .args(["-r"])
        .arg(folder)
        .status();

    refresh_finder(folder);
    Ok(())
}

#[cfg(not(any(target_os = "macos", target_os = "windows")))]
pub fn set_folder_icon(_image_path: &Path, folder: &Path) -> Result<()> {
    Err(IconServiceError::UnsupportedOnPlatform(format!(
        "Setting a folder icon for '{}' is only supported on macOS and Windows.",
        folder.display()
    )))
}

#[cfg(not(any(target_os = "macos", target_os = "windows")))]
pub fn reset_folder_icon(folder: &Path) -> Result<()> {
    Err(IconServiceError::UnsupportedOnPlatform(format!(
        "Resetting a folder icon for '{}' is only supported on macOS and Windows.",
        folder.display()
    )))
}

/// Touch a folder's modification date so Finder refreshes its icon.
/// Port of `IconService.refreshFinder(for:)` — `FileManager.setAttributes`
/// with the current modification date.
pub fn refresh_finder(folder: &Path) {
    let now = std::time::SystemTime::now();
    let _ = filetime_touch(folder, now);
}

#[cfg(unix)]
fn filetime_touch(path: &Path, time: std::time::SystemTime) -> std::io::Result<()> {
    use std::os::unix::fs::MetadataExt;
    let _ = path.metadata().map(|m| m.mtime());
    // std has no utimens wrapper; use libc-free approach via `touch` is
    // avoided — instead update through OpenOptions set_times is unstable.
    // Fallback: create+remove a temp entry is wrong. Use the `filetime`
    // approach via std::fs::File::set_modified_times (stable since 1.75
    // on File, not on Dir). For a directory, open it read-only and set
    // times through the file handle where the OS allows it.
    let file = std::fs::File::open(path)?;
    file.set_modified(time)
}

#[cfg(not(unix))]
fn filetime_touch(path: &Path, time: std::time::SystemTime) -> std::io::Result<()> {
    let file = std::fs::File::open(path)?;
    file.set_modified(time)
}
