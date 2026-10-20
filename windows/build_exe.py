"""Build standalone MCons-Windows.exe using PyInstaller"""

import os
import subprocess
import sys

def build():
    windows_dir = os.path.dirname(os.path.abspath(__file__))
    app_script = os.path.join(windows_dir, "mcons_app.py")
    dist_dir = os.path.join(windows_dir, "dist")
    build_dir = os.path.join(windows_dir, "build")

    cmd = [
        sys.executable,
        "-m",
        "PyInstaller",
        "--onefile",
        "--windowed",
        "--name",
        "MCons-Windows",
        "--distpath",
        dist_dir,
        "--workpath",
        build_dir,
        app_script,
    ]

    print(f"Running: {' '.join(cmd)}")
    ret = subprocess.run(cmd)
    if ret.returncode == 0:
        exe_path = os.path.join(dist_dir, "MCons-Windows.exe")
        print(f"\n[SUCCESS] Built standalone executable: {exe_path}")
    else:
        print(f"\n[FAILED] PyInstaller build failed with exit code {ret.returncode}")

if __name__ == "__main__":
    build()
