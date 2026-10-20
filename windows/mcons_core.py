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


def get_packs_dir() -> str:
    """Finds the IconPacks directory in source tree or bundled executable"""
    # 1. Next to executable
    exe_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
    candidates = [
        os.path.join(exe_dir, "IconPacks"),
        os.path.join(exe_dir, "MCons", "Resources", "IconPacks"),
        os.path.join(exe_dir, "..", "MCons", "Resources", "IconPacks"),
        os.path.abspath("MCons/Resources/IconPacks"),
    ]
    for c in candidates:
        if os.path.isdir(c):
            return c
    return os.path.abspath("MCons/Resources/IconPacks")


def load_all_packs(packs_dir: Optional[str] = None) -> List[Dict]:
    """Loads all 19 icon packs and their icons metadata"""
    if not packs_dir:
        packs_dir = get_packs_dir()

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
        # SHCNE_UPDATEDIR = 0x00001000, SHCNF_PATHW = 0x0005
        ctypes.windll.shell32.SHChangeNotify(SHCNE_UPDATEDIR, SHCNF_PATHW, folder_path, None)
        # SHCNE_ASSOCCHANGED = 0x08000000, SHCNF_IDLIST = 0x0000
        ctypes.windll.shell32.SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, None, None)
    except Exception as e:
        print(f"Shell notify warning: {e}")
