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

    # 2. Build standalone PyInstaller executable
    cmd = [
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
        f"--icon={icon_path}",
        f"--add-data={icon_packs_dir};IconPacks",
        f"--add-data={icon_path};.",
        app_script,
    ]

    print(f"\n[1/2] Building standalone executable with PyInstaller...")
    ret = subprocess.run(cmd)
    if ret.returncode != 0:
        print(f"\n[FAILED] PyInstaller build failed with exit code {ret.returncode}")
        sys.exit(ret.returncode)

    exe_path = os.path.join(dist_dir, "MCons-Windows.exe")
    exe_size_mb = os.path.getsize(exe_path) / (1024 * 1024)
    print(f"[SUCCESS] Built standalone executable: {exe_path} ({exe_size_mb:.2f} MB)")

    # 3. Build Windows Installer with Inno Setup
    iscc_path = find_iscc()
    iss_script = os.path.join(windows_dir, "installer.iss")

    if iscc_path and os.path.isfile(iss_script):
        print(f"\n[2/2] Compiling Windows Installer with Inno Setup ({iscc_path})...")
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
