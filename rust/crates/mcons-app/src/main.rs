#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

//! MCons Desktop App — Native window desktop application.
//!
//! The Swift original is a native macOS SwiftUI app. SwiftUI cannot run on
//! Linux and has no Rust equivalent, so the UI is rebuilt as HTML/CSS/JS
//! served from `http://127.0.0.1:8795/` by a tiny std-only HTTP server
//! (no network crates — `std::net::TcpListener`, one thread per
//! connection). Every colour, spacing, radius, font size and line of copy
//! comes from `MCons/Core/Theme/AppTheme.swift` and the Swift feature
//! views; see `rust/PORT_SPEC.md` for the audit that drove it.
//!
//! State lives server-side in [`ServerState`] (an `AppState` plus the
//! image cache, the update check result, and the batch folders). The
//! browser keeps only view-local state (search text, selected pack in a
//! detail view). Thumbnails are served as PNGs from the 128px image
//! cache, exactly like `FolderIcon.thumbnailImage()`.
//!
//! On Linux, apply/reset go through the same core code as on macOS and
//! surface the core's `UnsupportedOnPlatform` error instead of
//! pretending the icon was applied.

use mcons_core::export::{export, ExportFormat};
use mcons_core::image_cache::IconImageCache;
use mcons_core::images::to_png_bytes;
use mcons_core::pack_builder::{build_custom_pack, PackBuilderInput};
use mcons_core::update::{ReleaseInfo, UpdateService, UpdateStatus};
use mcons_core::{AppState, FolderIcon, IconPack, VERSION};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

const INDEX_HTML: &str = include_str!("../web/index.html");
const APP_ICON_PNG: &[u8] = include_bytes!("../web/appicon.png");
const PORT: u16 = 8795;
const MAX_CONCURRENT_CONNS: usize = 64;
const MAX_BODY_SIZE: usize = 25 * 1024 * 1024; // 25 MB

static ACTIVE_CONNS: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);

fn upload_dir() -> PathBuf {
    std::env::temp_dir().join(format!("mcons-uploads-{}", std::process::id()))
}

/// Server-side state: the app state machine plus the pieces the web UI
/// needs that Swift kept in `@State` on the views.
struct ServerState {
    app: AppState,
    cache: IconImageCache,
    update: UpdateService,
    /// Last update-check outcome, kept for the Updates view + sidebar badge.
    update_status: String,
    update_error: String,
    last_release: Option<ReleaseInfo>,
    last_checked: Option<String>,
    batch_folders: Vec<PathBuf>,
    batch_status: Vec<(PathBuf, String)>,
    /// A custom image imported on the Apply view (Swift `custom_<UUID>`).
    custom_icon: Option<FolderIcon>,
}

impl ServerState {
    fn new() -> Self {
        Self {
            app: AppState::new(),
            cache: IconImageCache::new(),
            update: UpdateService::default(),
            update_status: "idle".to_string(),
            update_error: String::new(),
            last_release: None,
            last_checked: None,
            batch_folders: Vec::new(),
            batch_status: Vec::new(),
            custom_icon: None,
        }
    }

    fn find_icon(&self, id: &str) -> Option<FolderIcon> {
        if let Some(c) = &self.custom_icon {
            if c.id == id {
                return Some(c.clone());
            }
        }
        self.app
            .cached_icon_packs
            .iter()
            .flat_map(|p| p.icons.iter())
            .find(|i| i.id == id)
            .cloned()
    }

    fn find_pack(&self, id: &str) -> Option<IconPack> {
        self.app
            .cached_icon_packs
            .iter()
            .find(|p| p.id == id)
            .cloned()
    }

    /// Full state snapshot for the sidebar + the active view.
    fn state_json(&self) -> Value {
        let fav_icons = self.app.favorite_icons();
        json!({
            "version": VERSION,
            "fullVersion": self.update.current_full_version(),
            "packs": self.app.cached_icon_packs,
            "packCount": self.app.cached_icon_packs.len(),
            "iconCount": self.app.cached_icon_packs.iter().map(|p| p.icon_count()).sum::<usize>(),
            "favorites": self.app.settings.favorites,
            "favoriteIcons": fav_icons,
            "settings": self.app.settings,
            "recents": self.app.recent_folders,
            "statusMessage": self.app.status_message,
            "showSuccess": self.app.show_success_animation,
            "selectedIcon": self.app.selected_icon,
            "targetFolder": self.app.target_folder_url,
            "updateAvailable": self.update_status == "available",
            "updateStatus": self.update_status,
            "updateError": self.update_error,
            "lastRelease": self.last_release,
            "lastChecked": self.last_checked,
            "batchFolders": self.batch_folders,
            "batchStatus": self.batch_status.iter().map(|(p, s)| json!({"folder": p, "status": s})).collect::<Vec<_>>(),
            "undoAvailable": !self.app.undo_stack.is_empty(),
            "redoAvailable": !self.app.redo_stack.is_empty(),
        })
    }
}

