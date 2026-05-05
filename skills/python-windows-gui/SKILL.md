---
name: python-windows-gui
description: >
  Best practices for building modern, beautiful Windows desktop GUI applications using Python.
  Use this skill whenever the user wants to create a Windows desktop app, GUI application, or
  desktop tool with Python. Triggers include: mentions of Flet, NiceGUI, PySide6, PyQt6,
  customtkinter, Dear PyGui, tkinter, "modern UI", "beautiful interface", "looks good",
  "desktop app", "Windows app", "GUI", "graphical interface", "desktop tool", or any request
  to build a Python application with buttons, windows, forms, dialogs, menus, or visual
  interfaces. Also use when the user asks about packaging Python apps as .exe files,
  distributing Python desktop apps, using PyInstaller, `flet build`, or `flet pack`. Even if
  the user just says "build me an app" or "make a tool with a UI" in a Python context, use
  this skill.
---

# Modern Python Windows GUI Application Development

This skill provides best practices, patterns, and guidance for building **modern, professional-quality**
Windows desktop GUI applications with Python in 2026. It covers framework selection, project
structure, coding patterns, modern styling, threading, packaging, and distribution.

## What's Modern in 2026

The Python desktop GUI landscape changed substantially. The current top picks:

- **Flet** (Apache 2.0) — Flutter-based, gorgeous Material 3 UI, single Python codebase to desktop/web/mobile. The "modern look" default in 2026.
- **NiceGUI** (MIT) — Vue/Quasar/FastAPI under the hood, native desktop window via pywebview, web-styling fluency, fantastic for dashboards and internal tools.
- **PySide6** (LGPL) — The professional Qt6 binding. Still the gold standard for complex commercial desktop apps.
- **CustomTkinter** (MIT) — Modern flat look on top of stock tkinter; the quick-and-clean choice for simple internal utilities.
- **Dear PyGui** (MIT) — GPU-accelerated, ideal for real-time data viz, instrumentation, game-like UIs.

**Notable changes:** PySimpleGUI is no longer actively maintained — do **not** start new projects with it. Plain tkinter still ships with Python and works, but its default look is dated; reach for CustomTkinter or Flet instead. PyQt6 still works but PySide6 is preferred for new Qt projects (LGPL > GPL for commercial work).

## Quick Framework Decision

Choose based on what the user actually wants:

| User says... | Recommend | Why |
|---|---|---|
| "Modern", "beautiful", "looks like a real app" | **Flet** | Material 3 out of the box, animations, dark mode, looks 2026 |
| "Dashboard", "internal tool", "data viz UI" | **NiceGUI** | Charts, tables, bindings, served as web or native window |
| "Professional", "complex", "commercial app", "enterprise" | **PySide6** | 600+ classes, native widgets, mature tooling, QtSql, QtCharts |
| "Quick utility", "simple tool", "wrap a script" | **CustomTkinter** | Modern look, minimal API, no install pain, ships with Python's tkinter base |
| "Realtime", "high FPS", "data viz performance" | **Dear PyGui** | GPU-rendered, immediate-mode |
| "Just a file picker", "tiny prompt" | **tkinter** | Zero dependencies |

**Default recommendation when modernity matters most: Flet.** When commercial-grade native Windows feel matters most: PySide6. When the user wants a dashboard or web-like data tool: NiceGUI.

For a detailed breakdown of every framework, read `references/framework-comparison.md`.

## Modern Look — Read This First

Whenever the user asks for a "modern", "beautiful", "clean", or "professional-looking" UI, **read `references/modern-look-guide.md` before writing code.** It covers dark-mode-by-default, typography (Inter / Segoe UI Variable), spacing scales, Material 3 / Fluent patterns, icon systems (Lucide, Material Symbols, Phosphor), motion/animation, and accessibility.

For Morae-branded apps (when the user is at Morae Global / CLUTCH Group), also load the `morae-brand` skill so colors, fonts, and theming match the brand system.

## Project Structure

Always structure GUI projects properly from the start. Read `references/project-structure.md`
for full layouts for **Flet**, **NiceGUI**, and **PySide6** projects.

Generic recommended layout (PySide6 example):

