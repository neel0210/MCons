"""Build standalone MCons-Windows.exe and Inno Setup installer"""

import os
import shutil
import subprocess
import sys


def find_iscc() -> str:
    """Finds Inno Setup Compiler executable ISCC.exe"""
    which = shutil.which("iscc.exe") or shutil.which("ISCC.exe")
    if which:
        return which

    candidates = [
        os.path.expandvars(r"%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"),
        r"C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        r"C:\Program Files\Inno Setup 6\ISCC.exe",
        r"C:\Program Files (x86)\Inno Setup 5\ISCC.exe",
    ]
    for c in candidates:
        if os.path.isfile(c):
            return c
    return ""


def build():
    # Kill any running instances to prevent file lock
    subprocess.run(["taskkill", "/F", "/IM", "MCons-Windows.exe", "/T"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["taskkill", "/F", "/IM", "MCons.exe", "/T"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    windows_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(windows_dir, ".."))
    app_script = os.path.join(windows_dir, "mcons_app.py")
    dist_dir = os.path.join(windows_dir, "dist")
    build_dir = os.path.join(windows_dir, "build")
    icon_path = os.path.join(windows_dir, "mcons.ico")
    icon_packs_dir = os.path.join(repo_root, "MCons", "Resources", "IconPacks")

    # 1. Ensure icon exists
    if not os.path.isfile(icon_path):
        from PIL import Image
        png_src = os.path.join(repo_root, "assets", "icon.png")
        if os.path.exists(png_src):
            im = Image.open(png_src).convert("RGBA")
            im.save(icon_path, format="ICO", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
            print(f"Generated {icon_path}")

    thumbnails_dir = os.path.join(windows_dir, "thumbnails")
    if not os.path.isdir(thumbnails_dir) or len(os.listdir(thumbnails_dir)) < 190:
        import generate_thumbnails
        generate_thumbnails.generate_all()

    # Pre-generate packs cache for fast startup
    cache_path = os.path.join(windows_dir, "packs_cache.json")
    if not os.path.isfile(cache_path):
        import json, mcons_core
        packs = mcons_core.load_all_packs(icon_packs_dir)
        cache_data = []
        for p in packs:
            cache_data.append({k: v for k, v in p.items() if k != 'icons'} | {
                'icons': [{'name': i['name'], 'file': i['file']} for i in p['icons']]
            })
        with open(cache_path, "w", encoding="utf-8") as f:
            json.dump(cache_data, f, indent=2)
        print(f"Generated {cache_path}")

    # 2. Build onedir application for instant startup and Inno Setup
    onedir_cmd = [
        sys.executable,
        "-m",
        "PyInstaller",
        "--noconfirm",
        "--clean",
        "--onedir",
        "--windowed",
        "--name",
        "MCons",
        "--distpath",
        dist_dir,
        "--workpath",
        build_dir,
        "--collect-all",
        "customtkinter",
        f"--icon={icon_path}",
        f"--add-data={icon_packs_dir};IconPacks",
        f"--add-data={thumbnails_dir};thumbnails",
        f"--add-data={cache_path};.",
        f"--add-data={icon_path};.",
        app_script,
    ]

    print(f"\n[1/3] Building native MCons application bundle (--onedir)...")
    ret1 = subprocess.run(onedir_cmd)
    if ret1.returncode != 0:
        print(f"\n[FAILED] PyInstaller onedir build failed with exit code {ret1.returncode}")
        sys.exit(ret1.returncode)
    onedir_exe = os.path.join(dist_dir, "MCons", "MCons.exe")
    print(f"[SUCCESS] Built instant-launch application: {onedir_exe}")

    # 3. Build standalone single-file executable
    onefile_cmd = [
        sys.executable,
        "-m",
        "PyInstaller",
        "--noconfirm",
        "--clean",
        "--onefile",
        "--windowed",
        "--name",
        "MCons-Windows",
        "--distpath",
        dist_dir,
        "--workpath",
        build_dir,
        "--collect-all",
        "customtkinter",
        f"--icon={icon_path}",
        f"--add-data={icon_packs_dir};IconPacks",
        f"--add-data={thumbnails_dir};thumbnails",
        f"--add-data={cache_path};.",
        f"--add-data={icon_path};.",
        app_script,
    ]

    print(f"\n[2/3] Building portable single-file executable (--onefile)...")
    ret2 = subprocess.run(onefile_cmd)
    if ret2.returncode != 0:
        print(f"\n[FAILED] PyInstaller onefile build failed with exit code {ret2.returncode}")
        sys.exit(ret2.returncode)

    exe_path = os.path.join(dist_dir, "MCons-Windows.exe")
    exe_size_mb = os.path.getsize(exe_path) / (1024 * 1024)
    print(f"[SUCCESS] Built standalone executable: {exe_path} ({exe_size_mb:.2f} MB)")

    # 4. Build Windows Installer with Inno Setup
    iscc_path = find_iscc()
    iss_script = os.path.join(windows_dir, "installer.iss")

    if "--skip-installer" in sys.argv:
        print(f"\n[SKIP] Skipping installer compilation (--skip-installer specified).")
    elif iscc_path and os.path.isfile(iss_script):
        print(f"\n[3/3] Compiling Windows Installer with Inno Setup ({iscc_path})...")
        iscc_cmd = [iscc_path, iss_script]
        iscc_ret = subprocess.run(iscc_cmd, cwd=windows_dir)
        if iscc_ret.returncode == 0:
            setup_exe = os.path.join(dist_dir, "MCons-Windows-Setup.exe")
            if os.path.isfile(setup_exe):
                setup_size_mb = os.path.getsize(setup_exe) / (1024 * 1024)
                print(f"[SUCCESS] Built Windows Installer: {setup_exe} ({setup_size_mb:.2f} MB)")
        else:
            print(f"[WARNING] Inno Setup compilation failed with code {iscc_ret.returncode}")
    else:
        print(f"\n[SKIP] ISCC.exe not found or installer.iss missing. Standalone .exe is ready in {dist_dir}.")


if __name__ == "__main__":
    build()