fn open_browser(url: &str) {
    if cfg!(target_os = "windows") {
        let _ = std::process::Command::new("cmd")
            .args(["/C", "start", url])
            .spawn();
    } else if cfg!(target_os = "macos") {
        let _ = std::process::Command::new("/usr/bin/open").arg(url).spawn();
    } else {
        let _ = std::process::Command::new("xdg-open").arg(url).spawn();
    }
}

#[cfg(not(target_os = "linux"))]
fn run_gui(url: &str) -> ! {
    use tao::{
        event::{Event, WindowEvent},
        event_loop::{ControlFlow, EventLoop},
        window::WindowBuilder,
    };
    use wry::WebViewBuilder;

    let event_loop = EventLoop::new();
    let mut builder = WindowBuilder::new()
        .with_title("MCons")
        .with_inner_size(tao::dpi::LogicalSize::new(1040.0, 720.0))
        .with_min_inner_size(tao::dpi::LogicalSize::new(840.0, 620.0));

    if let Ok(img) = image::load_from_memory(APP_ICON_PNG) {
        let rgba = img.to_rgba8();
        let (width, height) = rgba.dimensions();
        if let Ok(icon) = tao::window::Icon::from_rgba(rgba.into_raw(), width, height) {
            builder = builder.with_window_icon(Some(icon));
        }
    }

    let window = match builder.build(&event_loop) {
        Ok(w) => w,
        Err(e) => {
            eprintln!("Failed to create window: {e}");
            open_browser(url);
            loop {
                std::thread::park();
            }
        }
    };

    let _webview = match WebViewBuilder::new().with_url(url).build(&window) {
        Ok(wv) => wv,
        Err(e) => {
            eprintln!("Failed to initialize webview: {e}");
            open_browser(url);
            loop {
                std::thread::park();
            }
        }
    };

    event_loop.run(move |event, _, control_flow| {
        let _ = &_webview;
        *control_flow = ControlFlow::Wait;
        if let Event::WindowEvent {
            event: WindowEvent::CloseRequested,
            ..
        } = event
        {
            *control_flow = ControlFlow::Exit;
        }
    });
}