```
my_app/
├── src/
│   ├── __init__.py
│   ├── main.py              # Entry point
│   ├── app.py               # QApplication setup
│   ├── ui/
│   │   ├── __init__.py
│   │   ├── main_window.py   # Main window class
│   │   ├── dialogs/         # Dialog windows
│   │   ├── widgets/         # Custom/reusable widgets
│   │   └── styles/          # QSS stylesheets or theme files
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py        # App configuration/settings
│   │   ├── database.py      # Database layer (if needed)
│   │   └── workers.py       # Background thread workers
│   ├── models/              # Data models
│   ├── utils/               # Helper functions
│   └── resources/           # Icons, images, fonts
│       ├── icons/
│       └── images/
├── tests/
├── scripts/
│   └── build.bat            # PyInstaller / flet build script
├── pyproject.toml
├── requirements.txt
└── README.md
```

## Core Coding Patterns

### Pattern 1: Flet "Hello, modern world"

```python
# main.py
import flet as ft

def main(page: ft.Page):
    page.title = "My App"
    page.theme_mode = ft.ThemeMode.DARK
    page.theme = ft.Theme(color_scheme_seed=ft.Colors.INDIGO)
    page.padding = 24

    page.add(
        ft.Text("Welcome", size=28, weight=ft.FontWeight.W_600),
        ft.ElevatedButton(
            "Click me",
            icon=ft.Icons.ROCKET_LAUNCH,
            on_click=lambda e: page.add(ft.Text("Hello!")),
        ),
    )

ft.app(target=main)  # Opens a native desktop window
```

Run: `pip install flet && python main.py`

### Pattern 2: NiceGUI "Hello, native desktop"

```python
# main.py
from nicegui import ui, native

ui.label("Welcome").classes("text-2xl font-semibold")
ui.button("Click me", on_click=lambda: ui.notify("Hello!"))

ui.run(
    native=True,                  # native desktop window via pywebview
    reload=False,                 # required for native mode
    port=native.find_open_port(), # avoid port collisions
    title="My App",
    window_size=(1000, 700),
    dark=True,
)
```

Run: `pip install "nicegui[native]" && python main.py`

### Pattern 3: PySide6 Application Entry Point

```python
# main.py — Keep this minimal
import sys
import ctypes
from PySide6.QtWidgets import QApplication
from PySide6.QtGui import QIcon, QFont
from ui.main_window import MainWindow

def main():
    # Windows taskbar icon fix (critical — do this before QApplication)
    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("mycompany.myapp.1.0")

    app = QApplication(sys.argv)
    app.setApplicationName("My App")
    app.setOrganizationName("MyCompany")
    app.setWindowIcon(QIcon("resources/icons/app.ico"))
    app.setFont(QFont("Segoe UI Variable", 10))  # Modern Windows 11 font

    window = MainWindow()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
```

### Pattern 4: PySide6 Main Window

```python
# ui/main_window.py
from PySide6.QtWidgets import QMainWindow, QWidget, QVBoxLayout
from PySide6.QtCore import QSettings, QSize

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("My Application")
        self.setMinimumSize(800, 600)

        self._setup_ui()
        self._setup_menu()
        self._setup_statusbar()
        self._load_settings()

    def _setup_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        self.layout = QVBoxLayout(central)

    def _setup_menu(self):
        menubar = self.menuBar()
        file_menu = menubar.addMenu("&File")

    def _setup_statusbar(self):
        self.statusBar().showMessage("Ready")

    def _load_settings(self):
        settings = QSettings()
        if (geometry := settings.value("geometry")):
            self.restoreGeometry(geometry)
        if (state := settings.value("windowState")):
            self.restoreState(state)

    def closeEvent(self, event):
        settings = QSettings()
        settings.setValue("geometry", self.saveGeometry())
        settings.setValue("windowState", self.saveState())
        super().closeEvent(event)
```

### Pattern 5: Threading — Never Block the GUI

This is the single most common mistake in GUI development. Long-running operations MUST run in
background threads. The GUI event loop runs on the main thread — blocking it freezes the entire
UI and Windows may mark your app as "Not Responding."

**PySide6 — QThread + signals:**

