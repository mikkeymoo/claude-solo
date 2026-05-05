---
name: python-windows-gui
description: >
  Best practices for building modern, professional Windows desktop GUI applications using Python.
  Use this skill whenever the user wants to create a Windows desktop app, GUI application, or
  desktop tool with Python. Triggers include: mentions of PySide6, PyQt6, customtkinter,
  Flet, NiceGUI, Dear PyGui, tkinter, "modern UI", "beautiful interface", "looks good",
  "desktop app", "Windows app", "GUI", "graphical interface", "desktop tool", or any request
  to build a Python application with buttons, windows, forms, dialogs, menus, or visual
  interfaces. Also use when the user asks about packaging Python apps as .exe files,
  distributing Python desktop apps, or using PyInstaller. Even if the user just says "build me
  an app" or "make a tool with a UI" in a Python context, use this skill.
---

# Modern Python Windows GUI Application Development

This skill provides best practices, patterns, and guidance for building **modern, professional-quality**
Windows desktop GUI applications with Python in 2026. It covers framework selection, project
structure, coding patterns, modern styling, threading, packaging, and distribution.

## Best-Practices Default: PySide6

**For production Windows desktop apps in 2026, the default best-practices choice is PySide6** (Qt 6.11+, official Python binding from The Qt Company, classified `Production/Stable` on PyPI). It is:

- **Mature** — Qt has 30+ years of development, PySide since 2009. Used by Spotify, Dropbox, Calibre, Autodesk Maya, Blender's UI patterns, and countless commercial apps.
- **Stable API** — semantic versioning, predictable upgrades, deep documentation.
- **Native widgets** — looks correct on Windows 11, including high-DPI and dark mode.
- **Comprehensive** — 600+ classes covering UI, networking, multimedia, SQL, charts, 3D, web view, etc.
- **Permissive licensing** — LGPL means free for commercial closed-source use.
- **Modern look is achievable** — with thoughtful QSS theming you can build UIs that look as good as anything in Electron or Flutter (read `references/modern-look-guide.md`).

**Default this skill to PySide6 unless the user explicitly asks for something else or has a clear reason to choose differently.**

## When to Choose Something Else

Other frameworks have legitimate niches. Pick them only when the trade-offs match the user's real needs:

| Use case | Pick | Why | Trade-off |
|----------|------|-----|-----------|
| Quick utility, modern flat look, minimal install | **CustomTkinter** | MIT, 5-minute setup, modern dark/light themes on top of stdlib tkinter | Limited widget set, no native networking/SQL; not for complex apps |
| Cross-platform desktop+web+mobile from one codebase | **Flet** | Flutter under the hood, gorgeous Material 3 default, single codebase | **Pre-1.0** (currently 0.84) — APIs still changing; performance overhead from Python↔Flutter bridge; debugging spans two runtimes |
| Internal dashboard, data tool, IoT panel | **NiceGUI** | Vue/Quasar/FastAPI stack, Tailwind classes, native or web | Web-based feel (not native widgets); ~200MB bundles via WebView2 |
| GPU-accelerated realtime data viz / instrumentation | **Dear PyGui** | DirectX/OpenGL rendering, immediate-mode | Non-native look; different mental model |
| Tablet/touch kiosk, mobile-first | **Kivy** | Multitouch, OpenGL ES, mobile deployment | Non-native look on desktop; KV language learning curve |
| Tiny prompt with zero deps | **tkinter** | Ships with Python | Dated default appearance |

**Avoid:**
- **PySimpleGUI** — no longer actively maintained as of 2026; not a safe pick for new work.
- **PyQt6 over PySide6** for new commercial projects — PyQt6 is GPL (requires open-sourcing OR a commercial license); PySide6 is LGPL (free for closed-source). The APIs are nearly identical; pick PySide6 by default.

For full per-framework details, read `references/framework-comparison.md`.

## Honest Note on Flet (and "Modern" Frameworks)

If the user says "I want a modern-looking app," it's tempting to reach for Flet because the defaults look gorgeous out of the box. But "modern look" is not the same as "best practice." A few things to be straight about:

- **Flet is pre-1.0** (0.84 as of April 2026). The team is actively working toward a 1.0 with stability guarantees, but **APIs are still changing** between releases. For a tool that needs to be maintainable for years, this is a real cost.
- **Flet's architecture is a Python↔Flutter bridge** over a local message protocol. For UI-heavy apps with frequent state changes, this adds latency and event chatter compared to in-process Qt.
- **Debugging is split-brain** — Flutter DevTools won't see Python-side issues, and Python debuggers don't see the Flutter rendering layer.
- **PySide6 with a thoughtful QSS theme can look every bit as modern as Flet.** The "default look" gap is real but closeable. See `references/modern-look-guide.md`.