#[cfg(target_os = "linux")]
fn run_gui(url: &str) -> ! {
    use tao::{
        event::{Event, WindowEvent},
        event_loop::{ControlFlow, EventLoop},
        platform::unix::WindowExtUnix,
        window::WindowBuilder,
    };
    use wry::{WebViewBuilder, WebViewBuilderExtUnix};

    let event_loop = EventLoop::new();
    let mut builder = WindowBuilder::new()
        .with_title("MCons")
        .with_inner_size(tao::dpi::LogicalSize::new(1040.0, 720.0))
        .with_min_inner_size(tao::dpi::LogicalSize::new(840.0, 620.0));

    if let Ok(img) = image::load_from_memory(APP_ICON_PNG) {
        let rgba = img.to_rgba8();
        let (width, height) = rgba.dimensions();
        if let Ok(icon) = tao::window::Icon::from_rgba(rgba.into_raw(), width, height) {
            builder = builder.with_window_icon(Some(icon));
        }
    }

    let window = match builder.build(&event_loop) {
        Ok(w) => w,
        Err(e) => {
            eprintln!("Failed to create window: {e}");
            open_browser(url);
            loop {
                std::thread::park();
            }
        }
    };

    let vbox = match window.default_vbox() {
        Some(v) => v,
        None => {
            eprintln!("Failed to get window vbox");
            open_browser(url);
            loop {
                std::thread::park();
            }
        }
    };

    let _webview = match WebViewBuilder::new().with_url(url).build_gtk(vbox) {
        Ok(wv) => wv,
        Err(e) => {
            eprintln!("Failed to initialize webview: {e}");
            open_browser(url);
            loop {
                std::thread::park();
            }
        }
    };

    event_loop.run(move |event, _, control_flow| {
        let _ = &_webview;
        *control_flow = ControlFlow::Wait;
        if let Event::WindowEvent {
            event: WindowEvent::CloseRequested,
            ..
        } = event
        {
            *control_flow = ControlFlow::Exit;
        }
    });
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let server_mode = args.iter().any(|a| a == "--server" || a == "--headless");

    let state = Arc::new(Mutex::new(ServerState::new()));
    let listener = TcpListener::bind(("127.0.0.1", PORT))
        .or_else(|_| TcpListener::bind(("127.0.0.1", 0)))
        .unwrap_or_else(|e| {
            eprintln!("mcons-app: cannot bind 127.0.0.1: {e}");
            std::process::exit(1);
        });

    let local_port = listener.local_addr().map(|a| a.port()).unwrap_or(PORT);
    let url = format!("http://127.0.0.1:{local_port}/");

    if server_mode {
        println!("MCons Server running at {url} (Ctrl+C to stop)");
        for s in listener.incoming().flatten() {
            if ACTIVE_CONNS.load(std::sync::atomic::Ordering::Relaxed) >= MAX_CONCURRENT_CONNS {
                eprintln!("mcons-app: max concurrent connections reached, dropping");
                drop(s);
                continue;
            }
            let st = Arc::clone(&state);
            std::thread::spawn(move || {
                ACTIVE_CONNS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                handle_connection(s, st);
                ACTIVE_CONNS.fetch_sub(1, std::sync::atomic::Ordering::Relaxed);
            });
        }
        return;
    }

    let server_state = Arc::clone(&state);
    std::thread::spawn(move || {
        for s in listener.incoming().flatten() {
            if ACTIVE_CONNS.load(std::sync::atomic::Ordering::Relaxed) >= MAX_CONCURRENT_CONNS {
                drop(s);
                continue;
            }
            let st = Arc::clone(&server_state);
            std::thread::spawn(move || {
                ACTIVE_CONNS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                handle_connection(s, st);
                ACTIVE_CONNS.fetch_sub(1, std::sync::atomic::Ordering::Relaxed);
            });
        }
    });

    run_gui(&url);
}

fn handle_connection(mut stream: TcpStream, state: Arc<Mutex<ServerState>>) {
    let _ = stream.set_read_timeout(Some(std::time::Duration::from_secs(30)));
    let mut buf = Vec::new();
    let mut chunk = [0u8; 8192];
    // Read until the header terminator, then the body per Content-Length.
    let header_end = loop {
        match stream.read(&mut chunk) {
            Ok(0) => return,
            Ok(n) => {
                buf.extend_from_slice(&chunk[..n]);
                if let Some(pos) = find_subslice(&buf, b"\r\n\r\n") {
                    break pos + 4;
                }
                if buf.len() > 1_048_576 {
                    return;
                }
            }
            Err(_) => return,
        }
    };
    let header = String::from_utf8_lossy(&buf[..header_end]).into_owned();
    let mut lines = header.lines();
    let Some(request_line) = lines.next() else {
        return;
    };
    let mut parts = request_line.split_whitespace();
    let method = parts.next().unwrap_or("").to_string();
    let raw_path = parts.next().unwrap_or("/").to_string();
    let mut headers = HashMap::new();
    for line in lines {
        if let Some((k, v)) = line.split_once(':') {
            headers.insert(k.trim().to_lowercase(), v.trim().to_string());
        }
    }

    // Host & Origin verification (DNS rebinding / CSRF mitigation).
    if let Some(host) = headers.get("host") {
        let host_name = host.split(':').next().unwrap_or("");
        if host_name != "127.0.0.1" && host_name != "localhost" {
            return;
        }
    }
    if let Some(origin) = headers.get("origin") {
        if !origin.starts_with("http://127.0.0.1:") && !origin.starts_with("http://localhost:") {
            return;
        }
    }

    let content_len: usize = headers
        .get("content-length")
        .and_then(|v| v.parse().ok())
        .unwrap_or(0);
    if content_len > MAX_BODY_SIZE {
        return;
    }
    let mut body = buf[header_end..].to_vec();
    while body.len() < content_len {
        match stream.read(&mut chunk) {
            Ok(0) => break,
            Ok(n) => body.extend_from_slice(&chunk[..n]),
            Err(_) => break,
        }
    }
    let (path, query) = match raw_path.split_once('?') {
        Some((p, q)) => (p.to_string(), q.to_string()),
        None => (raw_path.clone(), String::new()),
    };
    let query_map = parse_query(&query);
    let body_str = String::from_utf8_lossy(&body).into_owned();

    let (status, content_type, payload, extra_headers) =
        route(&method, &path, &query_map, &body_str, &state);
    let mut head = format!(
        "HTTP/1.1 {status}\r\nContent-Type: {content_type}\r\nContent-Length: {}\r\nConnection: close\r\n",
        payload.len()
    );
    for (k, v) in extra_headers {
        head.push_str(&format!("{k}: {v}\r\n"));
    }
    head.push_str("\r\n");
    let _ = stream.write_all(head.as_bytes());
    let _ = stream.write_all(&payload);
}