```python
from PySide6.QtCore import QThread, Signal

class Worker(QThread):
    progress = Signal(int)
    result = Signal(object)
    error = Signal(str)

    def __init__(self, task_fn, *args):
        super().__init__()
        self.task_fn = task_fn
        self.args = args

    def run(self):
        try:
            self.result.emit(self.task_fn(*self.args))
        except Exception as e:
            self.error.emit(str(e))
```

**Flet — async or threading.Thread + page.update():**

```python
import asyncio, flet as ft

async def long_task(page: ft.Page, status: ft.Text):
    status.value = "Working..."
    page.update()
    await asyncio.sleep(3)  # or await your real async work
    status.value = "Done!"
    page.update()
```

**NiceGUI — async-native (FastAPI under the hood):**

```python
from nicegui import ui
import asyncio

async def long_task():
    ui.notify("Working...")
    await asyncio.sleep(3)
    ui.notify("Done!")

ui.button("Run", on_click=long_task)
```

**Threading rules across all frameworks:**
- NEVER call GUI/widget methods from a worker thread — use signals (Qt) or `page.update()` (Flet) or async (NiceGUI)
- NEVER use `time.sleep()` in the main thread — use `asyncio.sleep()` or move work to a worker
- Keep a reference to QThread workers (`self.worker = ...`) to prevent garbage collection crashes
- Disable trigger buttons while work is running to prevent duplicate execution
- Always handle errors in workers and surface them to the user

### Pattern 6: Settings and Configuration

**PySide6 — `QSettings` (maps to Windows Registry):**

```python
from PySide6.QtCore import QSettings
settings = QSettings("MyCompany", "MyApp")
settings.setValue("last_directory", path)
last_dir = settings.value("last_directory", "")
```

**Flet / NiceGUI — `pathlib` + JSON in `%LOCALAPPDATA%`:**

```python
import json, os
from pathlib import Path

config_dir = Path(os.getenv("LOCALAPPDATA")) / "MyApp"
config_dir.mkdir(parents=True, exist_ok=True)
config_file = config_dir / "config.json"
```

NiceGUI also has `app.storage.user`, `app.storage.general`, and `app.storage.tab` for built-in persistence.

## Styling and Theming

For polished modern apps, **always** apply a deliberate visual theme. Read
`references/modern-look-guide.md` for a 2026 design system: colors, typography, spacing,
motion, icons, dark mode. Read `references/styling-guide.md` for QSS stylesheet specifics.

**Quick wins by framework:**

- **Flet**: `page.theme = ft.Theme(color_scheme_seed=...)` + `page.theme_mode = ft.ThemeMode.DARK` — Material 3 done.
- **NiceGUI**: `ui.run(dark=True)` plus Tailwind-style utility classes (`.classes("text-2xl rounded-2xl")`).
- **PySide6**: Load a `.qss` file with `app.setStyleSheet(...)`. Use `Segoe UI Variable` on Windows 11.
- **CustomTkinter**: `ctk.set_appearance_mode("dark")` and `ctk.set_default_color_theme("blue")`.

## Windows-Specific Considerations

### Taskbar Icon Fix (PySide6 / PyQt6 / tkinter)

Windows groups Python apps under the Python icon by default. Always fix this **before** creating QApplication / Tk:

```python
import ctypes
ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("mycompany.myapp.1.0")
```

Flet and NiceGUI handle this internally — no fix needed there.

### High-DPI Support

Qt6 (PySide6 / PyQt6) handles high-DPI scaling automatically. Flet inherits Flutter's per-monitor DPI awareness. NiceGUI inherits the embedded Edge WebView2 engine's scaling. No extra code needed.

### File and Directory Paths

```python
from pathlib import Path
import os

app_data    = Path(os.getenv("APPDATA"))         # Roaming
local_data  = Path(os.getenv("LOCALAPPDATA"))    # Local
documents   = Path.home() / "Documents"

# Qt cross-platform helper
from PySide6.QtCore import QStandardPaths
config_dir = QStandardPaths.writableLocation(QStandardPaths.AppConfigLocation)
```

### Resource Path Handling (PyInstaller)