**When Flet is the right call:** internal tools where time-to-first-UI is the main constraint, prototypes, or when the user genuinely needs the same codebase to ship to web/mobile too. **When PySide6 is the right call:** anything destined for production with a multi-year lifespan, anything that needs deep Windows integration, anything performance-sensitive.

NiceGUI sits in a similar place — fantastic for what it is (web-stack dashboards), but not a default for Windows desktop apps.

## Project Structure

Always structure GUI projects properly from the start. Read `references/project-structure.md`
for full layouts. Recommended layout for a PySide6 production app:

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
│   ├── models/              # Data models (Qt models for views)
│   ├── utils/               # Helper functions
│   └── resources/           # Icons, images, fonts
│       ├── icons/
│       └── images/
├── tests/
├── scripts/
│   └── build.bat            # PyInstaller build script
├── pyproject.toml
├── requirements.txt
└── README.md
```

## Core Coding Patterns (PySide6)

### Pattern 1: Application Entry Point

```python
# main.py — Keep this minimal
import sys
import ctypes
from PySide6.QtWidgets import QApplication
from PySide6.QtGui import QIcon, QFont
from ui.main_window import MainWindow

def main():
    # Windows taskbar icon fix (critical — must run before QApplication)
    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("mycompany.myapp.1.0")

    app = QApplication(sys.argv)
    app.setApplicationName("My App")
    app.setOrganizationName("MyCompany")
    app.setOrganizationDomain("mycompany.com")
    app.setWindowIcon(QIcon("resources/icons/app.ico"))
    app.setFont(QFont("Segoe UI Variable", 10))  # Modern Windows 11 font

    # Apply theme stylesheet
    with open("ui/styles/dark.qss", "r", encoding="utf-8") as f:
        app.setStyleSheet(f.read())

    window = MainWindow()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
```

### Pattern 2: Main Window with State Persistence

```python
# ui/main_window.py
from PySide6.QtWidgets import QMainWindow, QWidget, QVBoxLayout
from PySide6.QtCore import QSettings

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
        settings = QSettings()  # Uses app/org name set in main.py
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

### Pattern 3: Threading — Never Block the GUI

This is the single most common mistake in GUI development. Long-running operations MUST run in
background threads. The GUI event loop runs on the main thread — blocking it freezes the entire
UI and Windows may mark your app as "Not Responding."

```python
# core/workers.py
from PySide6.QtCore import QThread, Signal

class Worker(QThread):
    """Generic worker for running a callable on a background thread."""
    progress = Signal(int)
    result = Signal(object)
    error = Signal(str)

    def __init__(self, task_fn, *args, **kwargs):
        super().__init__()
        self.task_fn = task_fn
        self.args = args
        self.kwargs = kwargs

    def run(self):
        try:
            result = self.task_fn(*self.args, **self.kwargs)
            self.result.emit(result)
        except Exception as e:
            self.error.emit(str(e))
```

```python
# In your window class:
def start_long_task(self):
    self.run_button.setEnabled(False)
    self.worker = Worker(do_heavy_work, "input.csv")  # store ref!
    self.worker.result.connect(self.on_done)
    self.worker.error.connect(self.on_error)
    self.worker.finished.connect(lambda: self.run_button.setEnabled(True))
    self.worker.start()
```

**Threading rules:**
- NEVER call widget methods from a worker thread — emit signals, connect them on the main thread
- NEVER use `time.sleep()` on the main thread
- ALWAYS keep a reference to the worker (`self.worker = ...`) — local refs get garbage collected and crash the app
- ALWAYS disable the trigger button while work is running
- ALWAYS handle errors in `run()` — uncaught exceptions in QThreads vanish silently

### Pattern 4: Settings via QSettings

```python
from PySide6.QtCore import QSettings

settings = QSettings()  # Uses app/org name set with setApplicationName/setOrganizationName
settings.setValue("last_directory", path)
last_dir = settings.value("last_directory", "", type=str)  # Default empty string
```

`QSettings` writes to the Windows Registry on Windows automatically — no JSON file management needed.

### Pattern 5: Model/View for Data

For any list, table, or tree of more than ~50 items, use Qt's Model/View architecture rather than naive `QListWidget`/`QTableWidget`. It scales to millions of rows, supports sorting/filtering proxy models, and separates data from presentation. See `references/patterns-and-recipes.md` Section 1 for a working `QAbstractTableModel` example.

## Modern Look — Read This For Visual Polish

If the user wants a "modern", "beautiful", or "professional-looking" UI, **read `references/modern-look-guide.md` before writing code.** It covers a 2026 design system: dark mode by default, typography (Segoe UI Variable / Inter), 4-point spacing, generous radius, Material 3 / Fluent patterns, icons (Lucide / Material Symbols / Phosphor), motion (150-250ms ease-out), accessibility, and a complete dark-mode QSS theme for PySide6.

