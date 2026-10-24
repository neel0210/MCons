"""MCons for Windows — Modern Desktop GUI & CLI
CustomTkinter GUI matching MCons dark glassmorphism design system
"""

import os
import sys
import argparse
from typing import List, Dict, Optional
from PIL import Image, ImageTk
import customtkinter as ctk
from tkinter import filedialog, messagebox

# Ensure local import
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mcons_core

# High-DPI Awareness on Windows
if sys.platform == "win32":
    try:
        import ctypes
        ctypes.windll.shcore.SetProcessDpiAwareness(2)  # Per-Monitor DPI aware
    except Exception:
        try:
            import ctypes
            ctypes.windll.user32.SetProcessDPIAware()
        except Exception:
            pass

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")


class MConsWindowsApp(ctk.CTk):
    def __init__(self, initial_folder: Optional[str] = None):
        super().__init__()

        self.title("MCons — Windows Folder Customizer")
        self.geometry("980x680")
        self.minsize(860, 580)
        self.configure(fg_color="#08090d")

        # Set Window Icon
        ico_candidates = [
            os.path.join(os.path.dirname(os.path.abspath(__file__)), "mcons.ico"),
            os.path.abspath("windows/mcons.ico"),
        ]
        if getattr(sys, 'frozen', False):
            meipass = getattr(sys, '_MEIPASS', None)
            if meipass:
                ico_candidates.insert(0, os.path.join(meipass, "mcons.ico"))
        for ico in ico_candidates:
            if os.path.exists(ico):
                try:
                    self.iconbitmap(ico)
                    break
                except Exception:
                    pass

        self.selected_folder: Optional[str] = None
        self.selected_icon_path: Optional[str] = None
        self.selected_icon_name: Optional[str] = None
        self.active_category: str = "All"
        self.search_query: str = ""

        # Load packs
        self.packs = mcons_core.load_all_packs()
        self.icon_cache: Dict[str, ctk.CTkImage] = {}

        self._build_ui()

        if initial_folder and os.path.isdir(initial_folder):
            self.selected_folder = os.path.abspath(initial_folder)
            self.folder_path_entry.delete(0, "end")
            self.folder_path_entry.insert(0, self.selected_folder)
            self.status_label.configure(
                text=f"Selected folder: '{os.path.basename(self.selected_folder)}'",
                text_color="#38bdf8"
            )

    def _build_ui(self):
        # 1. Top Header
        self.header_frame = ctk.CTkFrame(self, fg_color="#0e121b", corner_radius=0, height=64)
        self.header_frame.pack(fill="x", side="top")

        self.logo_label = ctk.CTkLabel(
            self.header_frame,
            text="⚡ MCons",
            font=ctk.CTkFont(family="Segoe UI", size=20, weight="bold"),
            text_color="#3abfc3"
        )
        self.logo_label.pack(side="left", padx=24, pady=14)

        self.subtitle_label = ctk.CTkLabel(
            self.header_frame,
            text="Native Windows Folder Customizer • 196+ Vector Icons",
            font=ctk.CTkFont(family="Segoe UI", size=12),
            text_color="#94a3b8"
        )
        self.subtitle_label.pack(side="left", padx=0, pady=14)

        # Tab selector (Single Folder vs Batch Apply)
        self.tabview = ctk.CTkTabview(
            self,
            fg_color="#0b0e14",
            segmented_button_fg_color="#141a26",
            segmented_button_selected_color="#2479d4",
            segmented_button_selected_hover_color="#1b5bb5",
            corner_radius=18
        )
        self.tabview.pack(fill="both", expand=True, padx=20, pady=12)

        self.tab_single = self.tabview.add("Single Folder")
        self.tab_batch = self.tabview.add("Batch Apply")

        self._build_single_folder_tab()
        self._build_batch_tab()

    def _build_single_folder_tab(self):
        # Target folder selection bar
        target_card = ctk.CTkFrame(self.tab_single, fg_color="#121724", corner_radius=14)
        target_card.pack(fill="x", padx=10, pady=(6, 12))

        lbl = ctk.CTkLabel(
            target_card,
            text="Target Folder:",
            font=ctk.CTkFont(size=13, weight="bold"),
            text_color="#f8fafc"
        )
        lbl.pack(side="left", padx=(16, 8), pady=12)

        self.folder_path_entry = ctk.CTkEntry(
            target_card,
            placeholder_text="Select a folder or drag & drop...",
            fg_color="#0a0d14",
            border_color="#1e2638",
            corner_radius=10,
            font=ctk.CTkFont(family="Consolas", size=12)
        )
        self.folder_path_entry.pack(side="left", fill="x", expand=True, padx=8, pady=12)

        browse_btn = ctk.CTkButton(
            target_card,
            text="Browse...",
            fg_color="#1e2638",
            hover_color="#2a354d",
            corner_radius=10,
            width=100,
            command=self._on_browse_folder
        )
        browse_btn.pack(side="right", padx=16, pady=12)

        # Middle Content: Filter & Search + Icons Grid
        middle_frame = ctk.CTkFrame(self.tab_single, fg_color="transparent")
        middle_frame.pack(fill="both", expand=True, padx=10, pady=0)

        # Controls row (Categories + Search)
        ctrl_row = ctk.CTkFrame(middle_frame, fg_color="transparent")
        ctrl_row.pack(fill="x", pady=(0, 10))

        # Categories
        categories = ["All", "Anime", "Tech & Dev", "Gaming", "Hardware"]
        self.cat_btns = []
        for cat in categories:
            btn = ctk.CTkButton(
                ctrl_row,
                text=cat,
                width=80,
                height=30,
                corner_radius=15,
                fg_color="#2479d4" if cat == "All" else "#141a26",
                hover_color="#3abfc3",
                font=ctk.CTkFont(size=12, weight="bold" if cat == "All" else "normal"),
                command=lambda c=cat: self._on_select_category(c)
            )
            btn.pack(side="left", padx=4)
            self.cat_btns.append((cat, btn))

        # Search box
        self.search_entry = ctk.CTkEntry(
            ctrl_row,
            placeholder_text="Search Gojo, Naruto, Docker, Deku...",
            width=240,
            height=32,
            fg_color="#0e131d",
            border_color="#1e2638",
            corner_radius=16
        )
        self.search_entry.pack(side="right")
        self.search_entry.bind("<KeyRelease>", self._on_search_changed)

        # Scrollable icon grid
        self.icons_scroll = ctk.CTkScrollableFrame(
            middle_frame,
            fg_color="#0e121a",
            corner_radius=14,
            scrollbar_button_color="#1e2638"
        )
        self.icons_scroll.pack(fill="both", expand=True)

        # Bottom Bar: Selected icon preview & Action buttons
        bottom_bar = ctk.CTkFrame(self.tab_single, fg_color="#121724", corner_radius=14, height=72)
        bottom_bar.pack(fill="x", padx=10, pady=(12, 6))

        self.selection_label = ctk.CTkLabel(
            bottom_bar,
            text="Selected Icon: None",
            font=ctk.CTkFont(size=13, weight="bold"),
            text_color="#94a3b8"
        )
        self.selection_label.pack(side="left", padx=20, pady=16)

        self.status_label = ctk.CTkLabel(
            bottom_bar,
            text="",
            font=ctk.CTkFont(size=12),
            text_color="#10b981"
        )
        self.status_label.pack(side="left", padx=10, pady=16)

        restore_btn = ctk.CTkButton(
            bottom_bar,
            text="Restore Default",
            fg_color="#27272a",
            hover_color="#3f3f46",
            corner_radius=20,
            height=38,
            width=130,
            command=self._on_restore_icon
        )
        restore_btn.pack(side="right", padx=(8, 16), pady=16)

        apply_btn = ctk.CTkButton(
            bottom_bar,
            text="Apply Icon to Folder",
            fg_color="#2479d4",
            hover_color="#3abfc3",
            corner_radius=20,
            height=38,
            width=170,
            font=ctk.CTkFont(size=13, weight="bold"),
            command=self._on_apply_icon
        )
        apply_btn.pack(side="right", padx=8, pady=16)

        self._render_icons_grid()

    def _build_batch_tab(self):
        lbl = ctk.CTkLabel(
            self.tab_batch,
            text="Batch Customize Multiple Folders",
            font=ctk.CTkFont(size=16, weight="bold"),
            text_color="#f8fafc"
        )
        lbl.pack(anchor="w", padx=20, pady=(16, 4))

        sub = ctk.CTkLabel(
            self.tab_batch,
            text="Select a parent folder to automatically style all child directories.",
            font=ctk.CTkFont(size=12),
            text_color="#94a3b8"
        )
        sub.pack(anchor="w", padx=20, pady=(0, 16))

        batch_card = ctk.CTkFrame(self.tab_batch, fg_color="#121724", corner_radius=14)
        batch_card.pack(fill="x", padx=20, pady=10)

        self.batch_parent_entry = ctk.CTkEntry(
            batch_card,
            placeholder_text="Parent directory containing subfolders...",
            fg_color="#0a0d14",
            border_color="#1e2638",
            corner_radius=10,
            font=ctk.CTkFont(family="Consolas", size=12)
        )
        self.batch_parent_entry.pack(side="left", fill="x", expand=True, padx=16, pady=16)

        browse_batch_btn = ctk.CTkButton(
            batch_card,
            text="Browse Parent...",
            fg_color="#1e2638",
            hover_color="#2a354d",
            corner_radius=10,
            width=120,
            command=self._on_browse_batch_parent
        )
        browse_batch_btn.pack(side="right", padx=16, pady=16)

        self.batch_log_box = ctk.CTkTextbox(
            self.tab_batch,
            fg_color="#0a0d14",
            text_color="#e2e8f0",
            corner_radius=12,
            font=ctk.CTkFont(family="Consolas", size=12)
        )
        self.batch_log_box.pack(fill="both", expand=True, padx=20, pady=10)

        apply_batch_btn = ctk.CTkButton(
            self.tab_batch,
            text="Apply Selected Icon to All Subfolders",
            fg_color="#2479d4",
            hover_color="#3abfc3",
            corner_radius=20,
            height=40,
            font=ctk.CTkFont(size=13, weight="bold"),
            command=self._on_apply_batch
        )
        apply_batch_btn.pack(side="right", padx=20, pady=16)

    def _on_browse_folder(self):
        path = filedialog.askdirectory(title="Select Folder to Customize")
        if path:
            self.selected_folder = os.path.abspath(path)
            self.folder_path_entry.delete(0, "end")
            self.folder_path_entry.insert(0, self.selected_folder)
            self.status_label.configure(text=f"Selected '{os.path.basename(path)}'", text_color="#38bdf8")

    def _on_browse_batch_parent(self):
        path = filedialog.askdirectory(title="Select Parent Directory")
        if path:
            self.batch_parent_entry.delete(0, "end")
            self.batch_parent_entry.insert(0, os.path.abspath(path))

    def _on_select_category(self, cat: str):
        self.active_category = cat
        for c, btn in self.cat_btns:
            if c == cat:
                btn.configure(fg_color="#2479d4", font=ctk.CTkFont(size=12, weight="bold"))
            else:
                btn.configure(fg_color="#141a26", font=ctk.CTkFont(size=12, weight="normal"))
        self._render_icons_grid()

    def _on_search_changed(self, event=None):
        self.search_query = self.search_entry.get().strip().lower()
        self._render_icons_grid()

    def _render_icons_grid(self):
        for widget in self.icons_scroll.winfo_children():
            widget.destroy()

        # Filter packs & icons
        filtered_icons = []
        for pack in self.packs:
            if self.active_category != "All" and pack.get("category", "") != self.active_category:
                continue

            for icon in pack["icons"]:
                q = self.search_query
                if not q or q in icon["name"].lower() or q in pack["name"].lower():
                    filtered_icons.append((pack, icon))

        if not filtered_icons:
            empty_lbl = ctk.CTkLabel(
                self.icons_scroll,
                text="No icons found matching your search.",
                text_color="#64748b",
                font=ctk.CTkFont(size=13)
            )
            empty_lbl.pack(pady=40)
            return

        # Render in a clean grid (5 columns)
        cols = 5
        for idx, (pack, icon) in enumerate(filtered_icons):
            row = idx // cols
            col = idx % cols

            card = ctk.CTkFrame(
                self.icons_scroll,
                fg_color="#182030" if self.selected_icon_path == icon["path"] else "#121724",
                border_color="#3abfc3" if self.selected_icon_path == icon["path"] else "#1a2233",
                border_width=2 if self.selected_icon_path == icon["path"] else 1,
                corner_radius=12,
                width=140,
                height=135
            )
            card.grid(row=row, column=col, padx=8, pady=8, sticky="nsew")
            card.bind("<Button-1>", lambda e, p=icon["path"], n=icon["name"]: self._select_icon(p, n))

            # Thumbnail Image Preview
            thumb_path = mcons_core.get_icon_thumbnail_path(icon["path"], size=44)
            if thumb_path and os.path.exists(thumb_path):
                if thumb_path not in self.icon_cache:
                    try:
                        pil_im = Image.open(thumb_path)
                        self.icon_cache[thumb_path] = ctk.CTkImage(light_image=pil_im, dark_image=pil_im, size=(44, 44))
                    except Exception:
                        pass
                if thumb_path in self.icon_cache:
                    img = self.icon_cache[thumb_path]
                    img_lbl = ctk.CTkLabel(card, text="", image=img)
                    img_lbl.pack(pady=(10, 2))
                    img_lbl.bind("<Button-1>", lambda e, p=icon["path"], n=icon["name"]: self._select_icon(p, n))

            name_lbl = ctk.CTkLabel(
                card,
                text=icon["name"],
                font=ctk.CTkFont(size=11, weight="bold"),
                text_color="#f8fafc"
            )
            name_lbl.pack(pady=(4, 1), padx=6)
            name_lbl.bind("<Button-1>", lambda e, p=icon["path"], n=icon["name"]: self._select_icon(p, n))

            pack_lbl = ctk.CTkLabel(
                card,
                text=pack["name"],
                font=ctk.CTkFont(size=9),
                text_color="#94a3b8"
            )
            pack_lbl.pack(pady=(0, 10), padx=6)
            pack_lbl.bind("<Button-1>", lambda e, p=icon["path"], n=icon["name"]: self._select_icon(p, n))

    def _select_icon(self, icon_path: str, icon_name: str):
        self.selected_icon_path = icon_path
        self.selected_icon_name = icon_name
        self.selection_label.configure(
            text=f"Selected Icon: {icon_name}",
            text_color="#3abfc3"
        )
        self._render_icons_grid()

    def _on_apply_icon(self):
        target = self.folder_path_entry.get().strip()
        if not target or not os.path.isdir(target):
            messagebox.showerror("Error", "Please select a valid target folder first.")
            return

        if not self.selected_icon_path:
            messagebox.showerror("Error", "Please select an icon to apply.")
            return

        success, msg = mcons_core.apply_folder_icon(target, self.selected_icon_path)
        if success:
            self.status_label.configure(text="✓ Applied icon successfully!", text_color="#10b981")
            messagebox.showinfo("Success", f"Custom icon applied to:\n{target}\n\nWindows Explorer has been refreshed!")
        else:
            self.status_label.configure(text=f"Failed: {msg}", text_color="#ef4444")
            messagebox.showerror("Error", msg)

    def _on_restore_icon(self):
        target = self.folder_path_entry.get().strip()
        if not target or not os.path.isdir(target):
            messagebox.showerror("Error", "Please select a valid folder to restore.")
            return

        success, msg = mcons_core.restore_folder_icon(target)
        if success:
            self.status_label.configure(text="✓ Restored default folder icon", text_color="#38bdf8")
            messagebox.showinfo("Restored", f"Default folder icon restored for:\n{target}")
        else:
            messagebox.showerror("Error", msg)

    def _on_apply_batch(self):
        parent = self.batch_parent_entry.get().strip()
        if not parent or not os.path.isdir(parent):
            messagebox.showerror("Error", "Please select a valid parent folder.")
            return

        if not self.selected_icon_path:
            messagebox.showerror("Error", "Please select an icon in the 'Single Folder' tab first.")
            return

        subdirs = [os.path.join(parent, d) for d in os.listdir(parent) if os.path.isdir(os.path.join(parent, d))]
        if not subdirs:
            messagebox.showinfo("Info", "No subfolders found inside the selected parent directory.")
            return

        self.batch_log_box.delete("1.0", "end")
        self.batch_log_box.insert("end", f"Starting batch apply to {len(subdirs)} subfolders...\n\n")

        success_count = 0
        for s in subdirs:
            ok, msg = mcons_core.apply_folder_icon(s, self.selected_icon_path)
            if ok:
                success_count += 1
                self.batch_log_box.insert("end", f"[OK] {os.path.basename(s)}\n")
            else:
                self.batch_log_box.insert("end", f"[FAIL] {os.path.basename(s)}: {msg}\n")

        self.batch_log_box.insert("end", f"\nCompleted: {success_count}/{len(subdirs)} folders updated.")
        messagebox.showinfo("Batch Complete", f"Applied icons to {success_count} folders!")