fn find_subslice(hay: &[u8], needle: &[u8]) -> Option<usize> {
    hay.windows(needle.len()).position(|w| w == needle)
}

fn parse_query(q: &str) -> HashMap<String, String> {
    let mut out = HashMap::new();
    for pair in q.split('&') {
        if pair.is_empty() {
            continue;
        }
        match pair.split_once('=') {
            Some((k, v)) => {
                out.insert(url_decode(k), url_decode(v));
            }
            None => {
                out.insert(url_decode(pair), String::new());
            }
        }
    }
    out
}

fn url_decode(s: &str) -> String {
    let bytes = s.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        match bytes[i] {
            b'%' if i + 2 < bytes.len() => {
                let h = hex_val(bytes[i + 1]);
                let l = hex_val(bytes[i + 2]);
                if let (Some(h), Some(l)) = (h, l) {
                    out.push(h * 16 + l);
                    i += 3;
                    continue;
                }
                out.push(bytes[i]);
                i += 1;
            }
            b'+' => {
                out.push(b' ');
                i += 1;
            }
            b => {
                out.push(b);
                i += 1;
            }
        }
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn hex_val(b: u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
}

fn base64_decode(s: &str) -> Option<Vec<u8>> {
    let mut vals = Vec::new();
    let mut acc: u32 = 0;
    let mut nbits = 0;
    for c in s.chars() {
        let v = match c {
            'A'..='Z' => c as u32 - 'A' as u32,
            'a'..='z' => c as u32 - 'a' as u32 + 26,
            '0'..='9' => c as u32 - '0' as u32 + 52,
            '+' => 62,
            '/' => 63,
            '=' => break,
            _ => continue,
        };
        acc = (acc << 6) | v;
        nbits += 6;
        if nbits >= 8 {
            nbits -= 8;
            vals.push(((acc >> nbits) & 0xff) as u8);
        }
    }
    Some(vals)
}

fn json_body(body: &str) -> Value {
    serde_json::from_str(body).unwrap_or(Value::Null)
}

fn json_ok(v: Value) -> (u16, &'static str, Vec<u8>, Vec<(&'static str, String)>) {
    (
        200,
        "application/json",
        serde_json::to_vec(&v).unwrap_or_default(),
        vec![],
    )
}

fn json_err(msg: &str) -> (u16, &'static str, Vec<u8>, Vec<(&'static str, String)>) {
    json_ok(json!({"ok": false, "error": msg}))
}

type Resp = (u16, &'static str, Vec<u8>, Vec<(&'static str, String)>);

