"""MCons Windows Core Engine
Native Windows folder icon customizer using desktop.ini & Win32 Shell API
"""

import os
import sys
import json
import base64
import re
import io
import ctypes
from typing import Dict, List, Optional, Tuple
from PIL import Image

# Win32 Constants
FILE_ATTRIBUTE_READONLY = 0x00000001
FILE_ATTRIBUTE_HIDDEN = 0x00000002
FILE_ATTRIBUTE_SYSTEM = 0x00000004
FILE_ATTRIBUTE_NORMAL = 0x00000080

SHCNE_ASSOCCHANGED = 0x08000000
SHCNE_UPDATEDIR = 0x00001000
SHCNF_IDLIST = 0x0000
SHCNF_PATHW = 0x0005

ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def get_cache_dir() -> str:
    """Returns local app cache directory for fast thumbnail access"""
    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        cache_dir = os.path.join(local_app_data, "MCons", "Thumbnails")
    else:
        cache_dir = os.path.join(os.path.expanduser("~"), ".mcons", "thumbnails")
    os.makedirs(cache_dir, exist_ok=True)
    return cache_dir


def get_icon_thumbnail_path(svg_path: str, size: int = 44) -> Optional[str]:
    """Returns or creates a cached PNG thumbnail path for fast UI display"""
    base_name = os.path.splitext(os.path.basename(svg_path))[0]
    parent_dir = os.path.basename(os.path.dirname(svg_path))
    thumb_name = f"{parent_dir}_{base_name}.png"

    candidates = [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "thumbnails", thumb_name),
        os.path.abspath(os.path.join("windows", "thumbnails", thumb_name)),
    ]
    if getattr(sys, 'frozen', False):
        meipass = getattr(sys, '_MEIPASS', None)
        if meipass:
            candidates.insert(0, os.path.join(meipass, "thumbnails", thumb_name))

    for c in candidates:
        if os.path.isfile(c):
            return c

    import hashlib
    h = hashlib.md5(svg_path.encode("utf-8")).hexdigest()
    thumb_path = os.path.join(get_cache_dir(), f"{h}_{size}.png")
    if os.path.exists(thumb_path):
        return thumb_path

    im = extract_image_from_svg(svg_path)
    if im:
        try:
            im_thumb = im.resize((size, size), Image.Resampling.LANCZOS)
            im_thumb.save(thumb_path, format="PNG")
            return thumb_path
        except Exception:
            pass
    return None


def get_packs_dir() -> str:
    """Finds the IconPacks directory in source tree or bundled executable"""
    # 1. PyInstaller single-file temp extract directory
    if getattr(sys, 'frozen', False):
        meipass = getattr(sys, '_MEIPASS', None)
        if meipass and os.path.isdir(os.path.join(meipass, "IconPacks")):
            return os.path.join(meipass, "IconPacks")
        exe_dir = os.path.dirname(os.path.abspath(sys.executable))
        if os.path.isdir(os.path.join(exe_dir, "IconPacks")):
            return os.path.join(exe_dir, "IconPacks")

    # 2. Next to executable or current script
    exe_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
    candidates = [
        os.path.join(exe_dir, "IconPacks"),
        os.path.join(exe_dir, "MCons", "Resources", "IconPacks"),
        os.path.join(exe_dir, "..", "MCons", "Resources", "IconPacks"),
        os.path.abspath("MCons/Resources/IconPacks"),
        os.path.abspath("../MCons/Resources/IconPacks"),
    ]
    for c in candidates:
        if os.path.isdir(c):
            return c
    return os.path.abspath("MCons/Resources/IconPacks")


