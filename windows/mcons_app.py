"""MCons for Windows — Exact macOS SwiftUI Replica
Faithfully replicates the macOS MCons JetBlack design system, NavigationSplitView sidebar,
Home dashboard with Quick Action cards and PackPreviewCard banners, Icon Packs with 2-column
wide banner cards displaying real floating icon samples, Pack Detail drill-down, Favorites,
Icon Apply with 2-column Before -> After preview, Batch Apply, Pack Builder, Settings, and About.
"""

import os
import sys
import shutil
import subprocess
import argparse
import webbrowser
from typing import List, Dict, Optional, Tuple
from PIL import Image, ImageTk
import customtkinter as ctk
from tkinter import filedialog, messagebox

# Ensure local import
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mcons_core

# Exception logging hook
import traceback

def log_debug(msg):
    try:
        log_path = os.path.join(os.path.expanduser("~"), "mcons_debug.log")
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"{msg}\n")
            f.flush()
            os.fsync(f.fileno())
    except Exception:
        pass

def unhandled_handler(exc_type, exc_value, exc_traceback):
    err_text = "".join(traceback.format_exception(exc_type, exc_value, exc_traceback))
    try:
        log_path = os.path.join(os.path.expanduser("~"), "mcons_debug.log")
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(err_text + "\n")
            f.flush()
            os.fsync(f.fileno())
    except Exception:
        pass
    try:
        import ctypes
        ctypes.windll.user32.MessageBoxW(0, f"MCons encountered an error:\n\n{err_text[:1000]}", "MCons Error", 0x10)
    except Exception:
        pass

sys.excepthook = unhandled_handler

# High-DPI Awareness and AppUserModelID on Windows
if sys.platform == "win32":
    try:
        import ctypes
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("NeelJ.MCons.Windows.1.0")
        ctypes.windll.shcore.SetProcessDpiAwareness(2)
    except Exception:
        try:
            import ctypes
            ctypes.windll.user32.SetProcessDPIAware()
        except Exception:
            pass

try:
    ctk.set_appearance_mode("Dark")
    ctk.set_default_color_theme("blue")
except Exception:
    pass

# =============================================================================
# JetBlack Design System Constants (Exact match to MCons AppTheme.swift)
# =============================================================================
COLOR_SIDEBAR_BG = "#08090D"     # JetBlack Sidebar Background
COLOR_CANVAS_BG = "#0C0E14"      # JetBlack Canvas Background
COLOR_CARD_BG = "#13151F"        # JetBlack Card Surface
COLOR_CARD_SURFACE = "#1A1D2A"   # JetBlack Elevated Surface / Chips
COLOR_ACCENT = "#6366F1"         # Primary Electric Violet/Indigo Accent
COLOR_ACCENT_HOVER = "#4F46E5"   # Accent Hover
COLOR_ACCENT_GRAD_END = "#8B5CF6"# Accent Gradient End
COLOR_TEXT_PRIMARY = "#FFFFFF"
COLOR_TEXT_SECONDARY = "#94A3B8"
COLOR_TEXT_MUTED = "#64748B"
COLOR_SUCCESS = "#10B981"
COLOR_WARNING = "#F59E0B"
COLOR_ERROR = "#F43F5E"
COLOR_BORDER = "#1E2235"
COLOR_SIDEBAR_ACTIVE = "#1A1D2E"
COLOR_CYAN = "#00D2FF"

# Fallback fonts (overridden dynamically by OS capabilities in app init)
FONT_FAMILY = "Segoe UI Variable Text"
FONT_DISPLAY = "Segoe UI Variable Display"
FONT_ICON = "Segoe Fluent Icons"