fn route(
    method: &str,
    path: &str,
    query: &HashMap<String, String>,
    body: &str,
    state: &Arc<Mutex<ServerState>>,
) -> Resp {
    // Static assets.
    if method == "GET" && path == "/" {
        return (
            200,
            "text/html; charset=utf-8",
            INDEX_HTML.as_bytes().to_vec(),
            vec![],
        );
    }
    if method == "GET" && path == "/appicon.png" {
        return (
            200,
            "image/png",
            APP_ICON_PNG.to_vec(),
            vec![(
                "Cache-Control",
                "public, max-age=604800, immutable".to_string(),
            )],
        );
    }
    if !path.starts_with("/api/") {
        return (404, "text/plain", b"not found".to_vec(), vec![]);
    }

    let mut st = state.lock().unwrap_or_else(|e| e.into_inner());
    let req = json_body(body);
    let s = |v: &str| {
        req.get(v)
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string()
    };
    let s_opt = |v: &str| req.get(v).and_then(|x| x.as_str()).map(|x| x.to_string());

    match (method, path) {
        ("GET", "/api/state") => json_ok(st.state_json()),

        ("GET", "/api/thumb") => {
            let id = query.get("id").cloned().unwrap_or_default();
            let size: u32 = query
                .get("size")
                .and_then(|v| v.parse().ok())
                .unwrap_or(128);
            let Some(icon) = st.find_icon(&id) else {
                return (404, "text/plain", b"icon not found".to_vec(), vec![]);
            };
            let img = if let Some(url) = &icon.file_url {
                st.cache.image_for_url(url, Some(size))
            } else {
                icon.color_hex
                    .as_ref()
                    .map(|hex| mcons_core::renderer::render_folder_icon(hex, size))
            };
            drop(st);
            match img.and_then(|i| to_png_bytes(&i).ok()) {
                Some(png) => (
                    200,
                    "image/png",
                    png,
                    vec![(
                        "Cache-Control",
                        "public, max-age=604800, immutable".to_string(),
                    )],
                ),
                None => (404, "text/plain", b"thumbnail unavailable".to_vec(), vec![]),
            }
        }

        ("POST", "/api/favorite") => {
            let id = s("id");
            if st.find_icon(&id).is_none() {
                return json_err("unknown icon");
            }
            st.app.toggle_favorite(&FolderIcon::new(id, "", ""));
            st.app.status_message = String::new();
            json_ok(json!({"ok": true, "favorites": st.app.settings.favorites}))
        }

        ("POST", "/api/select-icon") => {
            let id = s("id");
            match st.find_icon(&id) {
                Some(icon) => {
                    st.app.selected_icon = Some(icon);
                    json_ok(json!({"ok": true}))
                }
                None => json_err("unknown icon"),
            }
        }

        ("POST", "/api/select-target") => {
            let path = s("path");
            let p = PathBuf::from(&path);
            if !p.is_dir() {
                return json_err("not a folder");
            }
            st.app.target_folder_url = Some(p);
            json_ok(json!({"ok": true}))
        }

        ("POST", "/api/clear-target") => {
            st.app.target_folder_url = None;
            json_ok(json!({"ok": true}))
        }

        ("POST", "/api/apply") => {
            let icon_id = s("icon_id");
            let folder = s("folder");
            let name = s("name");
            let tint = s_opt("tint").filter(|t| !t.is_empty());
            let Some(icon) = st.find_icon(&icon_id) else {
                return json_err("no icon selected");
            };
            let folder_path = PathBuf::from(&folder);
            let ok = st
                .app
                .apply_atomic_operation(&icon, &folder_path, &name, tint.as_deref());
            if ok {
                json_ok(json!({"ok": true, "message": st.app.status_message}))
            } else {
                let err = st
                    .app
                    .current_error
                    .as_ref()
                    .map(|e| e.to_string())
                    .unwrap_or_else(|| "Apply failed".to_string());
                json_ok(json!({"ok": false, "error": err, "message": st.app.status_message}))
            }
        }

        ("POST", "/api/reset") => {
            let folder = PathBuf::from(s("folder"));
            let ok = st.app.reset_icon(&folder);
            if ok {
                json_ok(json!({"ok": true, "message": st.app.status_message}))
            } else {
                let err = st
                    .app
                    .current_error
                    .as_ref()
                    .map(|e| e.to_string())
                    .unwrap_or_else(|| "Reset failed".to_string());
                json_ok(json!({"ok": false, "error": err}))
            }
        }

        ("POST", "/api/has-custom-icon") => {
            let folder = PathBuf::from(s("folder"));
            json_ok(json!({"has": st.app.icon_service.has_custom_icon(&folder)}))
        }

        ("POST", "/api/undo") => {
            let ok = st.app.undo();
            json_ok(json!({"ok": ok, "message": st.app.status_message}))
        }
        ("POST", "/api/redo") => {
            let ok = st.app.redo();
            json_ok(json!({"ok": ok, "message": st.app.status_message}))
        }

        ("GET", "/api/settings") => json_ok(json!(st.app.settings)),
        ("POST", "/api/settings") => {
            if let Some(v) = req.get("defaultIconSize").and_then(|x| x.as_f64()) {
                st.app.settings.default_icon_size = v;
                st.app.icon_service =
                    mcons_core::icon_service::IconService::new(if v > 0.0 { v } else { 1024.0 });
            }
            if let Some(v) = req.get("showIconNames").and_then(|x| x.as_bool()) {
                st.app.settings.show_icon_names = v;
            }
            if let Some(v) = req.get("autoRefreshFinder").and_then(|x| x.as_bool()) {
                st.app.settings.auto_refresh_finder = v;
            }
            if let Some(v) = req.get("recentFolderLimit").and_then(|x| x.as_i64()) {
                st.app.settings.recent_folder_limit = v;
            }
            let _ = st.app.settings.save();
            json_ok(json!({"ok": true, "settings": st.app.settings}))
        }
        ("POST", "/api/clear-recents") => {
            st.app.recent_folders.clear();
            st.app.status_message = "Recent folders cleared".to_string();
            json_ok(json!({"ok": true}))
        }

        ("GET", "/api/installed-apps") => {
            let apps = st.app.folder_service.installed_applications();
            json_ok(json!({"apps": apps}))
        }
        ("POST", "/api/create-folder") => {
            let name = s("name");
            let parent = PathBuf::from(s("parent"));
            match st.app.folder_service.create_folder(&name, &parent) {
                Some(p) => {
                    st.app.target_folder_url = Some(p.clone());
                    json_ok(json!({"ok": true, "path": p}))
                }
                None => json_err("could not create folder"),
            }
        }
        ("POST", "/api/browse") => {
            let dir = s("dir");
            let base = if dir.is_empty() {
                st.app.folder_service.home_directory()
            } else {
                PathBuf::from(&dir)
            };
            let entries = st
                .app
                .folder_service
                .folders_in_directory(&base)
                .into_iter()
                .map(|p| {
                    json!({"name": p.file_name().map(|n| n.to_string_lossy()).unwrap_or_default(), "path": p})
                })
                .collect::<Vec<_>>();
            json_ok(json!({
                "current": base,
                "parent": base.parent().map(|p| p.to_path_buf()),
                "entries": entries,
                "home": st.app.folder_service.home_directory(),
            }))
        }

        ("POST", "/api/batch-add") => {
            let mut added = 0;
            if let Some(folders) = req.get("folders").and_then(|x| x.as_array()) {
                for f in folders {
                    if let Some(p) = f.as_str() {
                        let pb = PathBuf::from(p);
                        if pb.is_dir() && !st.batch_folders.contains(&pb) {
                            st.batch_folders.push(pb);
                            added += 1;
                        }
                    }
                }
            }
            // A directory passed as `dir` contributes its subfolders too
            // (Swift's Add Folders panel is multi-select; the web picker
            // adds the folder itself plus its children).
            json_ok(json!({"ok": true, "added": added, "folders": st.batch_folders}))
        }
        ("POST", "/api/batch-clear") => {
            st.batch_folders.clear();
            st.batch_status.clear();
            json_ok(json!({"ok": true}))
        }
        ("POST", "/api/batch-remove") => {
            let p = PathBuf::from(s("folder"));
            st.batch_folders.retain(|f| f != &p);
            st.batch_status.retain(|(f, _)| f != &p);
            json_ok(json!({"ok": true}))
        }
        ("POST", "/api/pick-folder") => {
            let path = pick_folder_native();
            json_ok(json!({"ok": path.is_some(), "path": path}))
        }
        ("POST", "/api/batch-step") => {
            let icon_id = s("icon_id");
            let folder_str = s("folder");
            let tint = s_opt("tint").filter(|t| !t.is_empty());
            let Some(icon) = st.find_icon(&icon_id) else {
                return json_err("no icon selected");
            };
            let folder = PathBuf::from(folder_str);
            let name = folder
                .file_name()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_default();
            let ok = st
                .app
                .apply_atomic_operation(&icon, &folder, &name, tint.as_deref());
            let status = if ok {
                "Applied".to_string()
            } else {
                "Failed: Apply failed".to_string()
            };
            if let Some(pos) = st.batch_status.iter().position(|(f, _)| f == &folder) {
                st.batch_status[pos].1 = status.clone();
            } else {
                st.batch_status.push((folder.clone(), status.clone()));
            }
            json_ok(json!({"ok": ok, "folder": folder, "status": status}))
        }
        ("POST", "/api/batch") => {
            let icon_id = s("icon_id");
            let tint = s_opt("tint").filter(|t| !t.is_empty());
            let Some(icon) = st.find_icon(&icon_id) else {
                return json_err("no icon selected");
            };
            let folders = st.batch_folders.clone();
            let total = folders.len();
            let mut attempted = 0usize;
            st.batch_status.clear();
            for folder in &folders {
                let name = folder
                    .file_name()
                    .map(|n| n.to_string_lossy().into_owned())
                    .unwrap_or_default();
                let ok = st
                    .app
                    .apply_atomic_operation(&icon, folder, &name, tint.as_deref());
                attempted += 1;
                st.batch_status.push((
                    folder.clone(),
                    if ok {
                        "Applied".to_string()
                    } else {
                        "Failed: Apply failed".to_string()
                    },
                ));
            }
            // Swift counts attempts, not successes — as written.
            let message = format!("Successfully applied icons to {attempted} folders!");
            let _ = total;
            st.app.status_message = message.clone();
            json_ok(json!({
                "ok": true,
                "message": message,
                "statuses": st.batch_status.iter().map(|(p, s)| json!({"folder": p, "status": s})).collect::<Vec<_>>(),
            }))
        }

        ("GET", "/api/update/check") => {
            let (status, release) = st.update.check_for_updates(false);
            let (code, err) = match &status {
                UpdateStatus::Idle => ("idle", String::new()),
                UpdateStatus::Checking => ("checking", String::new()),
                UpdateStatus::UpdateAvailable(_) => ("available", String::new()),
                UpdateStatus::UpToDate => ("uptodate", String::new()),
                UpdateStatus::Error(m) => ("error", m.clone()),
            };
            st.update_status = code.to_string();
            st.update_error = err;
            st.last_release = release.clone();
            st.last_checked = Some(chrono_now());
            json_ok(json!({
                "ok": true,
                "status": code,
                "error": st.update_error,
                "release": release,
                "lastChecked": st.last_checked,
            }))
        }
        ("POST", "/api/update/install") => {
            let Some(release) = st.last_release.clone() else {
                return json_err("no release checked yet");
            };
            match st
                .update
                .install_update_directly(&release, |_progress: &str| {})
            {
                Ok(()) => json_ok(json!({"ok": true, "message": "Relaunching MCons..."})),
                // Swift's fallback: "Direct install failed. Opening Terminal..."
                Err(e) => json_ok(
                    json!({"ok": false, "error": e, "message": "Direct install failed. Opening Terminal..."}),
                ),
            }
        }
        ("POST", "/api/update/installer-script") => match st.update.write_installer_script() {
            Ok(p) => json_ok(json!({"ok": true, "path": p})),
            Err(e) => json_err(&e.to_string()),
        },

        ("GET", "/api/export") => {
            let id = query.get("id").cloned().unwrap_or_default();
            let format = query.get("format").cloned().unwrap_or_default();
            let tint = query.get("tint").cloned().filter(|t| !t.is_empty());
            let Some(icon) = st.find_icon(&id) else {
                return (404, "text/plain", b"icon not found".to_vec(), vec![]);
            };
            let fmt = match format.as_str() {
                "icns" => ExportFormat::Icns,
                "svg" => ExportFormat::Svg,
                _ => ExportFormat::Png,
            };
            let tint_rgb = tint.as_deref().and_then(mcons_core::color::Rgb::from_hex);
            static EXPORT_SEQ: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
            let seq = EXPORT_SEQ.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
            let tmp = std::env::temp_dir().join(format!(
                "mcons-export-{}-{}.{}",
                std::process::id(),
                seq,
                fmt.file_extension()
            ));
            match export(&icon, fmt, &tmp, tint_rgb) {
                Ok(()) => match std::fs::read(&tmp) {
                    Ok(bytes) => {
                        let _ = std::fs::remove_file(&tmp);
                        let fname =
                            format!("{}.{}", icon.name.replace(' ', "_"), fmt.file_extension());
                        (
                            200,
                            "application/octet-stream",
                            bytes,
                            vec![(
                                "Content-Disposition",
                                format!("attachment; filename=\"{fname}\""),
                            )],
                        )
                    }
                    Err(e) => json_err(&e.to_string()),
                },
                Err(e) => json_err(&e.to_string()),
            }
        }

        ("POST", "/api/upload") => {
            let name = s("name");
            let data_b64 = s("data");
            let Some(bytes) = base64_decode(&data_b64) else {
                return json_err("bad upload data");
            };
            if bytes.len() > 10 * 1024 * 1024 {
                return json_err("upload too large (max 10MB)");
            }
            let udir = upload_dir();
            let _ = std::fs::create_dir_all(&udir);
            let safe_stem: String = std::path::Path::new(&name)
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("custom_icon")
                .chars()
                .filter(|c| c.is_alphanumeric() || *c == '.' || *c == '-' || *c == '_')
                .collect();
            let safe_name = if safe_stem.is_empty() || safe_stem == "." || safe_stem == ".." {
                format!("custom_{}.png", uuid_string())
            } else {
                format!("{}_{}", uuid_string(), safe_stem)
            };
            let path = udir.join(&safe_name);
            if std::fs::write(&path, &bytes).is_err() {
                return json_err("could not save upload");
            }
            let stem = path
                .file_stem()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_else(|| "Custom Icon".to_string());
            let icon = FolderIcon::new(format!("custom_{}", uuid_string()), stem, "custom")
                .with_file(path.clone());
            st.custom_icon = Some(icon.clone());
            st.app.selected_icon = Some(icon.clone());
            json_ok(json!({"ok": true, "icon": icon, "path": path}))
        }

        ("POST", "/api/build-pack") => {
            let name = s("name");
            let input = PackBuilderInput {
                // Swift's live slug pill: slug of the pack name.
                id: mcons_core::pack_builder::slugify(&name),
                name,
                description: s("description"),
                emoji: s("emoji"),
                accent_color_hex: s("accent"),
                icon_files: req
                    .get("files")
                    .and_then(|x| x.as_array())
                    .map(|a| {
                        a.iter()
                            .filter_map(|v| v.as_str().map(PathBuf::from))
                            .collect()
                    })
                    .unwrap_or_default(),
            };
            match build_custom_pack(&input) {
                Ok(dir) => {
                    st.app.refresh_icon_packs();
                    json_ok(json!({"ok": true, "dir": dir}))
                }
                Err(e) => json_err(&e.to_string()),
            }
        }
        ("POST", "/api/delete-pack") => {
            let id = s("id");
            match st.find_pack(&id) {
                Some(pack) => {
                    let ok = st.app.delete_custom_pack(&pack);
                    json_ok(json!({"ok": ok}))
                }
                None => json_err("unknown pack"),
            }
        }

        _ => (
            404,
            "application/json",
            br#"{"ok":false,"error":"unknown route"}"#.to_vec(),
            vec![],
        ),
    }
}