**Modern look is absolutely achievable in PySide6 with QSS.** The framework's "default" appearance is conservative, but a thoughtful 200-line stylesheet brings it fully up to 2026 standards.

For Morae-branded apps (Morae Global / CLUTCH Group), also load the `morae-brand` skill so colors, fonts, and theming match the brand system.

## Styling and Theming

Read `references/styling-guide.md` for QSS specifics. Quick wins:

- Load a QSS file at startup with `app.setStyleSheet(open("dark.qss").read())`
- Use `Segoe UI Variable` on Windows 11, fall back to `Segoe UI`
- Use `setProperty("role", "primary")` on widgets and target with `QPushButton[role="primary"]` in QSS — keeps stylesheets clean
- Refresh styles after property changes with `widget.style().unpolish(widget); widget.style().polish(widget)`

## Windows-Specific Considerations

### Taskbar Icon Fix (Required)

Windows groups Python apps under the Python icon by default. Always fix this **before** creating QApplication:

```python
import ctypes
ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("mycompany.myapp.1.0")
```

### High-DPI Support

Qt6 handles high-DPI scaling automatically — no extra code needed for most apps.

### File and Directory Paths

```python
from pathlib import Path
import os
from PySide6.QtCore import QStandardPaths

# Native Windows
app_data    = Path(os.getenv("APPDATA"))         # Roaming
local_data  = Path(os.getenv("LOCALAPPDATA"))    # Local
documents   = Path.home() / "Documents"

# Qt cross-platform helper (preferred — works on macOS/Linux too)
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

Read `references/packaging-guide.md` for full details. The mature path for Python desktop apps is **PyInstaller**:

```bash
pip install pyinstaller pyinstaller-hooks-contrib
pyinstaller --name "MyApp" --windowed --icon=resources/icons/app.ico --onedir src/main.py
```

**Universal packaging rules:**
- Build inside a clean virtual environment (extra installed packages get bundled, bloating output)
- Use `--onedir` for production — `--onefile` has slow startup and is harder to debug
- Test the packaged app on a clean Windows machine without Python installed
- Use a `.spec` file for reproducible, version-controlled builds
- Only install ONE Qt binding per environment (PySide6 OR PyQt6, never both)
- For installers, use **Inno Setup** (free, scriptable) — covered in the packaging guide

## Common Pitfalls

1. **Choosing PySimpleGUI** — no longer maintained as of 2026; pick PySide6 (production) or CustomTkinter (quick) instead
2. **Choosing PyQt6 over PySide6 for commercial work** — PyQt6 is GPL; PySide6 is LGPL. Same API, very different licensing.
3. **Choosing pre-1.0 frameworks for production** — Flet (0.84 as of 2026) is exciting but APIs are still changing. Acceptable for prototypes/internal tools; risky for multi-year production code.
4. **Blocking the main thread** — Use QThread / workers for anything taking > 100ms
5. **Forgetting to keep worker references** — `self.worker = ...`, not `worker = ...`
6. **Modifying GUI from threads** — Always use signals to marshal back to the main thread
7. **Missing AppUserModelID** — Causes wrong/missing taskbar icon on Windows
8. **Using `--onefile` in production** — Slow startup, hard to debug; use `--onedir`
9. **Hardcoding file paths** — Use `pathlib`, `QStandardPaths`, or `os.getenv("LOCALAPPDATA")`
10. **Not saving/restoring window state** — Users expect geometry persistence
11. **Missing error handling in workers** — Unhandled exceptions in threads vanish silently
12. **Mixing Qt bindings** — Never import from both PyQt6 and PySide6 in the same project
13. **Not using layout managers** — Always use layouts, never fixed pixel positions
14. **Using `QListWidget`/`QTableWidget` for big datasets** — Use the Model/View architecture for anything over ~50 rows

## Reference Files

Read these as needed for deeper guidance on specific topics:

| File | When to read |
|------|-------------|
| `references/modern-look-guide.md` | **Always read for "modern" / "beautiful" requests.** Color systems, typography, spacing, dark mode QSS theme, motion, icons |
| `references/framework-comparison.md` | Choosing between frameworks; full PySide6/Flet/NiceGUI/CustomTkinter/Dear PyGui/tkinter/Kivy comparison |
| `references/project-structure.md` | Starting a new project — full boilerplate and recommended layouts |
| `references/styling-guide.md` | QSS stylesheets, dark/light QSS themes, Qt-specific styling tricks |
| `references/packaging-guide.md` | Building .exe — PyInstaller spec files, Inno Setup installers, code signing |
| `references/patterns-and-recipes.md` | Common UI patterns: tables, forms, file dialogs, tray icons, charts, etc. |