class MConsWindowsApp(ctk.CTk):
    """
    Main MCons Windows Application
    Faithfully replicates the macOS MCons interface and features.
    """
    def __init__(self, initial_folder: Optional[str] = None):
        super().__init__()

        # Detect native Windows typography & vector icon font
        fams = self.tk.call("font", "families")
        self.font_family = "Segoe UI Variable Text" if "Segoe UI Variable Text" in fams else "Segoe UI"
        self.font_display = "Segoe UI Variable Display" if "Segoe UI Variable Display" in fams else self.font_family
        self.font_icon = "Segoe Fluent Icons" if "Segoe Fluent Icons" in fams else ("Segoe MDL2 Assets" if "Segoe MDL2 Assets" in fams else "Segoe UI")

        global FONT_FAMILY, FONT_DISPLAY, FONT_ICON
        FONT_FAMILY = self.font_family
        FONT_DISPLAY = self.font_display
        FONT_ICON = self.font_icon

        self.title("MCons — Icons for Windows")
        self.geometry("1120x740")
        self.minsize(960, 640)
        self.configure(fg_color=COLOR_SIDEBAR_BG)

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

        # Data & State
        self.packs = mcons_core.load_all_packs()
        self.icon_cache: Dict[str, ctk.CTkImage] = {}
        self.selected_folder: Optional[str] = None
        self.custom_folder_name: str = ""
        self.selected_icon_path: Optional[str] = None
        self.selected_icon_name: Optional[str] = None
        self.selected_icon_pack: Optional[str] = None
        self.current_nav: str = "home"
        self.pack_detail_id: Optional[str] = None
        self.search_query: str = ""
        self.search_scope: str = "Packs"  # "Packs" or "All Icons"
        self.active_category: str = "All"
        self.recent_folders: List[str] = []

        # Build NavigationSplitView layout
        self._build_main_layout()

        # Windows Platform Optimizations: DWM Theme & Keyboard Shortcuts
        self._apply_windows_theme()
        self._bind_windows_shortcuts()

        if initial_folder and os.path.isdir(initial_folder):
            self.selected_folder = os.path.abspath(initial_folder)
            self.custom_folder_name = os.path.basename(self.selected_folder)
            self._navigate_to("apply")
        else:
            self._navigate_to("home")

    # =========================================================================
    # WINDOWS PLATFORM INTEGRATIONS (DWM THEME & KEYBOARD ACCELERATORS)
    # =========================================================================

    def _apply_windows_theme(self):
        """Applies Windows 10/11 DWM dark titlebar, caption colors, and Mica backdrop"""
        if sys.platform != "win32":
            return
        try:
            import ctypes
            from ctypes import wintypes
            self.update_idletasks()
            hwnd = ctypes.windll.user32.GetParent(self.winfo_id()) or self.winfo_id()

            val_true = ctypes.c_int(1)
            # DWMWA_USE_IMMERSIVE_DARK_MODE (20 on Win 10 20H1+, 19 on older builds)
            if ctypes.windll.dwmapi.DwmSetWindowAttribute(
                wintypes.HWND(hwnd),
                ctypes.c_uint(20),
                ctypes.byref(val_true),
                ctypes.sizeof(val_true)
            ) != 0:
                ctypes.windll.dwmapi.DwmSetWindowAttribute(
                    wintypes.HWND(hwnd),
                    ctypes.c_uint(19),
                    ctypes.byref(val_true),
                    ctypes.sizeof(val_true)
                )

            # DWMWA_WINDOW_CORNER_PREFERENCE = 33 (2 = DWMWCP_ROUND on Windows 11)
            corner_val = ctypes.c_int(2)
            ctypes.windll.dwmapi.DwmSetWindowAttribute(
                wintypes.HWND(hwnd),
                ctypes.c_uint(33),
                ctypes.byref(corner_val),
                ctypes.sizeof(corner_val)
            )

            # DWMWA_BORDER_COLOR = 34 (BGR: 0x0035221E for subtle border #1E2235)
            border_color = ctypes.c_uint(0x0035221E)
            ctypes.windll.dwmapi.DwmSetWindowAttribute(
                wintypes.HWND(hwnd),
                ctypes.c_uint(34),
                ctypes.byref(border_color),
                ctypes.sizeof(border_color)
            )

            # DWMWA_CAPTION_COLOR = 35 (BGR: 0x000D0908 for JetBlack #08090D)
            title_color = ctypes.c_uint(0x000D0908)
            ctypes.windll.dwmapi.DwmSetWindowAttribute(
                wintypes.HWND(hwnd),
                ctypes.c_uint(35),
                ctypes.byref(title_color),
                ctypes.sizeof(title_color)
            )

            # DWMWA_TEXT_COLOR = 36 (White #FFFFFF -> 0x00FFFFFF)
            text_color = ctypes.c_uint(0x00FFFFFF)
            ctypes.windll.dwmapi.DwmSetWindowAttribute(
                wintypes.HWND(hwnd),
                ctypes.c_uint(36),
                ctypes.byref(text_color),
                ctypes.sizeof(text_color)
            )

            # DWMWA_SYSTEMBACKDROP_TYPE = 38 (2 = Mica on Windows 11 22H2+)
            mica_val = ctypes.c_int(2)
            ctypes.windll.dwmapi.DwmSetWindowAttribute(
                wintypes.HWND(hwnd),
                ctypes.c_uint(38),
                ctypes.byref(mica_val),
                ctypes.sizeof(mica_val)
            )
        except Exception:
            pass

    def _bind_windows_shortcuts(self):
        """Binds standard Windows desktop keyboard accelerators"""
        self.bind("<Control-Key-1>", lambda e: self._navigate_to("home"))
        self.bind("<Control-Key-2>", lambda e: self._navigate_to("packs"))
        self.bind("<Control-Key-3>", lambda e: self._navigate_to("favorites"))
        self.bind("<Control-Key-4>", lambda e: self._navigate_to("apply"))
        self.bind("<Control-Key-5>", lambda e: self._navigate_to("batch"))
        self.bind("<Control-Key-6>", lambda e: self._navigate_to("builder"))
        self.bind("<Control-comma>", lambda e: self._navigate_to("settings"))
        self.bind("<Control-f>", lambda e: self._on_shortcut_find())
        self.bind("<Control-F>", lambda e: self._on_shortcut_find())
        self.bind("<Escape>", lambda e: self._on_shortcut_escape())
        self.bind("<F5>", lambda e: self._on_shortcut_refresh())
        self.bind("<Control-v>", lambda e: self._on_paste_clipboard_path())
        self.bind("<Control-V>", lambda e: self._on_paste_clipboard_path())

    def _on_shortcut_find(self):
        if self.current_nav != "packs" or self.pack_detail_id is not None:
            self._navigate_to("packs")
        if hasattr(self, "pack_search_entry") and self.pack_search_entry.winfo_exists():
            self.pack_search_entry.focus_set()
            self.pack_search_entry.select_range(0, 'end')
        return "break"

    def _on_shortcut_escape(self):
        if self.current_nav == "packs" and self.pack_detail_id:
            self._navigate_to("packs")

    def _on_shortcut_refresh(self):
        self.packs = mcons_core.load_all_packs()
        self._navigate_to(self.current_nav, self.pack_detail_id)

    def _on_paste_clipboard_path(self):
        try:
            clip = self.clipboard_get().strip().strip('"').strip("'")
            if os.path.isdir(clip):
                self.selected_folder = os.path.abspath(clip)
                self.custom_folder_name = os.path.basename(self.selected_folder)
                if self.current_nav != "apply":
                    self._navigate_to("apply")
                else:
                    self._render_apply_view()
        except Exception:
            pass

    # =========================================================================
    # LAYOUT: SIDEBAR (LEFT) + DETAIL VIEW (RIGHT)
    # =========================================================================

    def _build_main_layout(self):
        # 1. Left Sidebar (Fixed 228px width, matching macOS ideal sidebar width)
        self.sidebar_frame = ctk.CTkFrame(
            self,
            width=228,
            corner_radius=0,
            fg_color=COLOR_SIDEBAR_BG,
            border_width=0
        )
        self.sidebar_frame.pack(side="left", fill="y", padx=0, pady=0)
        self.sidebar_frame.pack_propagate(False)

        self._build_sidebar()

        # Vertical Divider Line
        divider = ctk.CTkFrame(self, width=1, corner_radius=0, fg_color=COLOR_BORDER)
        divider.pack(side="left", fill="y")

        # 2. Right Detail Content Container (Expands)
        self.content_container = ctk.CTkFrame(
            self,
            corner_radius=0,
            fg_color=COLOR_CANVAS_BG,
            border_width=0
        )
        self.content_container.pack(side="right", fill="both", expand=True)

    def _build_sidebar(self):
        # App Brand Header (Mirrors appBrandHeader in ContentView.swift)
        brand = ctk.CTkFrame(self.sidebar_frame, fg_color="transparent")
        brand.pack(fill="x", padx=14, pady=(16, 10))

        # 30x30 App Icon
        icon_img = self._get_image_thumbnail("windows/mcons.ico", size=30)
        if icon_img:
            app_logo = ctk.CTkLabel(brand, text="", image=icon_img)
            app_logo.pack(side="left", padx=(0, 8))
        else:
            app_logo = ctk.CTkLabel(brand, text="⚡", font=ctk.CTkFont(size=20, weight="bold"), text_color=COLOR_ACCENT)
            app_logo.pack(side="left", padx=(0, 8))

        # Title & Subtitle column
        title_col = ctk.CTkFrame(brand, fg_color="transparent")
        title_col.pack(side="left", fill="y")

        t_lbl = ctk.CTkLabel(
            title_col,
            text="MCons",
            font=ctk.CTkFont(family="Segoe UI", size=14, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        t_lbl.pack(anchor="w")

        sub_lbl = ctk.CTkLabel(
            title_col,
            text="Icons for Windows",
            font=ctk.CTkFont(family="Segoe UI", size=10),
            text_color=COLOR_TEXT_SECONDARY
        )
        sub_lbl.pack(anchor="w")

        # Version Pill Badge on far right (Capsule style)
        ver_pill = ctk.CTkLabel(
            brand,
            text="v1.0.4",
            font=ctk.CTkFont(family="Consolas", size=9, weight="bold"),
            fg_color=COLOR_CARD_SURFACE,
            text_color=COLOR_TEXT_SECONDARY,
            corner_radius=8,
            height=18,
            padx=6
        )
        ver_pill.pack(side="right")

        # Thin Divider
        div = ctk.CTkFrame(self.sidebar_frame, height=1, fg_color=COLOR_BORDER)
        div.pack(fill="x", padx=14, pady=(0, 10))

        # Scrollable Navigation Items
        self.nav_scroll = ctk.CTkScrollableFrame(
            self.sidebar_frame,
            fg_color="transparent",
            scrollbar_button_color=COLOR_CARD_BG,
            scrollbar_button_hover_color=COLOR_BORDER
        )
        self.nav_scroll.pack(fill="both", expand=True, padx=8, pady=0)

        self.sidebar_rows: Dict[str, Dict] = {}

        # DISCOVER Group
        self._add_nav_group_header("DISCOVER")
        self._add_sidebar_row("home", "\uE80F", "Home")
        self._add_sidebar_row("packs", "\uE71D", "Icon Packs", badge=str(len(self.packs)))
        self._add_sidebar_row("favorites", "\uEB52", "Favorites", badge="0")
        self._add_sidebar_row("apply", "\uE790", "Apply Icon")
        self._add_sidebar_row("batch", "\uE8D4", "Batch Apply")
        self._add_sidebar_row("builder", "\uEC7A", "Pack Builder")

        # PREFERENCES Group
        self._add_nav_group_header("PREFERENCES")
        self._add_sidebar_row("settings", "\uE713", "Settings")
        self._add_sidebar_row("about", "\uE946", "About")

    def _add_nav_group_header(self, text: str):
        lbl = ctk.CTkLabel(
            self.nav_scroll,
            text=text,
            font=ctk.CTkFont(family=self.font_family, size=10, weight="bold"),
            text_color=COLOR_TEXT_MUTED
        )
        lbl.pack(anchor="w", padx=10, pady=(12, 4))

    def _add_sidebar_row(self, nav_id: str, icon_symbol: str, label_text: str, badge: Optional[str] = None):
        row = ctk.CTkFrame(self.nav_scroll, fg_color="transparent", height=34, corner_radius=6)
        row.pack(fill="x", pady=2)
        row.pack_propagate(False)

        # Leading 3px vertical accent indicator bar
        bar = ctk.CTkFrame(row, width=3, height=16, corner_radius=2, fg_color="transparent")
        bar.pack(side="left", padx=(4, 6))

        # Vector Symbol / Icon (Segoe Fluent Icons / MDL2 Assets)
        sym = ctk.CTkLabel(
            row,
            text=icon_symbol,
            font=ctk.CTkFont(family=self.font_icon, size=13),
            width=22,
            text_color=COLOR_TEXT_SECONDARY
        )
        sym.pack(side="left")

        # Label Text
        lbl = ctk.CTkLabel(
            row,
            text=label_text,
            font=ctk.CTkFont(family=self.font_family, size=13),
            text_color=COLOR_TEXT_SECONDARY,
            anchor="w"
        )
        lbl.pack(side="left", fill="x", expand=True, padx=(6, 0))

        # Optional Pill Badge
        badge_lbl = None
        if badge is not None:
            badge_lbl = ctk.CTkLabel(
                row,
                text=badge,
                font=ctk.CTkFont(family=self.font_family, size=10, weight="bold"),
                fg_color=COLOR_CARD_SURFACE,
                text_color=COLOR_TEXT_SECONDARY,
                corner_radius=8,
                height=18,
                padx=6
            )
            badge_lbl.pack(side="right", padx=(0, 6))

        # Click handler on row & children
        for widget in [row, sym, lbl]:
            widget.bind("<Button-1>", lambda e, n=nav_id: self._navigate_to(n))

        self.sidebar_rows[nav_id] = {
            "row": row,
            "bar": bar,
            "sym": sym,
            "lbl": lbl,
            "badge": badge_lbl
        }

    def _update_sidebar_active_state(self, active_nav: str):
        for nid, elements in self.sidebar_rows.items():
            if nid == active_nav:
                elements["row"].configure(fg_color=COLOR_SIDEBAR_ACTIVE)
                elements["bar"].configure(fg_color=COLOR_ACCENT)
                elements["sym"].configure(text_color=COLOR_ACCENT)
                elements["lbl"].configure(text_color=COLOR_TEXT_PRIMARY, font=ctk.CTkFont(family=self.font_family, size=13, weight="bold"))
                if elements["badge"]:
                    elements["badge"].configure(fg_color=COLOR_ACCENT, text_color="#FFFFFF")
            else:
                elements["row"].configure(fg_color="transparent")
                elements["bar"].configure(fg_color="transparent")
                elements["sym"].configure(text_color=COLOR_TEXT_SECONDARY)
                elements["lbl"].configure(text_color=COLOR_TEXT_SECONDARY, font=ctk.CTkFont(family=self.font_family, size=13, weight="normal"))
                if elements["badge"]:
                    elements["badge"].configure(fg_color=COLOR_CARD_SURFACE, text_color=COLOR_TEXT_SECONDARY)

        # Update favorites count badge
        favs = mcons_core.get_favorites()
        if "favorites" in self.sidebar_rows and self.sidebar_rows["favorites"]["badge"]:
            self.sidebar_rows["favorites"]["badge"].configure(text=str(len(favs)))

    def _navigate_to(self, nav_id: str, pack_id: Optional[str] = None):
        self.current_nav = nav_id
        self.pack_detail_id = pack_id
        self._update_sidebar_active_state(nav_id)

        # Clear Content Container
        for child in self.content_container.winfo_children():
            child.destroy()

        if nav_id == "home":
            self._render_home_view()
        elif nav_id == "packs":
            if self.pack_detail_id:
                self._render_pack_detail_view(self.pack_detail_id)
            else:
                self._render_packs_view()
        elif nav_id == "favorites":
            self._render_favorites_view()
        elif nav_id == "apply":
            self._render_apply_view()
        elif nav_id == "batch":
            self._render_batch_view()
        elif nav_id == "builder":
            self._render_builder_view()
        elif nav_id == "settings":
            self._render_settings_view()
        elif nav_id == "about":
            self._render_about_view()

    # =========================================================================
    # VIEW 1: HOME DASHBOARD (Exact Replica of HomeView.swift)
    # =========================================================================

    def _render_home_view(self):
        scroll = ctk.CTkScrollableFrame(self.content_container, fg_color="transparent")
        scroll.pack(fill="both", expand=True, padx=32, pady=24)

        # 1. Hero Section (Centered App Icon + Typography)
        hero = ctk.CTkFrame(scroll, fg_color="transparent")
        hero.pack(fill="x", pady=(0, 28))

        app_icon = self._get_image_thumbnail("windows/mcons.ico", size=88)
        if app_icon:
            icon_lbl = ctk.CTkLabel(hero, text="", image=app_icon)
            icon_lbl.pack(pady=(0, 10))

        title_lbl = ctk.CTkLabel(
            hero,
            text="MCons",
            font=ctk.CTkFont(family="Segoe UI", size=32, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        title_lbl.pack()

        subtitle_lbl = ctk.CTkLabel(
            hero,
            text="Icons for Windows",
            font=ctk.CTkFont(family="Segoe UI", size=18, weight="bold"),
            text_color=COLOR_ACCENT_GRAD_END
        )
        subtitle_lbl.pack(pady=(2, 6))

        tagline_lbl = ctk.CTkLabel(
            hero,
            text="Customize your folders with stunning handcrafted vector icon packs",
            font=ctk.CTkFont(family="Segoe UI", size=13),
            text_color=COLOR_TEXT_SECONDARY
        )
        tagline_lbl.pack()

        # 2. Quick Actions Section (Exact replica of QuickActionCard in HomeView.swift)
        qa_title = ctk.CTkLabel(
            scroll,
            text="Quick Actions",
            font=ctk.CTkFont(family="Segoe UI", size=18, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        qa_title.pack(anchor="w", pady=(0, 12))

        qa_row = ctk.CTkFrame(scroll, fg_color="transparent")
        qa_row.pack(fill="x", pady=(0, 28))
        qa_row.columnconfigure((0, 1, 2), weight=1, uniform="qa")

        # Card 1: Create & Style (Electric Violet Gradient)
        self._build_mac_quick_action_card(
            qa_row, 0,
            symbol="\uED25",
            title="Create & Style",
            subtitle="New folder with icon",
            gradient_bg="#6C5CE7",
            action=lambda: self._navigate_to("apply")
        )

        # Card 2: Browse Packs (Emerald Teal Gradient)
        self._build_mac_quick_action_card(
            qa_row, 1,
            symbol="\uE71D",
            title="Browse Packs",
            subtitle=f"{len(self.packs)} packs available",
            gradient_bg="#00B894",
            action=lambda: self._navigate_to("packs")
        )

        # Card 3: Custom Icon (Warm Coral Gradient)
        self._build_mac_quick_action_card(
            qa_row, 2,
            symbol="\uEB9F",
            title="Custom Icon",
            subtitle="Use your own image",
            gradient_bg="#E17055",
            action=lambda: self._navigate_to("apply")
        )

        # 3. Featured Packs Section (PackPreviewCard in HomeView.swift)
        fp_header = ctk.CTkFrame(scroll, fg_color="transparent")
        fp_header.pack(fill="x", pady=(0, 12))

        fp_title = ctk.CTkLabel(
            fp_header,
            text="Icon Packs",
            font=ctk.CTkFont(family=self.font_family, size=18, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        fp_title.pack(side="left")

        view_all_btn = ctk.CTkButton(
            fp_header,
            text="View All \uE76C",
            font=ctk.CTkFont(family=self.font_family, size=12, weight="bold"),
            fg_color="transparent",
            text_color=COLOR_ACCENT,
            hover_color=COLOR_CARD_BG,
            width=80,
            height=26,
            command=lambda: self._navigate_to("packs")
        )
        view_all_btn.pack(side="right")

        # 3-Column Preview Cards Grid
        fp_grid = ctk.CTkFrame(scroll, fg_color="transparent")
        fp_grid.pack(fill="x", pady=(0, 24))
        for c in range(3):
            fp_grid.columnconfigure(c, weight=1, uniform="preview_card")

        featured = self.packs[:3]
        for col_idx, pack in enumerate(featured):
            card = self._build_pack_preview_card(fp_grid, pack)
            card.grid(row=0, column=col_idx, padx=6, sticky="nsew")

    def _build_mac_quick_action_card(self, parent, col, symbol, title, subtitle, gradient_bg, action):
        """Replicates QuickActionCard with 56x56 gradient symbol box + title + subtitle"""
        card = ctk.CTkFrame(
            parent,
            fg_color=COLOR_CARD_BG,
            corner_radius=14,
            border_width=1,
            border_color=COLOR_BORDER,
            height=130
        )
        card.grid(row=0, column=col, padx=6, sticky="nsew")
        card.pack_propagate(False)

        inner = ctk.CTkFrame(card, fg_color="transparent")
        inner.pack(fill="both", expand=True, padx=16, pady=16)

        # 52x52 Gradient Box
        icon_box = ctk.CTkFrame(inner, width=52, height=52, corner_radius=12, fg_color=gradient_bg)
        icon_box.pack(pady=(0, 8))
        icon_box.pack_propagate(False)

        sym_lbl = ctk.CTkLabel(icon_box, text=symbol, font=ctk.CTkFont(family=self.font_icon, size=24), text_color="#FFFFFF")
        sym_lbl.place(relx=0.5, rely=0.5, anchor="center")

        t_lbl = ctk.CTkLabel(
            inner,
            text=title,
            font=ctk.CTkFont(family=self.font_family, size=14, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        t_lbl.pack()

        sub_lbl = ctk.CTkLabel(
            inner,
            text=subtitle,
            font=ctk.CTkFont(family=self.font_family, size=11),
            text_color=COLOR_TEXT_SECONDARY
        )
        sub_lbl.pack(pady=(2, 0))

        for w in [card, inner, icon_box, sym_lbl, t_lbl, sub_lbl]:
            w.bind("<Button-1>", lambda e, act=action: act())

    def _build_pack_preview_card(self, parent, pack: Dict) -> ctk.CTkFrame:
        """Replicates PackPreviewCard in HomeView.swift with floating icon samples in banner"""
        card = ctk.CTkFrame(
            parent,
            fg_color=COLOR_CARD_BG,
            corner_radius=14,
            border_width=1,
            border_color=COLOR_BORDER,
            height=140
        )
        card.pack_propagate(False)

        # Top Banner with Accent Tint Background
        accent_color = pack.get("accentColorHex", "#6366F1")
        banner = ctk.CTkFrame(card, fg_color=self._tint_hex(accent_color, 0.25), corner_radius=10, height=80)
        banner.pack(fill="x", padx=10, pady=(10, 8))
        banner.pack_propagate(False)

        # 3 floating preview icons
        icons_row = ctk.CTkFrame(banner, fg_color="transparent")
        icons_row.place(relx=0.5, rely=0.5, anchor="center")

        for icon in pack["icons"][:3]:
            thumb = self._get_image_thumbnail(icon["path"], size=44)
            if thumb:
                img_lbl = ctk.CTkLabel(icons_row, text="", image=thumb)
                img_lbl.pack(side="left", padx=6)

        # Bottom Info
        info = ctk.CTkFrame(card, fg_color="transparent")
        info.pack(fill="x", padx=12, pady=(0, 10))

        name_lbl = ctk.CTkLabel(
            info,
            text=pack["name"],
            font=ctk.CTkFont(family="Segoe UI", size=14, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        name_lbl.pack(anchor="w")

        count_lbl = ctk.CTkLabel(
            info,
            text=f"{pack['count']} icons",
            font=ctk.CTkFont(size=11),
            text_color=COLOR_TEXT_SECONDARY
        )
        count_lbl.pack(anchor="w")

        for w in [card, banner, info, name_lbl, count_lbl]:
            w.bind("<Button-1>", lambda e, p=pack["id"]: self._navigate_to("packs", pack_id=p))

        return card

    # =========================================================================
    # VIEW 2: ICON PACKS (Exact 2-Column Replica of IconPacksView.swift)
    # =========================================================================

    def _render_packs_view(self):
        container = ctk.CTkScrollableFrame(self.content_container, fg_color="transparent")
        container.pack(fill="both", expand=True, padx=32, pady=24)

        # Header Row
        head_row = ctk.CTkFrame(container, fg_color="transparent")
        head_row.pack(fill="x", pady=(0, 16))

        h_left = ctk.CTkFrame(head_row, fg_color="transparent")
        h_left.pack(side="left")

        title = ctk.CTkLabel(
            h_left,
            text="Icon Packs",
            font=ctk.CTkFont(family=self.font_display, size=28, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        title.pack(anchor="w")

        total_icons = sum(p["count"] for p in self.packs)
        sub = ctk.CTkLabel(
            h_left,
            text=f"Choose a pack or search across {total_icons}+ vector desktop icons",
            font=ctk.CTkFont(family=self.font_family, size=13),
            text_color=COLOR_TEXT_SECONDARY
        )
        sub.pack(anchor="w")

        create_btn = ctk.CTkButton(
            head_row,
            text="\uE710  Create Pack",
            font=ctk.CTkFont(family=self.font_family, size=12, weight="bold"),
            fg_color=COLOR_ACCENT,
            hover_color=COLOR_ACCENT_HOVER,
            corner_radius=14,
            height=32,
            width=110,
            command=lambda: self._navigate_to("builder")
        )
        create_btn.pack(side="right")

        # Search Bar & Scope Picker Card
        search_card = ctk.CTkFrame(container, fg_color=COLOR_CARD_BG, corner_radius=12, border_width=1, border_color=COLOR_BORDER)
        search_card.pack(fill="x", pady=(0, 14))

        sc_inner = ctk.CTkFrame(search_card, fg_color="transparent")
        sc_inner.pack(fill="x", padx=14, pady=10)

        mag_lbl = ctk.CTkLabel(sc_inner, text="\uE721", font=ctk.CTkFont(family=self.font_icon, size=13), text_color=COLOR_TEXT_SECONDARY)
        mag_lbl.pack(side="left", padx=(0, 8))

        self.pack_search_entry = ctk.CTkEntry(
            sc_inner,
            placeholder_text="Search packs or characters (e.g. Naruto, Python, Chrome)...",
            height=32,
            fg_color="transparent",
            border_width=0,
            font=ctk.CTkFont(family=self.font_family, size=13)
        )
        self.pack_search_entry.pack(side="left", fill="x", expand=True)
        self.pack_search_entry.bind("<KeyRelease>", self._on_pack_search_changed)

        # Scope Picker ("Packs" | "All Icons")
        self.scope_menu = ctk.CTkSegmentedButton(
            sc_inner,
            values=["Packs", "All Icons"],
            command=self._on_scope_changed,
            selected_color=COLOR_ACCENT,
            selected_hover_color=COLOR_ACCENT_HOVER,
            unselected_color=COLOR_CARD_SURFACE,
            corner_radius=8,
            height=28
        )
        self.scope_menu.set(self.search_scope)
        self.scope_menu.pack(side="right", padx=(8, 0))

        # Category Filter Pills (Shown in Packs scope)
        self.cat_chip_frame = ctk.CTkFrame(container, fg_color="transparent")
        self.cat_chip_frame.pack(fill="x", pady=(0, 16))

        categories = ["All", "Anime", "Tech & Dev", "Hardware", "System & Minimal", "Gaming & Anime"]
        self.cat_chips = []
        for cat in categories:
            btn = ctk.CTkButton(
                self.cat_chip_frame,
                text=cat,
                font=ctk.CTkFont(family="Segoe UI", size=11, weight="bold" if cat == self.active_category else "normal"),
                fg_color=COLOR_ACCENT if cat == self.active_category else COLOR_CARD_SURFACE,
                hover_color=COLOR_CARD_BG,
                text_color=COLOR_TEXT_PRIMARY if cat == self.active_category else COLOR_TEXT_SECONDARY,
                corner_radius=14,
                height=28,
                width=64,
                command=lambda c=cat: self._on_select_category(c)
            )
            btn.pack(side="left", padx=3)
            self.cat_chips.append((cat, btn))

        # Dynamic Grid Container
        self.packs_grid_container = ctk.CTkFrame(container, fg_color="transparent")
        self.packs_grid_container.pack(fill="both", expand=True)

        self._populate_packs_content()

    def _on_pack_search_changed(self, event=None):
        self.search_query = self.pack_search_entry.get().strip().lower()
        self._populate_packs_content()

    def _on_scope_changed(self, new_scope: str):
        self.search_scope = new_scope
        self._populate_packs_content()

    def _on_select_category(self, cat: str):
        self.active_category = cat
        for c, btn in self.cat_chips:
            if c == cat:
                btn.configure(fg_color=COLOR_ACCENT, text_color=COLOR_TEXT_PRIMARY, font=ctk.CTkFont(size=11, weight="bold"))
            else:
                btn.configure(fg_color=COLOR_CARD_SURFACE, text_color=COLOR_TEXT_SECONDARY, font=ctk.CTkFont(size=11, weight="normal"))
        self._populate_packs_content()

    def _populate_packs_content(self):
        for child in self.packs_grid_container.winfo_children():
            child.destroy()

        if self.search_scope == "All Icons":
            self._populate_all_icons_grid()
        else:
            self._populate_packs_cards_grid()

    def _populate_packs_cards_grid(self):
        """2-column Wide IconPackCard grid matching macOS IconPackCard in IconPacksView.swift"""
        filtered = []
        for p in self.packs:
            if self.active_category != "All" and p.get("category") != self.active_category:
                continue
            if self.search_query:
                matches_pack = self.search_query in p["name"].lower() or self.search_query in p.get("description", "").lower()
                matches_icon = any(self.search_query in i["name"].lower() for i in p["icons"])
                if not (matches_pack or matches_icon):
                    continue
            filtered.append(p)

        if not filtered:
            lbl = ctk.CTkLabel(
                self.packs_grid_container,
                text="No icon packs match your search criteria.",
                font=ctk.CTkFont(size=14),
                text_color=COLOR_TEXT_MUTED
            )
            lbl.pack(pady=40)
            return

        # 2-Column Wide Grid
        grid = ctk.CTkFrame(self.packs_grid_container, fg_color="transparent")
        grid.pack(fill="x")
        grid.columnconfigure((0, 1), weight=1, uniform="pack_wide_card")

        for idx, pack in enumerate(filtered):
            r = idx // 2
            c = idx % 2
            card = self._build_mac_icon_pack_card(grid, pack)
            card.grid(row=r, column=c, padx=8, pady=8, sticky="nsew")

    def _build_mac_icon_pack_card(self, parent, pack: Dict) -> ctk.CTkFrame:
        """
        Exact replica of IconPackCard in IconPacksView.swift:
        Top 120px banner with pack gradient/tint + 4 floating icon previews!
        Bottom info area with title, count badge, and description.
        """
        card = ctk.CTkFrame(
            parent,
            fg_color=COLOR_CARD_BG,
            corner_radius=16,
            border_width=1,
            border_color=COLOR_BORDER,
            height=210
        )
        card.pack_propagate(False)

        # 1. Top Preview Banner Area with pack accent color
        accent_hex = pack.get("accentColorHex", "#6366F1")
        banner = ctk.CTkFrame(
            card,
            fg_color=self._tint_hex(accent_hex, 0.35),
            corner_radius=12,
            height=120
        )
        banner.pack(fill="x", padx=10, pady=(10, 8))
        banner.pack_propagate(False)

        # 4 Preview Icons floating inside banner
        icons_row = ctk.CTkFrame(banner, fg_color="transparent")
        icons_row.place(relx=0.5, rely=0.5, anchor="center")

        sample_icons = pack["icons"][:4]
        for icon in sample_icons:
            thumb = self._get_image_thumbnail(icon["path"], size=52)
            if thumb:
                img_lbl = ctk.CTkLabel(icons_row, text="", image=thumb)
                img_lbl.pack(side="left", padx=8)

        # 2. Bottom Info Area
        info = ctk.CTkFrame(card, fg_color="transparent")
        info.pack(fill="both", expand=True, padx=14, pady=(0, 10))

        title_row = ctk.CTkFrame(info, fg_color="transparent")
        title_row.pack(fill="x")

        name_lbl = ctk.CTkLabel(
            title_row,
            text=f"{pack.get('emoji', '📁')}  {pack['name']}",
            font=ctk.CTkFont(family="Segoe UI", size=16, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        name_lbl.pack(side="left")

        # Icon Count Badge (Capsule)
        count_pill = ctk.CTkLabel(
            title_row,
            text=f"{pack['count']} icons",
            font=ctk.CTkFont(family="Segoe UI", size=11, weight="bold"),
            fg_color=COLOR_CARD_SURFACE,
            text_color=COLOR_TEXT_SECONDARY,
            corner_radius=10,
            height=22,
            padx=8
        )
        count_pill.pack(side="right")

        # Description
        desc_text = pack.get("description", "") or f"{pack.get('category', 'Anime')} custom folder collection"
        desc_lbl = ctk.CTkLabel(
            info,
            text=desc_text[:75] + ("..." if len(desc_text) > 75 else ""),
            font=ctk.CTkFont(family="Segoe UI", size=12),
            text_color=COLOR_TEXT_SECONDARY,
            anchor="w"
        )
        desc_lbl.pack(fill="x", pady=(4, 0))

        # Click handler to navigate into pack detail
        for w in [card, banner, icons_row, info, title_row, name_lbl, count_pill, desc_lbl]:
            w.bind("<Button-1>", lambda e, p=pack["id"]: self._navigate_to("packs", pack_id=p))

        return card

    def _populate_all_icons_grid(self):
        """Global Search Scope: 5-column grid across all icons"""
        matching = []
        for p in self.packs:
            for icon in p["icons"]:
                if not self.search_query or (self.search_query in icon["name"].lower() or self.search_query in p["name"].lower()):
                    matching.append((p, icon))

        if not matching:
            lbl = ctk.CTkLabel(self.packs_grid_container, text="No matching icons found.", font=ctk.CTkFont(size=14), text_color=COLOR_TEXT_MUTED)
            lbl.pack(pady=40)
            return

        grid = ctk.CTkFrame(self.packs_grid_container, fg_color="transparent")
        grid.pack(fill="x")
        cols = 5
        for c in range(cols):
            grid.columnconfigure(c, weight=1, uniform="all_icon")

        for idx, (pack, icon) in enumerate(matching[:60]):
            r = idx // cols
            c = idx % cols
            card = self._build_icon_card(grid, pack, icon)
            card.grid(row=r, column=c, padx=5, pady=5, sticky="nsew")

    # =========================================================================
    # PACK DETAIL DRILL-DOWN (IconPackDetailView in IconPacksView.swift)
    # =========================================================================

    def _render_pack_detail_view(self, pack_id: str):
        pack = next((p for p in self.packs if p["id"] == pack_id), None)
        if not pack:
            self._navigate_to("packs")
            return

        container = ctk.CTkScrollableFrame(self.content_container, fg_color="transparent")
        container.pack(fill="both", expand=True, padx=32, pady=24)

        # Header Row: Back Button + Title
        back_bar = ctk.CTkFrame(container, fg_color="transparent")
        back_bar.pack(fill="x", pady=(0, 14))

        back_btn = ctk.CTkButton(
            back_bar,
            text="\uE72B  Back",
            font=ctk.CTkFont(family=self.font_family, size=12, weight="bold"),
            fg_color="transparent",
            text_color=COLOR_ACCENT,
            hover_color=COLOR_CARD_BG,
            corner_radius=8,
            width=70,
            height=30,
            command=lambda: self._navigate_to("packs")
        )
        back_btn.pack(side="left")

        div_sep = ctk.CTkFrame(back_bar, width=1, height=20, fg_color=COLOR_BORDER)
        div_sep.pack(side="left", padx=10)

        title_lbl = ctk.CTkLabel(
            back_bar,
            text=f"{pack.get('emoji', '📁')}  {pack['name']}",
            font=ctk.CTkFont(family=self.font_display, size=22, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        title_lbl.pack(side="left")

        # Pack Info Card Banner
        accent_hex = pack.get("accentColorHex", "#6366F1")
        header_banner = ctk.CTkFrame(container, fg_color=COLOR_CARD_BG, corner_radius=14, border_width=1, border_color=COLOR_BORDER)
        header_banner.pack(fill="x", pady=(0, 18))

        hb_inner = ctk.CTkFrame(header_banner, fg_color="transparent")
        hb_inner.pack(fill="x", padx=20, pady=16)

        p_desc = pack.get("description", "") or "Vector icon pack for Windows folder customization."
        desc_l = ctk.CTkLabel(hb_inner, text=p_desc, font=ctk.CTkFont(size=13), text_color=COLOR_TEXT_SECONDARY, anchor="w")
        desc_l.pack(fill="x")

        badges_row = ctk.CTkFrame(hb_inner, fg_color="transparent")
        badges_row.pack(fill="x", pady=(8, 0))

        cat_badge = ctk.CTkLabel(badges_row, text=pack.get("category", "Anime"), font=ctk.CTkFont(size=11, weight="bold"), fg_color=COLOR_CARD_SURFACE, text_color=COLOR_CYAN, corner_radius=8, height=22, padx=8)
        cat_badge.pack(side="left", padx=(0, 8))

        count_badge = ctk.CTkLabel(badges_row, text=f"{pack['count']} vector icons", font=ctk.CTkFont(size=11, weight="bold"), fg_color=COLOR_CARD_SURFACE, text_color=COLOR_TEXT_PRIMARY, corner_radius=8, height=22, padx=8)
        count_badge.pack(side="left")

        # 5-Column Icons Grid
        icons_grid = ctk.CTkFrame(container, fg_color="transparent")
        icons_grid.pack(fill="x")
        cols = 5
        for c in range(cols):
            icons_grid.columnconfigure(c, weight=1, uniform="icon_detail_card")

        for idx, icon in enumerate(pack["icons"]):
            r = idx // cols
            c = idx % cols
            card = self._build_icon_card(icons_grid, pack, icon)
            card.grid(row=r, column=c, padx=5, pady=5, sticky="nsew")

    def _build_icon_card(self, parent, pack: Dict, icon: Dict) -> ctk.CTkFrame:
        """Card for individual icon in pack detail and favorites"""
        card = ctk.CTkFrame(
            parent,
            fg_color=COLOR_CARD_BG,
            corner_radius=12,
            border_width=1,
            border_color=COLOR_BORDER,
            height=130
        )
        card.pack_propagate(False)

        # Star toggle button
        is_fav = mcons_core.is_favorite(icon["path"])
        star_btn = ctk.CTkButton(
            card,
            text="\uE735" if is_fav else "\uE734",
            width=22,
            height=22,
            font=ctk.CTkFont(family=self.font_icon, size=11),
            fg_color="transparent",
            text_color=COLOR_WARNING if is_fav else COLOR_TEXT_MUTED,
            hover_color=COLOR_CARD_SURFACE,
            corner_radius=6,
            command=lambda i=icon["path"]: self._toggle_fav(i)
        )
        star_btn.place(relx=1.0, rely=0.0, anchor="ne", x=-6, y=6)

        # Thumbnail Image
        thumb = self._get_image_thumbnail(icon["path"], size=48)
        if thumb:
            img_lbl = ctk.CTkLabel(card, text="", image=thumb)
            img_lbl.pack(pady=(18, 6))
        else:
            img_lbl = ctk.CTkLabel(card, text="\uED25", font=ctk.CTkFont(family=self.font_icon, size=28), text_color=COLOR_TEXT_SECONDARY)
            img_lbl.pack(pady=(18, 6))

        # Icon Name
        name_lbl = ctk.CTkLabel(
            card,
            text=icon["name"][:16],
            font=ctk.CTkFont(family="Segoe UI", size=11, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        name_lbl.pack(padx=4)

        # Click handler -> select & switch to Apply view
        for w in [card, img_lbl, name_lbl]:
            w.bind("<Button-1>", lambda e, p=icon["path"], n=icon["name"], pk=pack["name"]: self._select_and_apply(p, n, pk))

        return card

    def _toggle_fav(self, icon_path: str):
        mcons_core.toggle_favorite(icon_path)
        if self.current_nav == "packs" and self.pack_detail_id:
            self._render_pack_detail_view(self.pack_detail_id)
        elif self.current_nav == "favorites":
            self._render_favorites_view()
        self._update_sidebar_active_state(self.current_nav)

    def _select_and_apply(self, icon_path: str, icon_name: str, pack_name: str):
        self.selected_icon_path = icon_path
        self.selected_icon_name = icon_name
        self.selected_icon_pack = pack_name
        self._navigate_to("apply")

    # =========================================================================
    # VIEW 3: FAVORITES VIEW (Mirrors FavoritesView.swift)
    # =========================================================================

    def _render_favorites_view(self):
        container = ctk.CTkScrollableFrame(self.content_container, fg_color="transparent")
        container.pack(fill="both", expand=True, padx=32, pady=24)

        # Header
        head = ctk.CTkFrame(container, fg_color="transparent")
        head.pack(fill="x", pady=(0, 18))

        title = ctk.CTkLabel(head, text="Favorites", font=ctk.CTkFont(family="Segoe UI", size=28, weight="bold"), text_color=COLOR_TEXT_PRIMARY)
        title.pack(anchor="w")

        sub = ctk.CTkLabel(head, text="Quick access to your starred vector icons", font=ctk.CTkFont(size=13), text_color=COLOR_TEXT_SECONDARY)
        sub.pack(anchor="w")

        fav_paths = mcons_core.get_favorites()
        if not fav_paths:
            empty = ctk.CTkFrame(container, fg_color=COLOR_CARD_BG, corner_radius=16, border_width=1, border_color=COLOR_BORDER)
            empty.pack(fill="both", expand=True, pady=30)

            inner = ctk.CTkFrame(empty, fg_color="transparent")
            inner.place(relx=0.5, rely=0.5, anchor="center")

            star_icon = ctk.CTkLabel(inner, text="⭐", font=ctk.CTkFont(size=48))
            star_icon.pack(pady=(0, 10))

            empty_title = ctk.CTkLabel(inner, text="No Favorites Yet", font=ctk.CTkFont(family="Segoe UI", size=18, weight="bold"), text_color=COLOR_TEXT_PRIMARY)
            empty_title.pack()

            empty_sub = ctk.CTkLabel(inner, text="Star your favorite icons in any Icon Pack to access them here instantly.", font=ctk.CTkFont(size=12), text_color=COLOR_TEXT_SECONDARY)
            empty_sub.pack(pady=(4, 16))

            browse_btn = ctk.CTkButton(
                inner,
                text="Browse Icon Packs →",
                font=ctk.CTkFont(size=12, weight="bold"),
                fg_color=COLOR_ACCENT,
                hover_color=COLOR_ACCENT_HOVER,
                corner_radius=10,
                height=34,
                command=lambda: self._navigate_to("packs")
            )
            browse_btn.pack()
            return

        grid = ctk.CTkFrame(container, fg_color="transparent")
        grid.pack(fill="x")
        cols = 5
        for c in range(cols):
            grid.columnconfigure(c, weight=1, uniform="fav_col")

        for idx, f_path in enumerate(fav_paths):
            r = idx // cols
            c = idx % cols
            icon_name = os.path.splitext(os.path.basename(f_path))[0]
            mock_pack = {"id": "favorites", "name": "Favorites"}
            mock_icon = {"path": f_path, "name": icon_name}
            card = self._build_icon_card(grid, mock_pack, mock_icon)
            card.grid(row=r, column=c, padx=5, pady=5, sticky="nsew")

    # =========================================================================
    # VIEW 4: APPLY ICON VIEW (2-Column Exact Replica of IconApplyView.swift)
    # =========================================================================

    def _render_apply_view(self):
        container = ctk.CTkScrollableFrame(self.content_container, fg_color="transparent")
        container.pack(fill="both", expand=True, padx=32, pady=24)

        # Header Row
        head = ctk.CTkFrame(container, fg_color="transparent")
        head.pack(fill="x", pady=(0, 20))

        title = ctk.CTkLabel(
            head,
            text="Apply Icon",
            font=ctk.CTkFont(family="Segoe UI", size=28, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        title.pack(anchor="w")

        sub = ctk.CTkLabel(
            head,
            text="Select an icon and a target folder, option to rename, then apply",
            font=ctk.CTkFont(family="Segoe UI", size=13),
            text_color=COLOR_TEXT_SECONDARY
        )
        sub.pack(anchor="w")

        # Two-Column Layout (Matching Mac IconApplyView)
        layout_row = ctk.CTkFrame(container, fg_color="transparent")
        layout_row.pack(fill="x", pady=(0, 24))
        layout_row.columnconfigure(0, weight=4, uniform="apply_col")  # Left: Icon Selection (300px)
        layout_row.columnconfigure(1, weight=6, uniform="apply_col")  # Right: Folder & Preview

        # =====================================================================
        # LEFT PANEL: Selected Icon Panel (iconSelectionPanel in Swift)
        # =====================================================================
        icon_panel = ctk.CTkFrame(layout_row, fg_color="transparent")
        icon_panel.grid(row=0, column=0, padx=(0, 12), sticky="nsew")

        ip_title = ctk.CTkLabel(
            icon_panel,
            text="Selected Icon",
            font=ctk.CTkFont(family="Segoe UI", size=16, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        ip_title.pack(anchor="w", pady=(0, 8))

        icon_card = ctk.CTkFrame(icon_panel, fg_color=COLOR_CARD_BG, corner_radius=14, border_width=1, border_color=COLOR_BORDER)
        icon_card.pack(fill="both", expand=True)

        ic_inner = ctk.CTkFrame(icon_card, fg_color="transparent")
        ic_inner.pack(fill="both", expand=True, padx=20, pady=20)

        # Large Hero Icon Preview Box
        if self.selected_icon_path:
            hero_thumb = self._get_image_thumbnail(self.selected_icon_path, size=88)
            self.apply_hero_lbl = ctk.CTkLabel(ic_inner, text="", image=hero_thumb)
            self.apply_hero_lbl.pack(pady=(10, 12))

            self.apply_hero_name = ctk.CTkLabel(
                ic_inner,
                text=self.selected_icon_name or "Icon",
                font=ctk.CTkFont(family="Segoe UI", size=16, weight="bold"),
                text_color=COLOR_TEXT_PRIMARY
            )
            self.apply_hero_name.pack()

            pack_display = self.selected_icon_pack or "Icon Pack"
            self.apply_hero_pack = ctk.CTkLabel(
                ic_inner,
                text=f"From: {pack_display}",
                font=ctk.CTkFont(size=12),
                text_color=COLOR_TEXT_SECONDARY
            )
            self.apply_hero_pack.pack(pady=(2, 16))
        else:
            self.apply_hero_lbl = ctk.CTkLabel(ic_inner, text="🖼️", font=ctk.CTkFont(size=48), text_color=COLOR_TEXT_MUTED)
            self.apply_hero_lbl.pack(pady=(16, 12))

            self.apply_hero_name = ctk.CTkLabel(
                ic_inner,
                text="No icon selected",
                font=ctk.CTkFont(family="Segoe UI", size=15, weight="bold"),
                text_color=COLOR_TEXT_SECONDARY
            )
            self.apply_hero_name.pack()

            self.apply_hero_pack = ctk.CTkLabel(
                ic_inner,
                text="Choose from Icon Packs or import your own",
                font=ctk.CTkFont(size=11),
                text_color=COLOR_TEXT_MUTED
            )
            self.apply_hero_pack.pack(pady=(2, 16))

        # Thin divider
        div = ctk.CTkFrame(ic_inner, height=1, fg_color=COLOR_BORDER)
        div.pack(fill="x", pady=(0, 14))

        # Browse Icon Packs Action Button
        browse_packs_b = ctk.CTkButton(
            ic_inner,
            text="📦  Browse Icon Packs",
            font=ctk.CTkFont(family="Segoe UI", size=12, weight="bold"),
            fg_color=COLOR_CARD_SURFACE,
            hover_color=COLOR_BORDER,
            corner_radius=8,
            height=34,
            command=lambda: self._navigate_to("packs")
        )
        browse_packs_b.pack(fill="x", pady=(0, 8))

        # Import Custom Image Action Button
        import_custom_b = ctk.CTkButton(
            ic_inner,
            text="🖼️  Import Custom Image...",
            font=ctk.CTkFont(family="Segoe UI", size=12),
            fg_color=COLOR_CARD_SURFACE,
            hover_color=COLOR_BORDER,
            corner_radius=8,
            height=34,
            command=self._on_browse_custom_image
        )
        import_custom_b.pack(fill="x")

        # =====================================================================
        # RIGHT PANEL: Target Folder + Preview & Apply Panels
        # =====================================================================
        right_panel = ctk.CTkFrame(layout_row, fg_color="transparent")
        right_panel.grid(row=0, column=1, padx=(12, 0), sticky="nsew")

        # 1. Target Folder Panel (folderSelectionPanel in Swift)
        folder_head = ctk.CTkFrame(right_panel, fg_color="transparent")
        folder_head.pack(fill="x", pady=(0, 8))

        fh_title = ctk.CTkLabel(
            folder_head,
            text="Target Folder",
            font=ctk.CTkFont(family="Segoe UI", size=16, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        fh_title.pack(side="left")

        if self.selected_folder:
            f_pill = ctk.CTkLabel(
                folder_head,
                text="FOLDER",
                font=ctk.CTkFont(size=9, weight="bold"),
                fg_color=COLOR_CARD_SURFACE,
                text_color=COLOR_ACCENT,
                corner_radius=6,
                height=18,
                padx=6
            )
            f_pill.pack(side="right")

        folder_card = ctk.CTkFrame(right_panel, fg_color=COLOR_CARD_BG, corner_radius=14, border_width=1, border_color=COLOR_BORDER)
        folder_card.pack(fill="x", pady=(0, 16))

        fc_inner = ctk.CTkFrame(folder_card, fg_color="transparent")
        fc_inner.pack(fill="x", padx=18, pady=16)

        if self.selected_folder:
            # Active selected folder row
            f_row = ctk.CTkFrame(fc_inner, fg_color="transparent")
            f_row.pack(fill="x", pady=(0, 10))

            f_icon_lbl = ctk.CTkLabel(f_row, text="📁", font=ctk.CTkFont(size=32))
            f_icon_lbl.pack(side="left", padx=(0, 12))

            f_details = ctk.CTkFrame(f_row, fg_color="transparent")
            f_details.pack(side="left", fill="x", expand=True)

            f_name_l = ctk.CTkLabel(
                f_details,
                text=os.path.basename(self.selected_folder),
                font=ctk.CTkFont(family="Segoe UI", size=15, weight="bold"),
                text_color=COLOR_TEXT_PRIMARY
            )
            f_name_l.pack(anchor="w")

            f_path_l = ctk.CTkLabel(
                f_details,
                text=self.selected_folder,
                font=ctk.CTkFont(size=11),
                text_color=COLOR_TEXT_SECONDARY
            )
            f_path_l.pack(anchor="w")

            clear_b = ctk.CTkButton(
                f_row,
                text="✕",
                width=24,
                height=24,
                fg_color="transparent",
                text_color=COLOR_TEXT_MUTED,
                hover_color=COLOR_CARD_SURFACE,
                command=self._on_clear_selected_folder
            )
            clear_b.pack(side="right")

            # Rename folder option (Mirrors Mac app customFolderName field)
            r_row = ctk.CTkFrame(fc_inner, fg_color="transparent")
            r_row.pack(fill="x", pady=(4, 0))

            r_header = ctk.CTkFrame(r_row, fg_color="transparent")
            r_header.pack(fill="x", pady=(0, 4))

            r_title = ctk.CTkLabel(r_header, text="Folder Name", font=ctk.CTkFont(size=11, weight="bold"), text_color=COLOR_TEXT_SECONDARY)
            r_title.pack(side="left")

            if self.selected_icon_name:
                use_icon_name_btn = ctk.CTkButton(
                    r_header,
                    text="Use Icon Name",
                    font=ctk.CTkFont(size=11, weight="bold"),
                    fg_color="transparent",
                    text_color=COLOR_SUCCESS,
                    hover_color=COLOR_CARD_SURFACE,
                    height=20,
                    command=lambda: self._set_folder_name(self.selected_icon_name)
                )
                use_icon_name_btn.pack(side="right")

            self.rename_entry = ctk.CTkEntry(
                r_row,
                height=32,
                fg_color=COLOR_CARD_SURFACE,
                border_color=COLOR_BORDER,
                font=ctk.CTkFont(family="Segoe UI", size=12)
            )
            self.rename_entry.insert(0, self.custom_folder_name or os.path.basename(self.selected_folder))
            self.rename_entry.pack(fill="x")
        else:
            # Drop zone / Selection box
            drop_box = ctk.CTkFrame(fc_inner, fg_color=COLOR_CARD_SURFACE, corner_radius=10, height=80)
            drop_box.pack(fill="x", pady=(0, 10))
            drop_box.pack_propagate(False)

            db_inner = ctk.CTkFrame(drop_box, fg_color="transparent")
            db_inner.place(relx=0.5, rely=0.5, anchor="center")

            db_icon = ctk.CTkLabel(db_inner, text="📁", font=ctk.CTkFont(size=24))
            db_icon.pack()

            db_text = ctk.CTkLabel(db_inner, text="Select a folder or paste path (Ctrl+V)", font=ctk.CTkFont(size=12), text_color=COLOR_TEXT_SECONDARY)
            db_text.pack()

            for w in [drop_box, db_inner, db_icon, db_text]:
                w.bind("<Button-1>", lambda e: self._on_choose_target_folder())

        # Folder action buttons
        btn_row = ctk.CTkFrame(fc_inner, fg_color="transparent")
        btn_row.pack(fill="x", pady=(8, 0))

        choose_f_btn = ctk.CTkButton(
            btn_row,
            text="Choose Folder...",
            font=ctk.CTkFont(family="Segoe UI", size=12, weight="bold"),
            fg_color=COLOR_CARD_SURFACE,
            hover_color=COLOR_BORDER,
            corner_radius=8,
            height=32,
            command=self._on_choose_target_folder
        )
        choose_f_btn.pack(side="left", fill="x", expand=True, padx=(0, 6))

        create_f_btn = ctk.CTkButton(
            btn_row,
            text="+ Create New Folder...",
            font=ctk.CTkFont(family="Segoe UI", size=12),
            fg_color=COLOR_CARD_SURFACE,
            hover_color=COLOR_BORDER,
            corner_radius=8,
            height=32,
            command=self._on_create_new_folder
        )
        create_f_btn.pack(side="right", fill="x", expand=True, padx=(6, 0))

        # 2. Preview & Apply Panel (previewPanel in Swift)
        prev_head = ctk.CTkLabel(
            right_panel,
            text="Preview & Apply",
            font=ctk.CTkFont(family="Segoe UI", size=16, weight="bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        prev_head.pack(anchor="w", pady=(0, 8))

        prev_card = ctk.CTkFrame(right_panel, fg_color=COLOR_CARD_BG, corner_radius=14, border_width=1, border_color=COLOR_BORDER)
        prev_card.pack(fill="x")

        pc_inner = ctk.CTkFrame(prev_card, fg_color="transparent")
        pc_inner.pack(fill="x", padx=20, pady=18)

        # Before / After Comparison Area (Exact match to Mac HStack)
        compare_row = ctk.CTkFrame(pc_inner, fg_color="transparent")
        compare_row.pack(fill="x", pady=(0, 16))
        compare_row.columnconfigure((0, 2), weight=1)

        # BEFORE
        before_col = ctk.CTkFrame(compare_row, fg_color="transparent")
        before_col.grid(row=0, column=0)

        b_caption = ctk.CTkLabel(before_col, text="BEFORE", font=ctk.CTkFont(size=10, weight="bold"), text_color=COLOR_TEXT_MUTED)
        b_caption.pack(pady=(0, 4))

        b_icon = ctk.CTkLabel(before_col, text="📁", font=ctk.CTkFont(size=44))
        b_icon.pack()

        b_name = ctk.CTkLabel(
            before_col,
            text=os.path.basename(self.selected_folder) if self.selected_folder else "No folder",
            font=ctk.CTkFont(size=11),
            text_color=COLOR_TEXT_SECONDARY
        )
        b_name.pack(pady=(4, 0))

        # ARROW
        arrow_lbl = ctk.CTkLabel(
            compare_row,
            text="➔",
            font=ctk.CTkFont(size=24, weight="bold"),
            text_color=COLOR_ACCENT
        )
        arrow_lbl.grid(row=0, column=1, padx=16)

        # AFTER
        after_col = ctk.CTkFrame(compare_row, fg_color="transparent")
        after_col.grid(row=0, column=2)

        a_caption = ctk.CTkLabel(after_col, text="AFTER", font=ctk.CTkFont(size=10, weight="bold"), text_color=COLOR_TEXT_MUTED)
        a_caption.pack(pady=(0, 4))

        if self.selected_icon_path:
            after_thumb = self._get_image_thumbnail(self.selected_icon_path, size=52)
            if after_thumb:
                a_icon = ctk.CTkLabel(after_col, text="", image=after_thumb)
                a_icon.pack()
            else:
                a_icon = ctk.CTkLabel(after_col, text="📁", font=ctk.CTkFont(size=44))
                a_icon.pack()
        else:
            a_icon = ctk.CTkLabel(after_col, text="❔", font=ctk.CTkFont(size=44), text_color=COLOR_TEXT_MUTED)
            a_icon.pack()

        a_name = ctk.CTkLabel(
            after_col,
            text=self.selected_icon_name if self.selected_icon_name else "No icon",
            font=ctk.CTkFont(size=11),
            text_color=COLOR_TEXT_SECONDARY
        )
        a_name.pack(pady=(4, 0))

        # Action Buttons Row
        action_btn_row = ctk.CTkFrame(pc_inner, fg_color="transparent")
        action_btn_row.pack(fill="x", pady=(10, 0))

        # Reset button
        reset_b = ctk.CTkButton(
            action_btn_row,
            text="\uE777  Reset Default",
            font=ctk.CTkFont(family=self.font_family, size=12),
            fg_color=COLOR_CARD_SURFACE,
            hover_color=COLOR_BORDER,
            corner_radius=8,
            height=36,
            command=self._on_execute_restore
        )
        reset_b.pack(side="left")

        # Primary Apply Button
        apply_b = ctk.CTkButton(
            action_btn_row,
            text="\uE790  Apply Icon",
            font=ctk.CTkFont(family=self.font_family, size=13, weight="bold"),
            fg_color=COLOR_ACCENT,
            hover_color=COLOR_ACCENT_HOVER,
            corner_radius=8,
            height=36,
            command=self._on_execute_apply
        )
        apply_b.pack(side="right", padx=(10, 0), fill="x", expand=True)

        # Status alert banner below
        self.apply_status_lbl = ctk.CTkLabel(
            container,
            text="",
            font=ctk.CTkFont(family=self.font_family, size=12, weight="bold"),
            text_color=COLOR_SUCCESS
        )
        self.apply_status_lbl.pack(fill="x", pady=(16, 0))

    def _set_folder_name(self, name: str):
        self.custom_folder_name = name
        if hasattr(self, "rename_entry"):
            self.rename_entry.delete(0, "end")
            self.rename_entry.insert(0, name)

    def _on_clear_selected_folder(self):
        self.selected_folder = None
        self.custom_folder_name = ""
        self._render_apply_view()

    def _on_choose_target_folder(self):
        folder = filedialog.askdirectory(title="Select Folder to Customize")
        if folder:
            self.selected_folder = os.path.abspath(folder)
            self.custom_folder_name = os.path.basename(self.selected_folder)
            self._render_apply_view()

    def _on_create_new_folder(self):
        parent = filedialog.askdirectory(title="Select Location for New Folder")
        if parent:
            new_path = os.path.join(parent, "New Folder")
            count = 1
            while os.path.exists(new_path):
                new_path = os.path.join(parent, f"New Folder ({count})")
                count += 1
            os.makedirs(new_path, exist_ok=True)
            self.selected_folder = new_path
            self.custom_folder_name = os.path.basename(new_path)
            self._render_apply_view()

    def _on_browse_custom_image(self):
        f = filedialog.askopenfilename(
            title="Select Custom Icon File",
            filetypes=[("Vector & Image files", "*.svg *.png *.ico *.jpg"), ("All files", "*.*")]
        )
        if f:
            self.selected_icon_path = os.path.abspath(f)
            self.selected_icon_name = os.path.splitext(os.path.basename(f))[0]
            self.selected_icon_pack = "Custom Import"
            self._render_apply_view()

    def _on_execute_apply(self):
        if not self.selected_folder or not os.path.isdir(self.selected_folder):
            self.apply_status_lbl.configure(text="Please choose a target folder.", text_color=COLOR_ERROR)
            return
        if not self.selected_icon_path:
            self.apply_status_lbl.configure(text="Please select an icon first.", text_color=COLOR_ERROR)
            return

        # Check if folder should be renamed
        target_path = self.selected_folder
        if hasattr(self, "rename_entry"):
            new_name = self.rename_entry.get().strip()
            if new_name and new_name != os.path.basename(self.selected_folder):
                parent_dir = os.path.dirname(self.selected_folder)
                renamed_path = os.path.join(parent_dir, new_name)
                try:
                    os.rename(self.selected_folder, renamed_path)
                    target_path = renamed_path
                    self.selected_folder = renamed_path
                    self.custom_folder_name = new_name
                except Exception as e:
                    self.apply_status_lbl.configure(text=f"Rename warning: {e}", text_color=COLOR_WARNING)

        ok, msg = mcons_core.apply_folder_icon(target_path, self.selected_icon_path)
        if ok:
            self.apply_status_lbl.configure(text=f"✓ Successfully applied icon to '{os.path.basename(target_path)}'", text_color=COLOR_SUCCESS)
            if hasattr(self, "open_explorer_btn") and self.open_explorer_btn.winfo_exists():
                self.open_explorer_btn.destroy()
            self.open_explorer_btn = ctk.CTkButton(
                self.apply_status_lbl.master,
                text="📁 Open in File Explorer",
                font=ctk.CTkFont(family=self.font_family, size=11, weight="bold"),
                fg_color=COLOR_CARD_SURFACE,
                hover_color=COLOR_BORDER,
                height=30,
                width=180,
                command=lambda p=target_path: subprocess.Popen(f'explorer.exe /select,"{p}"')
            )
            self.open_explorer_btn.pack(pady=(8, 0))
        else:
            self.apply_status_lbl.configure(text=f"✗ {msg}", text_color=COLOR_ERROR)

    def _on_execute_restore(self):
        if not self.selected_folder or not os.path.isdir(self.selected_folder):
            self.apply_status_lbl.configure(text="Please choose a target folder.", text_color=COLOR_ERROR)
            return

        ok, msg = mcons_core.restore_folder_icon(self.selected_folder)
        if ok:
            self.apply_status_lbl.configure(text=f"✓ Restored default icon for '{os.path.basename(self.selected_folder)}'", text_color=COLOR_SUCCESS)
            if hasattr(self, "open_explorer_btn") and self.open_explorer_btn.winfo_exists():
                self.open_explorer_btn.destroy()
            self.open_explorer_btn = ctk.CTkButton(
                self.apply_status_lbl.master,
                text="📁 Open in File Explorer",
                font=ctk.CTkFont(family=self.font_family, size=11, weight="bold"),
                fg_color=COLOR_CARD_SURFACE,
                hover_color=COLOR_BORDER,
                height=30,
                width=180,
                command=lambda p=self.selected_folder: subprocess.Popen(f'explorer.exe /select,"{p}"')
            )
            self.open_explorer_btn.pack(pady=(8, 0))
        else:
            self.apply_status_lbl.configure(text=f"✗ {msg}", text_color=COLOR_ERROR)

    # =========================================================================
    # VIEW 5: BATCH APPLY VIEW (Mirrors BatchApplyView.swift)
    # =========================================================================

    def _render_batch_view(self):
        container = ctk.CTkScrollableFrame(self.content_container, fg_color="transparent")
        container.pack(fill="both", expand=True, padx=32, pady=24)

        head = ctk.CTkFrame(container, fg_color="transparent")
        head.pack(fill="x", pady=(0, 20))

        title = ctk.CTkLabel(head, text="Batch Apply", font=ctk.CTkFont(family="Segoe UI", size=28, weight="bold"), text_color=COLOR_TEXT_PRIMARY)
        title.pack(anchor="w")

        sub = ctk.CTkLabel(head, text="Apply an icon pack across multiple folders simultaneously", font=ctk.CTkFont(size=13), text_color=COLOR_TEXT_SECONDARY)
        sub.pack(anchor="w")

        card1 = ctk.CTkFrame(container, fg_color=COLOR_CARD_BG, corner_radius=14, border_width=1, border_color=COLOR_BORDER)
        card1.pack(fill="x", pady=(0, 16))

        c1_inner = ctk.CTkFrame(card1, fg_color="transparent")
        c1_inner.pack(fill="x", padx=20, pady=18)

        lbl1 = ctk.CTkLabel(c1_inner, text="1. Select Parent Directory", font=ctk.CTkFont(family="Segoe UI", size=14, weight="bold"), text_color=COLOR_TEXT_PRIMARY)
        lbl1.pack(anchor="w", pady=(0, 8))

        row1 = ctk.CTkFrame(c1_inner, fg_color="transparent")
        row1.pack(fill="x")

        self.batch_parent_entry = ctk.CTkEntry(row1, placeholder_text="Select directory containing subfolders...", height=36, corner_radius=8, fg_color=COLOR_CARD_SURFACE, border_color=COLOR_BORDER)
        self.batch_parent_entry.pack(side="left", fill="x", expand=True, padx=(0, 8))

        b_browse = ctk.CTkButton(row1, text="Browse...", font=ctk.CTkFont(size=12, weight="bold"), fg_color=COLOR_CARD_SURFACE, hover_color=COLOR_BORDER, corner_radius=8, width=80, height=36, command=self._on_browse_batch_dir)
        b_browse.pack(side="right")

        # Choose pack
        lbl2 = ctk.CTkLabel(c1_inner, text="2. Choose Icon Pack", font=ctk.CTkFont(family="Segoe UI", size=14, weight="bold"), text_color=COLOR_TEXT_PRIMARY)
        lbl2.pack(anchor="w", pady=(14, 8))

        pack_names = [f"{p['emoji']} {p['name']} ({p['count']} icons)" for p in self.packs]
        self.batch_pack_menu = ctk.CTkOptionMenu(
            c1_inner,
            values=pack_names,
            height=36,
            corner_radius=8,
            fg_color=COLOR_CARD_SURFACE,
            button_color=COLOR_BORDER,
            button_hover_color=COLOR_ACCENT
        )
        self.batch_pack_menu.pack(fill="x", pady=(0, 14))

        # Execute Button & Log
        self.batch_run_btn = ctk.CTkButton(
            c1_inner,
            text="⚡ Apply Icons to All Subfolders",
            font=ctk.CTkFont(family="Segoe UI", size=13, weight="bold"),
            fg_color=COLOR_ACCENT,
            hover_color=COLOR_ACCENT_HOVER,
            corner_radius=8,
            height=38,
            command=self._on_execute_batch_run
        )
        self.batch_run_btn.pack(fill="x", pady=(0, 10))

        self.batch_log_box = ctk.CTkTextbox(c1_inner, height=140, fg_color=COLOR_SIDEBAR_BG, text_color=COLOR_TEXT_SECONDARY, font=ctk.CTkFont(family="Consolas", size=11))
        self.batch_log_box.pack(fill="x")
        self.batch_log_box.insert("end", "Select a parent directory to preview subfolders.\n")

    def _on_browse_batch_dir(self):
        folder = filedialog.askdirectory(title="Select Parent Directory")
        if folder:
            self.batch_parent_entry.delete(0, "end")
            self.batch_parent_entry.insert(0, os.path.abspath(folder))

            subdirs = [os.path.join(folder, d) for d in os.listdir(folder) if os.path.isdir(os.path.join(folder, d))]
            self.batch_log_box.delete("1.0", "end")
            self.batch_log_box.insert("end", f"Discovered {len(subdirs)} subfolders in:\n{folder}\n\n")
            for sd in subdirs[:10]:
                self.batch_log_box.insert("end", f"  • {os.path.basename(sd)}\n")
            if len(subdirs) > 10:
                self.batch_log_box.insert("end", f"  ... and {len(subdirs) - 10} more.\n")

    def _on_execute_batch_run(self):
        parent_dir = self.batch_parent_entry.get().strip()
        if not parent_dir or not os.path.isdir(parent_dir):
            self.batch_log_box.insert("end", "\n[ERROR] Invalid parent directory.\n")
            return

        choice = self.batch_pack_menu.get()
        matched = next((p for p in self.packs if p["name"] in choice), self.packs[0])
        icons = matched["icons"]

        subdirs = [os.path.join(parent_dir, d) for d in os.listdir(parent_dir) if os.path.isdir(os.path.join(parent_dir, d))]
        if not subdirs:
            self.batch_log_box.insert("end", "\n[WARNING] No subdirectories found.\n")
            return

        self.batch_log_box.insert("end", f"\nApplying pack '{matched['name']}' to {len(subdirs)} folders...\n")
        ok_count = 0
        for idx, sd in enumerate(subdirs):
            icon_obj = icons[idx % len(icons)]
            ok, msg = mcons_core.apply_folder_icon(sd, icon_obj["path"])
            tag = "✓ OK" if ok else "✗ FAIL"
            self.batch_log_box.insert("end", f"[{tag}] {os.path.basename(sd)} -> {icon_obj['name']}\n")
            if ok:
                ok_count += 1

        self.batch_log_box.insert("end", f"\nDone! {ok_count}/{len(subdirs)} folders customized.\n")

    # =========================================================================
    # VIEW 6: PACK BUILDER (Mirrors PackBuilderView.swift)
    # =========================================================================

    def _render_builder_view(self):
        container = ctk.CTkScrollableFrame(self.content_container, fg_color="transparent")
        container.pack(fill="both", expand=True, padx=32, pady=24)

        head = ctk.CTkFrame(container, fg_color="transparent")
        head.pack(fill="x", pady=(0, 20))

        title = ctk.CTkLabel(head, text="Pack Builder", font=ctk.CTkFont(family="Segoe UI", size=28, weight="bold"), text_color=COLOR_TEXT_PRIMARY)
        title.pack(anchor="w")

        sub = ctk.CTkLabel(head, text="Create and export custom vector icon packs", font=ctk.CTkFont(size=13), text_color=COLOR_TEXT_SECONDARY)
        sub.pack(anchor="w")

        card = ctk.CTkFrame(container, fg_color=COLOR_CARD_BG, corner_radius=14, border_width=1, border_color=COLOR_BORDER)
        card.pack(fill="x")

        c_inner = ctk.CTkFrame(card, fg_color="transparent")
        c_inner.pack(fill="x", padx=20, pady=20)

        lbl1 = ctk.CTkLabel(c_inner, text="Pack Name", font=ctk.CTkFont(size=13, weight="bold"), text_color=COLOR_TEXT_PRIMARY)
        lbl1.pack(anchor="w")

        self.builder_name = ctk.CTkEntry(c_inner, placeholder_text="e.g. Studio Neon", height=34, corner_radius=8, fg_color=COLOR_CARD_SURFACE, border_color=COLOR_BORDER)
        self.builder_name.pack(fill="x", pady=(4, 12))

        lbl2 = ctk.CTkLabel(c_inner, text="Category", font=ctk.CTkFont(size=13, weight="bold"), text_color=COLOR_TEXT_PRIMARY)
        lbl2.pack(anchor="w")

        self.builder_cat = ctk.CTkOptionMenu(
            c_inner,
            values=["Anime", "Tech & Dev", "Hardware", "System & Minimal", "Gaming & Anime", "Custom"],
            fg_color=COLOR_CARD_SURFACE,
            button_color=COLOR_BORDER,
            height=34,
            corner_radius=8
        )
        self.builder_cat.pack(fill="x", pady=(4, 16))

        import_b = ctk.CTkButton(
            c_inner,
            text="📁 Select SVG or PNG Icons...",
            font=ctk.CTkFont(family="Segoe UI", size=12, weight="bold"),
            fg_color=COLOR_CARD_SURFACE,
            hover_color=COLOR_BORDER,
            corner_radius=8,
            height=36,
            command=self._on_builder_import
        )
        import_b.pack(fill="x", pady=(0, 8))

        self.builder_files: List[str] = []
        self.builder_status = ctk.CTkLabel(c_inner, text="No files selected.", font=ctk.CTkFont(size=11), text_color=COLOR_TEXT_MUTED)
        self.builder_status.pack(anchor="w", pady=(0, 16))

        save_b = ctk.CTkButton(
            c_inner,
            text="✨ Save Custom Pack",
            font=ctk.CTkFont(family="Segoe UI", size=13, weight="bold"),
            fg_color=COLOR_ACCENT,
            hover_color=COLOR_ACCENT_HOVER,
            corner_radius=8,
            height=38,
            command=self._on_builder_save
        )
        save_b.pack(fill="x")

    def _on_builder_import(self):
        files = filedialog.askopenfilenames(
            title="Select SVG / PNG Icons",
            filetypes=[("SVG / PNG files", "*.svg *.png"), ("All files", "*.*")]
        )
        if files:
            self.builder_files = list(files)
            self.builder_status.configure(text=f"Selected {len(files)} icon files.", text_color=COLOR_CYAN)

    def _on_builder_save(self):
        name = self.builder_name.get().strip()
        if not name:
            messagebox.showwarning("MCons", "Please enter a Pack Name.")
            return
        if not self.builder_files:
            messagebox.showwarning("MCons", "Please select at least one icon file.")
            return

        packs_dir = mcons_core.get_packs_dir()
        slug = name.lower().replace(" ", "-")
        target = os.path.join(packs_dir, slug)
        os.makedirs(target, exist_ok=True)

        for f in self.builder_files:
            shutil.copy2(f, target)

        import json
        meta = {
            "name": name,
            "category": self.builder_cat.get(),
            "emoji": "🎨",
            "accentColorHex": "#6366F1",
            "description": f"Custom pack with {len(self.builder_files)} icons."
        }
        with open(os.path.join(target, "metadata.json"), "w", encoding="utf-8") as mf:
            json.dump(meta, mf, indent=2)

        self.packs = mcons_core.load_all_packs()
        messagebox.showinfo("MCons", f"Created pack '{name}' with {len(self.builder_files)} icons!")
        self._navigate_to("packs", pack_id=slug)

    # =========================================================================
    # VIEW 7: SETTINGS VIEW (Mirrors SettingsView.swift)
    # =========================================================================

    def _render_settings_view(self):
        container = ctk.CTkScrollableFrame(self.content_container, fg_color="transparent")
        container.pack(fill="both", expand=True, padx=32, pady=24)

        head = ctk.CTkFrame(container, fg_color="transparent")
        head.pack(fill="x", pady=(0, 20))

        title = ctk.CTkLabel(head, text="Settings", font=ctk.CTkFont(family="Segoe UI", size=28, weight="bold"), text_color=COLOR_TEXT_PRIMARY)
        title.pack(anchor="w")

        sub = ctk.CTkLabel(head, text="Configure MCons on Windows", font=ctk.CTkFont(size=13), text_color=COLOR_TEXT_SECONDARY)
        sub.pack(anchor="w")

        # Windows Shell Integration Card
        s_card = ctk.CTkFrame(container, fg_color=COLOR_CARD_BG, corner_radius=14, border_width=1, border_color=COLOR_BORDER)
        s_card.pack(fill="x", pady=(0, 16))

        sc_inner = ctk.CTkFrame(s_card, fg_color="transparent")
        sc_inner.pack(fill="x", padx=20, pady=18)

        st = ctk.CTkLabel(sc_inner, text="Windows Explorer Shell Integration", font=ctk.CTkFont(size=14, weight="bold"), text_color=COLOR_TEXT_PRIMARY)
        st.pack(anchor="w")

        sd = ctk.CTkLabel(sc_inner, text="Adds 'Customize with MCons' to the Windows folder right-click menu.", font=ctk.CTkFont(size=12), text_color=COLOR_TEXT_SECONDARY)
        sd.pack(anchor="w", pady=(2, 10))

        is_reg = mcons_core.is_context_menu_registered()
        status_text = "Status: Enabled in Windows Explorer" if is_reg else "Status: Not registered"
        status_color = COLOR_SUCCESS if is_reg else COLOR_TEXT_MUTED

        lbl_reg = ctk.CTkLabel(sc_inner, text=status_text, font=ctk.CTkFont(size=12, weight="bold"), text_color=status_color)
        lbl_reg.pack(anchor="w", pady=(0, 10))

        t_btn = ctk.CTkButton(
            sc_inner,
            text="Remove from Context Menu" if is_reg else "Enable Context Menu",
            font=ctk.CTkFont(size=12, weight="bold"),
            fg_color=COLOR_CARD_SURFACE if is_reg else COLOR_ACCENT,
            hover_color=COLOR_BORDER if is_reg else COLOR_ACCENT_HOVER,
            corner_radius=8,
            height=32,
            width=180,
            command=self._on_toggle_shell_menu
        )
        t_btn.pack(anchor="w")

        # Cache Card
        c_card = ctk.CTkFrame(container, fg_color=COLOR_CARD_BG, corner_radius=14, border_width=1, border_color=COLOR_BORDER)
        c_card.pack(fill="x")

        cc_inner = ctk.CTkFrame(c_card, fg_color="transparent")
        cc_inner.pack(fill="x", padx=20, pady=18)

        ct = ctk.CTkLabel(cc_inner, text="Thumbnail Cache", font=ctk.CTkFont(size=14, weight="bold"), text_color=COLOR_TEXT_PRIMARY)
        ct.pack(anchor="w")

        cd = ctk.CTkLabel(cc_inner, text="Clear temporary PNG thumbnails to free disk space.", font=ctk.CTkFont(size=12), text_color=COLOR_TEXT_SECONDARY)
        cd.pack(anchor="w", pady=(2, 10))

        clear_b = ctk.CTkButton(
            cc_inner,
            text="Clear Cache",
            font=ctk.CTkFont(size=12, weight="bold"),
            fg_color=COLOR_CARD_SURFACE,
            hover_color=COLOR_BORDER,
            corner_radius=8,
            height=32,
            width=120,
            command=self._on_clear_cache_btn
        )
        clear_b.pack(anchor="w")

    def _on_toggle_shell_menu(self):
        currently = mcons_core.is_context_menu_registered()
        mcons_core.set_context_menu_registered(not currently)
        self._render_settings_view()

    def _on_clear_cache_btn(self):
        c = mcons_core.clear_thumbnail_cache()
        messagebox.showinfo("MCons", f"Removed {c} cached thumbnails.")

    # =========================================================================
    # VIEW 8: ABOUT VIEW (Mirrors AboutView.swift)
    # =========================================================================

    def _render_about_view(self):
        container = ctk.CTkFrame(self.content_container, fg_color="transparent")
        container.pack(fill="both", expand=True, padx=32, pady=24)

        card = ctk.CTkFrame(container, fg_color=COLOR_CARD_BG, corner_radius=16, border_width=1, border_color=COLOR_BORDER)
        card.place(relx=0.5, rely=0.5, anchor="center")

        inner = ctk.CTkFrame(card, fg_color="transparent")
        inner.pack(padx=40, pady=36)

        icon_img = self._get_image_thumbnail("windows/mcons.ico", size=80)
        if icon_img:
            i_lbl = ctk.CTkLabel(inner, text="", image=icon_img)
            i_lbl.pack(pady=(0, 10))

        title = ctk.CTkLabel(inner, text="MCons for Windows", font=ctk.CTkFont(family="Segoe UI", size=24, weight="bold"), text_color=COLOR_TEXT_PRIMARY)
        title.pack()

        ver = ctk.CTkLabel(inner, text="Version 1.0.4 • Native Windows 10 & 11", font=ctk.CTkFont(size=12, weight="bold"), text_color=COLOR_ACCENT)
        ver.pack(pady=(2, 8))

        desc = ctk.CTkLabel(
            inner,
            text="Faithfully adapted from the macOS desktop design system.\nCrafted with high-resolution vector assets and desktop.ini integration.",
            font=ctk.CTkFont(size=12),
            text_color=COLOR_TEXT_SECONDARY,
            justify="center"
        )
        desc.pack(pady=(0, 18))

        row = ctk.CTkFrame(inner, fg_color="transparent")
        row.pack()

        gh_btn = ctk.CTkButton(
            row,
            text="GitHub Repository",
            font=ctk.CTkFont(size=12, weight="bold"),
            fg_color=COLOR_ACCENT,
            hover_color=COLOR_ACCENT_HOVER,
            corner_radius=8,
            height=34,
            command=lambda: webbrowser.open("https://github.com/neel0210/MCons")
        )
        gh_btn.pack(side="left", padx=4)

        issue_btn = ctk.CTkButton(
            row,
            text="Report Issue",
            font=ctk.CTkFont(size=12),
            fg_color=COLOR_CARD_SURFACE,
            hover_color=COLOR_BORDER,
            corner_radius=8,
            height=34,
            command=lambda: webbrowser.open("https://github.com/neel0210/MCons/issues")
        )
        issue_btn.pack(side="left", padx=4)

    # =========================================================================
    # HELPERS
    # =========================================================================

    def _get_image_thumbnail(self, path: str, size: int = 44) -> Optional[ctk.CTkImage]:
        cache_key = f"{path}_{size}"
        if cache_key in self.icon_cache:
            return self.icon_cache[cache_key]

        try:
            if path.endswith(".ico"):
                im = Image.open(path).convert("RGBA")
            else:
                thumb_path = mcons_core.get_icon_thumbnail_path(path, size=size)
                if thumb_path and os.path.exists(thumb_path):
                    im = Image.open(thumb_path).convert("RGBA")
                else:
                    im = mcons_core.extract_image_from_svg(path)

            if im:
                ctk_img = ctk.CTkImage(light_image=im, dark_image=im, size=(size, size))
                self.icon_cache[cache_key] = ctk_img
                return ctk_img
        except Exception:
            pass
        return None

    def _tint_hex(self, hex_color: str, factor: float = 0.3) -> str:
        """Mixes hex color with dark canvas background #0C0E14 for subtle banner backgrounds"""
        try:
            h = hex_color.lstrip('#')
            r, g, b = tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
            bg_r, bg_g, bg_b = 12, 14, 20
            out_r = int(r * factor + bg_r * (1 - factor))
            out_g = int(g * factor + bg_g * (1 - factor))
            out_b = int(b * factor + bg_b * (1 - factor))
            return f"#{out_r:02x}{out_g:02x}{out_b:02x}"
        except Exception:
            return COLOR_CARD_SURFACE


# =============================================================================
# CLI & LAUNCH ROUTINE
# =============================================================================

def cli_main():
    log_debug(f"cli_main started, argv={sys.argv}")

    # Dual GUI/CLI terminal attachment
    if any(arg in sys.argv[1:] for arg in ["apply", "restore", "list", "--help", "-h"]):
        if sys.platform == "win32":
            try:
                import ctypes
                if ctypes.windll.kernel32.AttachConsole(-1):
                    sys.stdout = open("CONOUT$", "w", encoding="utf-8")
                    sys.stderr = open("CONOUT$", "w", encoding="utf-8")
            except Exception:
                pass

    # Direct folder argument (e.g. from Explorer right-click context menu)
    if len(sys.argv) > 1 and not sys.argv[1].startswith("-") and sys.argv[1] not in ["apply", "restore", "list"]:
        folder_arg = sys.argv[1]
        if os.path.isdir(folder_arg):
            log_debug(f"Direct folder arg launch: {folder_arg}")
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
    log_debug(f"Parsed args: command={args.command}, folder={args.folder}")

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
        try:
            log_debug("Launching GUI: instantiating MConsWindowsApp...")
            app = MConsWindowsApp(initial_folder=args.folder)
            log_debug("Calling app.deiconify(), lift(), focus_force()...")
            app.deiconify()
            app.lift()
            app.focus_force()
            log_debug("Calling app.mainloop()...")
            app.mainloop()
            log_debug("app.mainloop() ended normally")
        except Exception as e:
            import traceback
            err_msg = traceback.format_exc()
            log_debug(f"Exception in GUI launch: {err_msg}")
            try:
                messagebox.showerror("MCons Error", f"Failed to launch MCons:\n\n{err_msg}")
            except Exception:
                pass


if __name__ == "__main__":
    cli_main()