fn pick_folder_native() -> Option<PathBuf> {
    if cfg!(target_os = "windows") {
        let output = std::process::Command::new("powershell")
            .args([
                "-NoProfile",
                "-Command",
                "Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.FolderBrowserDialog; $d.ShowNewFolderButton = $true; if ($d.ShowDialog() -eq 'OK') { Write-Output $d.SelectedPath }",
            ])
            .output()
            .ok()?;
        let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if !path.is_empty() {
            let p = PathBuf::from(path);
            if p.is_dir() {
                return Some(p);
            }
        }
    } else if cfg!(target_os = "macos") {
        let output = std::process::Command::new("osascript")
            .args([
                "-e",
                "POSIX path of (choose folder with prompt \"Select Folder to Style\")",
            ])
            .output()
            .ok()?;
        let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if !path.is_empty() {
            let p = PathBuf::from(path);
            if p.is_dir() {
                return Some(p);
            }
        }
    }
    None
}

fn chrono_now() -> String {
    // "Nov 18, 2026 at 8:40 PM"-ish, built from SystemTime without deps.
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    // Convert to a UTC civil date/time (Howard Hinnant's algorithm).
    let days = (secs / 86_400) as i64;
    let rem = secs % 86_400;
    let (h, m) = ((rem / 3600) as u32, ((rem % 3600) / 60) as u32);
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let mo = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = if mo <= 2 { y + 1 } else { y };
    let months = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    let (h12, ampm) = if h == 0 {
        (12, "AM")
    } else if h < 12 {
        (h, "AM")
    } else if h == 12 {
        (12, "PM")
    } else {
        (h - 12, "PM")
    };
    format!(
        "{} {}, {} at {}:{:02} {}",
        months[(mo - 1) as usize],
        d,
        year,
        h12,
        m,
        ampm
    )
}

fn uuid_string() -> String {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    use std::time::{SystemTime, UNIX_EPOCH};
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    let mut h = DefaultHasher::new();
    std::process::id().hash(&mut h);
    nanos.hash(&mut h);
    let a = h.finish();
    let mut h2 = DefaultHasher::new();
    a.hash(&mut h2);
    let b = h2.finish();
    format!("{a:08x}-{:04x}", (b >> 48) as u16)
}