def load_all_packs(packs_dir: Optional[str] = None) -> List[Dict]:
    """Loads all 19 icon packs and their icons metadata (cached for high performance)"""
    if not packs_dir:
        packs_dir = get_packs_dir()

    # Fast Path: Check pre-built packs_cache.json
    cache_candidates = [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "packs_cache.json"),
        os.path.abspath(os.path.join("windows", "packs_cache.json")),
    ]
    if getattr(sys, 'frozen', False):
        meipass = getattr(sys, '_MEIPASS', None)
        if meipass:
            cache_candidates.insert(0, os.path.join(meipass, "packs_cache.json"))
        exe_dir = os.path.dirname(os.path.abspath(sys.executable))
        cache_candidates.insert(1, os.path.join(exe_dir, "packs_cache.json"))

    for c in cache_candidates:
        if os.path.isfile(c):
            try:
                with open(c, "r", encoding="utf-8") as f:
                    raw_packs = json.load(f)
                packs = []
                for p in raw_packs:
                    p_copy = dict(p)
                    p_path = os.path.join(packs_dir, p["id"])
                    p_copy["icons"] = [
                        {
                            "name": i["name"],
                            "file": i["file"],
                            "path": os.path.join(p_path, i["file"])
                        }
                        for i in p["icons"]
                    ]
                    packs.append(p_copy)
                return packs
            except Exception:
                pass

    if not os.path.isdir(packs_dir):
        return []

    category_map = {
        'attack-on-titan': 'Anime',
        'black-clover': 'Anime',
        'cameras': 'Hardware',
        'chainsaw-man': 'Anime',
        'dandadan': 'Anime',
        'death-note': 'Anime',
        'demon-slayer': 'Anime',
        'dev-tech': 'Tech & Dev',
        'dragon-ball-super': 'Anime',
        'fullmetal-alchemist-brotherhood': 'Anime',
        'google': 'Tech & Dev',
        'jujutsu-kaisen': 'Anime',
        'kaiju-no-8': 'Anime',
        'macos-native-plus': 'System & Minimal',
        'my-hero-academia': 'Anime',
        'naruto': 'Anime',
        'one-piece': 'Anime',
        'pokemon': 'Gaming & Anime',
        'solo-leveling': 'Anime'
    }

    packs = []
    for pack_id in sorted(os.listdir(packs_dir)):
        p_path = os.path.join(packs_dir, pack_id)
        if not os.path.isdir(p_path):
            continue
        meta_path = os.path.join(p_path, "metadata.json")
        meta = {}
        if os.path.exists(meta_path):
            try:
                with open(meta_path, "r", encoding="utf-8") as f:
                    meta = json.load(f)
            except Exception:
                pass

        pack_name = meta.get("name", pack_id.replace("-", " ").title())
        pack_category = category_map.get(pack_id, "Anime")
        
        svg_files = [f for f in sorted(os.listdir(p_path)) if f.lower().endswith(".svg")]
        icons = []
        for svg in svg_files:
            icon_name = os.path.splitext(svg)[0]
            icons.append({
                "name": icon_name,
                "file": svg,
                "path": os.path.join(p_path, svg)
            })

        packs.append({
            "id": pack_id,
            "name": pack_name,
            "description": meta.get("description", ""),
            "emoji": meta.get("emoji", "📁"),
            "category": pack_category,
            "accentColorHex": meta.get("accentColorHex", "#6366F1"),
            "icons": icons,
            "count": len(icons)
        })

    return packs


