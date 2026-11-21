//! `mcons` — the MCons operations from the terminal.
//!
//! Every subcommand mirrors a flow from the Swift app:
//! `packs`/`icons` (IconPacksView), `apply`/`reset` (IconApplyView +
//! AppState.applyAtomicOperation), `batch` (BatchApplyView),
//! `export` (IconExportService), `build-pack` (PackBuilderView),
//! `check-update` (UpdateService), `favorites` (AppState favourites).

use clap::{Parser, Subcommand};
use mcons_core::{
    export::{self, ExportFormat},
    folder::FolderService,
    models::FolderIcon,
    pack_builder::{build_custom_pack, PackBuilderInput},
    pack_loader::IconPackLoader,
    update::UpdateService,
    AppState, Settings,
};
use std::path::PathBuf;

#[derive(Parser)]
#[command(
    name = "mcons",
    version,
    about = "MCons — custom folder icons, in Rust"
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// List all icon packs (bundled + custom + macOS Native+).
    Packs,
    /// List icons in a pack.
    Icons {
        /// Pack id, e.g. demon-slayer
        pack: String,
    },
    /// Apply an icon to a folder, optionally renaming it first.
    /// Same atomic rename-then-apply as the Swift app, with rollback.
    Apply {
        /// Icon id, e.g. demon-slayer_Tanjiro
        icon: String,
        /// Target folder
        folder: PathBuf,
        /// Rename the folder/app to this name first
        #[arg(long)]
        rename_to: Option<String>,
        /// Tint the icon, e.g. #FF5733
        #[arg(long)]
        tint: Option<String>,
    },
    /// Reset a folder to its default icon.
    Reset { folder: PathBuf },
    /// Apply the same icon to every folder in a directory.
    Batch {
        /// Icon id
        icon: String,
        /// Parent directory whose subfolders get the icon
        directory: PathBuf,
    },
    /// Export an icon as PNG (1024×1024), ICNS, or original SVG.
    Export {
        /// Icon id
        icon: String,
        /// png | icns | svg
        #[arg(long, default_value = "png")]
        format: String,
        /// Destination file
        dest: PathBuf,
    },
    /// Build a custom pack from icon files.
    BuildPack {
        /// Pack id
        id: String,
        /// Display name
        name: String,
        /// Icon files to include
        #[arg(required = true)]
        files: Vec<PathBuf>,
        #[arg(long, default_value = "Custom folder icon pack")]
        description: String,
        #[arg(long, default_value = "📁")]
        emoji: String,
        #[arg(long, default_value = "#6C5CE7")]
        accent: String,
    },
    /// List favourite icons.
    Favorites,
    /// Toggle a favourite.
    Favorite {
        /// Icon id
        icon: String,
    },
    /// Check GitHub Releases for a newer version.
    CheckUpdate,
    /// Render a programmatic colour folder icon to PNG (macOS Native+).
    RenderColor {
        /// Hex colour, e.g. #007AFF
        hex: String,
        /// Output PNG
        dest: PathBuf,
        #[arg(long, default_value_t = 1024)]
        size: u32,
    },
}

fn find_icon(packs: &[mcons_core::IconPack], id: &str) -> Option<FolderIcon> {
    packs
        .iter()
        .flat_map(|p| p.icons.iter().cloned())
        .find(|i| i.id == id)
}