When packaged, your app runs from a temp directory. Use this helper:

```python
import sys, os

def resource_path(relative_path: str) -> str:
    """Resolve resource path for both dev and PyInstaller bundle."""
    base = getattr(sys, "_MEIPASS", os.path.abspath("."))
    return os.path.join(base, relative_path)
```

## Packaging and Distribution

Read `references/packaging-guide.md` for the complete workflows. Quick summary by framework:

### Flet — Two Paths

**`flet build` (recommended, modern)** — uses Flutter SDK, embeds Python runtime, produces a fast offline executable. Requires Visual Studio 2022/2026 with the **Desktop development with C++** workload installed on Windows.

```bash
flet build windows
```

**`flet pack` (simpler, PyInstaller wrapper)** — works for most cases, fewer system prerequisites:

```bash
flet pack main.py --name "MyApp" --icon assets/icon.ico
```

### NiceGUI

NiceGUI ships a packaging helper (`nicegui-pack`) that wraps PyInstaller correctly. The key flags you need on Windows:

```bash
nicegui-pack --onefile --windowed --name "MyApp" main.py
# OR with raw PyInstaller:
pyinstaller --windowed --collect-all nicegui --hidden-import numpy --name "MyApp" main.py
```

The `--collect-all nicegui` flag is mandatory — without it, the static assets folder is missing at runtime. Use `native=True, reload=False` in `ui.run()` for packaged apps.

### PySide6 / CustomTkinter / Dear PyGui — PyInstaller

```bash
pip install pyinstaller pyinstaller-hooks-contrib
pyinstaller --name "MyApp" --windowed --icon=resources/icons/app.ico --onedir src/main.py
```

**Universal packaging rules:**
- Build inside a clean virtual environment
- Use `--onedir` for production — `--onefile` has slow startup and is harder to debug
- Test the packaged app on a clean machine without Python installed
- Use a `.spec` file for reproducible, version-controlled builds
- Only install ONE Qt binding (PySide6 OR PyQt6) per environment

## Common Pitfalls

1. **Choosing PySimpleGUI** — no longer maintained as of 2026; pick Flet, NiceGUI, or PySide6 instead
2. **Blocking the main thread** — Use QThread / async / workers for anything taking > 100ms
3. **Forgetting to keep worker references** — `self.worker = ...`, not `worker = ...`
4. **Modifying GUI from threads** — Always use signals / `page.update()` / async
5. **Missing AppUserModelID** — Causes wrong/missing taskbar icon on Windows for Qt/tkinter apps
6. **Using `--onefile` in production** — Slow startup, hard to debug; use `--onedir`
7. **Hardcoding file paths** — Use `pathlib`, `QStandardPaths`, or `os.getenv("LOCALAPPDATA")`
8. **Not saving/restoring window state** — Users expect geometry persistence
9. **Missing error handling in workers** — Unhandled exceptions in threads vanish silently
10. **Mixing Qt bindings** — Never import from both PyQt6 and PySide6 in the same project
11. **Not using layout managers** — Always use layouts, never fixed pixel positions
12. **NiceGUI native packaging without `--collect-all nicegui`** — Static assets won't bundle and the app crashes silently
13. **Flet `flet build` without Visual Studio C++ workload** — Build fails; either install it or fall back to `flet pack`

## Reference Files

Read these as needed for deeper guidance on specific topics:

| File | When to read |
|------|-------------|
| `references/modern-look-guide.md` | **Always read for "modern" / "beautiful" requests.** Color systems, typography, spacing, dark mode, motion, icons |
| `references/framework-comparison.md` | Choosing between frameworks; full comparison incl. Flet, NiceGUI, PySide6, CustomTkinter, Dear PyGui, tkinter |
| `references/project-structure.md` | Starting a new project — full boilerplate and recommended layouts |
| `references/styling-guide.md` | QSS stylesheets, dark/light QSS themes, Qt-specific styling tricks |
| `references/packaging-guide.md` | Building .exe — `flet build`, `flet pack`, `nicegui-pack`, PyInstaller spec files, installers |
| `references/patterns-and-recipes.md` | Common UI patterns: tables, forms, file dialogs, tray icons, charts, etc. |