def extract_image_from_svg(svg_path: str) -> Optional[Image.Image]:
    """Extracts high-resolution raster image from MCons SVG or converts it"""
    try:
        with open(svg_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

        m = re.search(r'base64,([A-Za-z0-9+/=]+)', content)
        if m:
            raw = base64.b64decode(m.group(1))
            return Image.open(io.BytesIO(raw)).convert("RGBA")

        # Fallback: simple colored square if pure vector
        im = Image.new("RGBA", (256, 256), (0, 113, 227, 255))
        return im
    except Exception as e:
        print(f"Error extracting image from {svg_path}: {e}")
        return None


def resolve_icon_path(query: str) -> Optional[str]:
    """Resolves an icon name, pack/icon, relative path, or absolute path to a valid SVG/ICO file"""
    if os.path.isfile(query):
        return os.path.abspath(query)

    packs_dir = get_packs_dir()

    # Try relative to packs dir
    cand = os.path.join(packs_dir, query)
    if os.path.isfile(cand):
        return cand
    if os.path.isfile(cand + ".svg"):
        return cand + ".svg"

    # Search through all packs
    clean_q = query.lower().strip()
    if clean_q.endswith(".svg") or clean_q.endswith(".ico"):
        clean_q = os.path.splitext(clean_q)[0]

    for p in load_all_packs(packs_dir):
        for icon in p["icons"]:
            iname = icon["name"].lower()
            if iname == clean_q or iname.replace(" ", "-") == clean_q or iname.replace("-", " ") == clean_q:
                return icon["path"]

    return None


def convert_image_to_ico(im: Image.Image, output_path: str):
    """Converts a PIL Image to a multi-size Windows .ico file"""
    im.save(output_path, format="ICO", sizes=ICO_SIZES)


def apply_folder_icon(folder_path: str, svg_or_ico_path: str) -> Tuple[bool, str]:
    """
    Applies custom icon to target Windows folder using desktop.ini and Win32 shell integration
    """
    folder_path = os.path.abspath(folder_path)
    if not os.path.isdir(folder_path):
        return False, f"Folder does not exist: {folder_path}"

    resolved = resolve_icon_path(svg_or_ico_path)
    if not resolved:
        return False, f"Icon not found: {svg_or_ico_path}"
    svg_or_ico_path = resolved

    target_ico = os.path.join(folder_path, "folder_icon.ico")
    desktop_ini = os.path.join(folder_path, "desktop.ini")

    # 1. Reset attributes on existing files if present
    if os.path.exists(desktop_ini):
        ctypes.windll.kernel32.SetFileAttributesW(desktop_ini, FILE_ATTRIBUTE_NORMAL)
    if os.path.exists(target_ico):
        ctypes.windll.kernel32.SetFileAttributesW(target_ico, FILE_ATTRIBUTE_NORMAL)

    # 2. Prepare .ico
    if svg_or_ico_path.lower().endswith(".ico"):
        with open(svg_or_ico_path, "rb") as src, open(target_ico, "wb") as dst:
            dst.write(src.read())
    else:
        im = extract_image_from_svg(svg_or_ico_path)
        if not im:
            return False, "Failed to decode icon image"
        convert_image_to_ico(im, target_ico)

    # 3. Write desktop.ini
    ini_content = (
        "[.ShellClassInfo]\r\n"
        "IconResource=folder_icon.ico,0\r\n"
        "[ViewState]\r\n"
        "Mode=\r\n"
        "Vid=\r\n"
        "FolderType=Generic\r\n"
    )
    with open(desktop_ini, "w", encoding="utf-8") as f:
        f.write(ini_content)

    # 4. Set Windows attributes:
    # desktop.ini: Hidden + System
    # folder_icon.ico: Hidden + System
    # Folder itself: Read-Only (Windows Explorer requires Read-Only or System bit to read desktop.ini)
    ctypes.windll.kernel32.SetFileAttributesW(target_ico, FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_SYSTEM)
    ctypes.windll.kernel32.SetFileAttributesW(desktop_ini, FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_SYSTEM)
    ctypes.windll.kernel32.SetFileAttributesW(folder_path, FILE_ATTRIBUTE_READONLY)

    # 5. Instantly flush Windows Explorer icon cache
    notify_windows_explorer(folder_path)

    return True, f"Successfully applied icon to {os.path.basename(folder_path)}"


def restore_folder_icon(folder_path: str) -> Tuple[bool, str]:
    """
    Restores folder to default Windows folder icon
    """
    folder_path = os.path.abspath(folder_path)
    if not os.path.isdir(folder_path):
        return False, f"Folder does not exist: {folder_path}"

    target_ico = os.path.join(folder_path, "folder_icon.ico")
    desktop_ini = os.path.join(folder_path, "desktop.ini")

    if os.path.exists(desktop_ini):
        ctypes.windll.kernel32.SetFileAttributesW(desktop_ini, FILE_ATTRIBUTE_NORMAL)
        try:
            os.remove(desktop_ini)
        except Exception:
            pass

    if os.path.exists(target_ico):
        ctypes.windll.kernel32.SetFileAttributesW(target_ico, FILE_ATTRIBUTE_NORMAL)
        try:
            os.remove(target_ico)
        except Exception:
            pass

    # Reset folder attribute to Normal
    ctypes.windll.kernel32.SetFileAttributesW(folder_path, FILE_ATTRIBUTE_NORMAL)

    notify_windows_explorer(folder_path)

    return True, f"Restored default icon for {os.path.basename(folder_path)}"


def notify_windows_explorer(folder_path: str):
    """Signals Windows Shell to reload folder icons without restarting explorer.exe"""
    try:
        # Invalidate Windows Explorer thumbnail cache by updating folder mtime
        try:
            os.utime(folder_path, None)
        except Exception:
            pass
        # SHCNE_UPDATEDIR = 0x00001000, SHCNF_PATHW = 0x0005
        ctypes.windll.shell32.SHChangeNotify(SHCNE_UPDATEDIR, SHCNF_PATHW, folder_path, None)
        # SHCNE_ASSOCCHANGED = 0x08000000, SHCNF_IDLIST = 0x0000
        ctypes.windll.shell32.SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, None, None)
    except Exception as e:
        print(f"Shell notify warning: {e}")