fn main() {
    let cli = Cli::parse();
    let loader = IconPackLoader;
    let packs = loader.load_all_packs();
    let folder_service = FolderService;

    match cli.command {
        Command::Packs => {
            for pack in &packs {
                println!(
                    "{:28} {:3} icons  {}  {}  [{}]",
                    pack.id,
                    pack.icon_count(),
                    pack.emoji,
                    pack.name,
                    pack.category()
                );
            }
            println!(
                "{} packs, {} icons",
                packs.len(),
                packs.iter().map(|p| p.icon_count()).sum::<usize>()
            );
        }
        Command::Icons { pack } => {
            let Some(p) = packs.iter().find(|p| p.id == pack) else {
                eprintln!("No pack with id '{pack}'");
                std::process::exit(1);
            };
            for icon in &p.icons {
                println!("{:45} {}", icon.id, icon.name);
            }
        }
        Command::Apply {
            icon,
            folder,
            rename_to,
            tint,
        } => {
            let Some(icon) = find_icon(&packs, &icon) else {
                eprintln!("No icon with id '{icon}'");
                std::process::exit(1);
            };
            let mut state = AppState::new();
            let name = rename_to.unwrap_or_else(|| {
                folder
                    .file_name()
                    .map(|n| n.to_string_lossy().into_owned())
                    .unwrap_or_default()
            });
            if state.apply_atomic_operation(&icon, &folder, &name, tint.as_deref()) {
                println!("{}", state.status_message);
            } else {
                eprintln!("{}", state.status_message);
                if let Some(err) = &state.current_error {
                    eprintln!("{} — {}", err, err.failure_reason());
                    eprintln!("{}", err.recovery_suggestion());
                }
                std::process::exit(1);
            }
        }
        Command::Reset { folder } => {
            let mut state = AppState::new();
            if state.reset_icon(&folder) {
                println!("{}", state.status_message);
            } else {
                eprintln!("{}", state.status_message);
                std::process::exit(1);
            }
        }
        Command::Batch { icon, directory } => {
            let Some(icon) = find_icon(&packs, &icon) else {
                eprintln!("No icon with id '{icon}'");
                std::process::exit(1);
            };
            let folders = folder_service.folders_in_directory(&directory);
            let mut state = AppState::new();
            let mut ok = 0;
            for folder in &folders {
                if state.apply_icon(&icon, folder) {
                    ok += 1;
                } else {
                    eprintln!("Failed for {}: {}", folder.display(), state.status_message);
                }
            }
            println!("Applied to {ok}/{} folders", folders.len());
            if ok != folders.len() {
                std::process::exit(1);
            }
        }
        Command::Export { icon, format, dest } => {
            let Some(icon) = find_icon(&packs, &icon) else {
                eprintln!("No icon with id '{icon}'");
                std::process::exit(1);
            };
            let fmt = match format.as_str() {
                "png" => ExportFormat::Png,
                "icns" => ExportFormat::Icns,
                "svg" => ExportFormat::Svg,
                other => {
                    eprintln!("Unknown format '{other}' (png | icns | svg)");
                    std::process::exit(1);
                }
            };
            match export::export(&icon, fmt, &dest, None) {
                Ok(()) => println!("Exported {} to {}", icon.name, dest.display()),
                Err(e) => {
                    eprintln!("Export failed: {e}");
                    std::process::exit(1);
                }
            }
        }
        Command::BuildPack {
            id,
            name,
            files,
            description,
            emoji,
            accent,
        } => match build_custom_pack(&PackBuilderInput {
            id,
            name,
            description,
            emoji,
            accent_color_hex: accent,
            icon_files: files,
        }) {
            Ok(dir) => println!("Pack created at {}", dir.display()),
            Err(e) => {
                eprintln!("Failed to build pack: {e}");
                std::process::exit(1);
            }
        },
        Command::Favorites => {
            let state = AppState::new();
            for icon in state.favorite_icons() {
                println!("{:45} {}", icon.id, icon.name);
            }
        }
        Command::Favorite { icon } => {
            let mut settings = Settings::load();
            settings.toggle_favorite(&icon);
            println!(
                "{} is now {}",
                icon,
                if settings.is_favorite(&icon) {
                    "a favourite"
                } else {
                    "not a favourite"
                }
            );
        }
        Command::CheckUpdate => {
            let svc = UpdateService::default();
            let (status, release) = svc.check_for_updates(false);
            println!("Current: {}", svc.current_full_version());
            match status {
                mcons_core::update::UpdateStatus::UpdateAvailable(r) => {
                    println!("Update available: {} ({})", r.tag_name, r.name);
                    if let Some(url) = r.html_url {
                        println!("{url}");
                    }
                }
                mcons_core::update::UpdateStatus::UpToDate => println!("Up to date."),
                mcons_core::update::UpdateStatus::Error(e) => {
                    eprintln!("Update check failed: {e}");
                    std::process::exit(1);
                }
                _ => {
                    let _ = release;
                    println!("No update information.");
                }
            }
        }
        Command::RenderColor { hex, dest, size } => {
            let img = mcons_core::renderer::render_folder_icon(&hex, size);
            let png = mcons_core::images::to_png_bytes(&img).unwrap_or_default();
            if std::fs::write(&dest, png).is_ok() {
                println!("Wrote {} ({}×{})", dest.display(), size, size);
            } else {
                eprintln!("Failed to write {}", dest.display());
                std::process::exit(1);
            }
        }
    }
}