def cli_main():
    # If running CLI commands from cmd/powershell, attach console so stdout/stderr output directly
    if any(arg in sys.argv[1:] for arg in ["apply", "restore", "list", "--help", "-h"]):
        if sys.platform == "win32":
            try:
                import ctypes
                if ctypes.windll.kernel32.AttachConsole(-1):
                    sys.stdout = open("CONOUT$", "w", encoding="utf-8")
                    sys.stderr = open("CONOUT$", "w", encoding="utf-8")
            except Exception:
                pass

    # If direct folder path passed (e.g. from Windows Explorer context menu)
    if len(sys.argv) > 1 and not sys.argv[1].startswith("-") and sys.argv[1] not in ["apply", "restore", "list"]:
        folder_arg = sys.argv[1]
        if os.path.isdir(folder_arg):
            app = MConsWindowsApp(initial_folder=folder_arg)
            app.mainloop()
            return

    parser = argparse.ArgumentParser(description="MCons for Windows — Desktop Folder Icon Customizer")
    parser.add_argument("--folder", help="Target folder to open in GUI", default=None)
    subparsers = parser.add_subparsers(dest="command")

    apply_p = subparsers.add_parser("apply", help="Apply icon to folder")
    apply_p.add_argument("folder", help="Target folder path")
    apply_p.add_argument("--icon", required=True, help="Icon SVG or ICO path, or icon name")

    restore_p = subparsers.add_parser("restore", help="Restore default folder icon")
    restore_p.add_argument("folder", help="Target folder path")

    list_p = subparsers.add_parser("list", help="List bundled icon packs")

    args = parser.parse_args()

    if args.command == "apply":
        ok, msg = mcons_core.apply_folder_icon(args.folder, args.icon)
        print(msg)
        sys.exit(0 if ok else 1)
    elif args.command == "restore":
        ok, msg = mcons_core.restore_folder_icon(args.folder)
        print(msg)
        sys.exit(0 if ok else 1)
    elif args.command == "list":
        packs = mcons_core.load_all_packs()
        print(f"Bundled Packs ({len(packs)}):")
        for p in packs:
            print(f"  [{p['id']}] {p['name']} ({p['count']} icons) - {p['category']}")
        sys.exit(0)
    else:
        # Launch GUI
        app = MConsWindowsApp(initial_folder=args.folder)
        app.mainloop()


if __name__ == "__main__":
    cli_main()