def get_favorites_file() -> str:
    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        app_dir = os.path.join(local_app_data, "MCons")
    else:
        app_dir = os.path.join(os.path.expanduser("~"), ".mcons")
    os.makedirs(app_dir, exist_ok=True)
    return os.path.join(app_dir, "favorites.json")


def get_favorites() -> List[str]:
    fav_file = get_favorites_file()
    if os.path.isfile(fav_file):
        try:
            with open(fav_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    return [f for f in data if os.path.isfile(f) or os.path.exists(f)]
        except Exception:
            pass
    return []


def is_favorite(icon_path: str) -> bool:
    favs = get_favorites()
    norm = os.path.normpath(icon_path)
    return any(os.path.normpath(f) == norm for f in favs)


def toggle_favorite(icon_path: str) -> bool:
    favs = get_favorites()
    norm = os.path.normpath(icon_path)
    if any(os.path.normpath(f) == norm for f in favs):
        favs = [f for f in favs if os.path.normpath(f) != norm]
        is_fav = False
    else:
        favs.append(icon_path)
        is_fav = True

    try:
        with open(get_favorites_file(), "w", encoding="utf-8") as f:
            json.dump(favs, f, indent=2)
    except Exception:
        pass
    return is_fav


def clear_thumbnail_cache() -> int:
    """Cleans up cached PNG thumbnails and returns freed file count"""
    cache_dir = get_cache_dir()
    count = 0
    if os.path.isdir(cache_dir):
        for f in os.listdir(cache_dir):
            fp = os.path.join(cache_dir, f)
            try:
                if os.path.isfile(fp):
                    os.remove(fp)
                    count += 1
            except Exception:
                pass
    return count


def is_context_menu_registered() -> bool:
    if sys.platform != "win32":
        return False
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Classes\Directory\shell\MCons"):
            return True
    except Exception:
        return False


def set_context_menu_registered(enabled: bool, exe_path: Optional[str] = None) -> bool:
    if sys.platform != "win32":
        return False
    try:
        import winreg
        if not exe_path:
            exe_path = sys.executable

        key_path = r"Software\Classes\Directory\shell\MCons"
        bg_key_path = r"Software\Classes\Directory\Background\shell\MCons"

        if enabled:
            # Folder right-click
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, key_path) as key:
                winreg.SetValueEx(key, "", 0, winreg.REG_SZ, "Customize with MCons")
                winreg.SetValueEx(key, "Icon", 0, winreg.REG_SZ, f'"{exe_path}"')
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, key_path + r"\command") as key:
                winreg.SetValueEx(key, "", 0, winreg.REG_SZ, f'"{exe_path}" "%1"')

            # Folder background right-click
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, bg_key_path) as key:
                winreg.SetValueEx(key, "", 0, winreg.REG_SZ, "Customize folder with MCons")
                winreg.SetValueEx(key, "Icon", 0, winreg.REG_SZ, f'"{exe_path}"')
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, bg_key_path + r"\command") as key:
                winreg.SetValueEx(key, "", 0, winreg.REG_SZ, f'"{exe_path}" "%V"')
            return True
        else:
            for kp in [key_path + r"\command", key_path, bg_key_path + r"\command", bg_key_path]:
                try:
                    winreg.DeleteKey(winreg.HKEY_CURRENT_USER, kp)
                except Exception:
                    pass
            return True
    except Exception as e:
        print(f"Registry toggle error: {e}")
        return False
