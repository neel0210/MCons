//! Strongly typed icon errors.
//!
//! Port of `IconServiceError` in `MCons/Core/Services/IconService.swift`
//! — same cases, same user-facing descriptions, failure reasons and
//! recovery suggestions.

use thiserror::Error;

#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum IconServiceError {
    #[error("Folder Not Found")]
    FolderNotFound { path: String },
    #[error("Permission Denied")]
    PermissionDenied { path: String },
    #[error("Invalid Icon Image")]
    InvalidImage,
    #[error("Failed to Set Folder Icon")]
    SetIconFailed { path: String },
    #[error("Failed to Reset Folder Icon")]
    ResetIconFailed { path: String },
    #[error("Unexpected Icon Error")]
    Unknown(String),
    /// The operation needs macOS AppKit and this binary is not on macOS.
    #[error("macOS-only operation")]
    UnsupportedOnPlatform(String),
}

impl IconServiceError {
    /// Swift `id` — used as the alert identifier.
    pub fn id(&self) -> String {
        match self {
            Self::FolderNotFound { path } => format!("fnf_{path}"),
            Self::PermissionDenied { path } => format!("pd_{path}"),
            Self::InvalidImage => "inv_img".to_string(),
            Self::SetIconFailed { path } => format!("sif_{path}"),
            Self::ResetIconFailed { path } => format!("rif_{path}"),
            Self::Unknown(msg) => format!("unk_{msg}"),
            Self::UnsupportedOnPlatform(msg) => format!("unsupported_{msg}"),
        }
    }

    pub fn failure_reason(&self) -> String {
        match self {
            Self::FolderNotFound { path } => {
                format!("No directory exists at path: '{path}'.")
            }
            Self::PermissionDenied { path } => {
                format!("MCons does not have write permissions for folder at path: '{path}'.")
            }
            Self::InvalidImage => {
                "The selected icon image could not be loaded or processed.".to_string()
            }
            Self::SetIconFailed { path } => {
                format!(
                    "macOS system call NSWorkspace.setIcon failed for folder at path: '{path}'."
                )
            }
            Self::ResetIconFailed { path } => {
                format!("macOS system call NSWorkspace.setIcon(nil) failed for folder at path: '{path}'.")
            }
            Self::Unknown(message) => message.clone(),
            Self::UnsupportedOnPlatform(message) => message.clone(),
        }
    }

    pub fn recovery_suggestion(&self) -> &'static str {
        match self {
            Self::FolderNotFound { .. } => "Please select a valid folder that exists on your Mac.",
            Self::PermissionDenied { .. } => "Check folder permissions in Finder (Get Info > Sharing & Permissions) or select a folder in your User directory.",
            Self::InvalidImage => "Try selecting a different image or an icon from one of the bundled icon packs.",
            Self::SetIconFailed { .. } | Self::ResetIconFailed { .. } => {
                "Ensure the folder is not locked or on a read-only volume, then try again."
            }
            Self::Unknown(_) => "Please try restarting MCons or choosing a different target folder.",
            Self::UnsupportedOnPlatform(_) => {
                "This operation needs macOS. Run MCons on a Mac to apply folder icons."
            }
        }
    }
}

pub type Result<T> = std::result::Result<T, IconServiceError>;
