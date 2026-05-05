# Project Structure — Starting a New Python GUI Project

## Table of Contents
0. **Flet & NiceGUI Layouts** ← read first if using these frameworks
1. Recommended Directory Layout (PySide6)
2. Boilerplate Files
3. Virtual Environment Setup
4. Dependencies Management

---

## 0. Flet & NiceGUI Layouts

### Flet — Small (single screen)

```
my_app/
├── main.py
├── pyproject.toml          # Required for `flet build`
├── requirements.txt
└── assets/
    ├── icon.png            # Default app icon (Flet auto-converts to .ico)
    └── fonts/
        └── Inter-Regular.ttf
```

**Minimal `pyproject.toml`:**
```toml
[project]
name = "my-app"
version = "1.0.0"
dependencies = ["flet>=0.80"]

[tool.flet]
org = "com.mycompany"
product = "MyApp"
company = "MyCompany"
copyright = "Copyright 2026 MyCompany"
```

### Flet — Medium / Large (multiple views)

```
my_app/
├── pyproject.toml
├── src/
│   ├── main.py             # Entry point — `ft.app(target=main)`
│   ├── app.py              # Page setup, theme, routing
│   ├── views/
│   │   ├── __init__.py
│   │   ├── home.py
│   │   ├── settings.py
│   │   └── about.py
│   ├── components/
│   │   ├── __init__.py
│   │   ├── card.py         # Reusable card component
│   │   └── nav_bar.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py       # JSON config in %LOCALAPPDATA%
│   │   ├── theme.py        # Color tokens, typography
│   │   └── api.py          # Backend / data layer
│   └── assets/
│       ├── icon.png
│       └── fonts/
└── tests/
```

### NiceGUI — Small

```
my_app/
├── main.py                 # Entry point
├── requirements.txt        # nicegui[native]
└── static/                 # Custom static files (optional)
    └── logo.svg
```

**Minimal `main.py`:**
```python
from nicegui import ui, native

ui.label("Hello").classes("text-2xl")
ui.run(native=True, reload=False, port=native.find_open_port(), title="My App", dark=True)
```

### NiceGUI — Medium / Large (multi-page)

```
my_app/
├── pyproject.toml
├── src/
│   ├── main.py             # Entry point with ui.run()
│   ├── pages/
│   │   ├── __init__.py
│   │   ├── home.py         # @ui.page('/') decorated functions
│   │   ├── settings.py     # @ui.page('/settings')
│   │   └── about.py
│   ├── components/
│   │   ├── __init__.py
│   │   ├── header.py
│   │   └── sidebar.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── theme.py        # ui.colors() setup, fonts
│   │   ├── storage.py      # app.storage helpers
│   │   └── api.py
│   └── static/
│       ├── logo.svg
│       └── style.css       # Custom CSS via ui.add_head_html
└── tests/
```

**Pattern for multi-page NiceGUI:**

```python
# src/main.py
from nicegui import ui, native
from pages import home, settings, about  # noqa - imports register routes

# Theme
ui.colors(primary="#6366F1")

ui.run(
    native=True,
    reload=False,
    port=native.find_open_port(),
    title="My App",
    window_size=(1200, 800),
    dark=True,
)
```

```python
# src/pages/home.py
from nicegui import ui

@ui.page("/")
def home():
    ui.label("Home").classes("text-2xl font-semibold")
```

---

## 1. Recommended Directory Layout (PySide6)

### Small app (single window, < 1000 LOC)

```
my_tool/
├── main.py                # Entry point + window definition
├── workers.py             # Background threads (if needed)
├── resources/
│   └── icons/
│       └── app.ico
├── styles/
│   └── theme.qss
├── requirements.txt
└── build.bat
```

### Medium app (multiple windows, 1K-10K LOC)

```
my_app/
├── src/
│   ├── __init__.py
│   ├── main.py            # Entry point only
│   ├── ui/
│   │   ├── __init__.py
│   │   ├── main_window.py
│   │   ├── dialogs/
│   │   │   ├── __init__.py
│   │   │   ├── settings_dialog.py
│   │   │   └── about_dialog.py
│   │   ├── widgets/
│   │   │   ├── __init__.py
│   │   │   └── status_widget.py
│   │   └── styles/
│   │       ├── dark_theme.qss
│   │       └── light_theme.qss
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py
│   │   └── workers.py
│   ├── models/
│   │   └── __init__.py
│   ├── utils/
│   │   ├── __init__.py
│   │   └── paths.py
│   └── resources/
│       ├── icons/
│       │   └── app.ico
│       └── images/
├── tests/
│   ├── __init__.py
│   └── test_core.py
├── scripts/
│   └── build.bat
├── app.spec
├── requirements.txt
├── pyproject.toml
└── README.md
```

### Large app (10K+ LOC, multiple modules)

Add to the medium structure:
- `src/services/` — Business logic services
- `src/database/` — Database models, migrations, DAL
- `src/api/` — External API client code
- `src/plugins/` — Plugin system (if applicable)
- `docs/` — Project documentation
- `scripts/` — Build, deploy, and utility scripts

---

## 2. Boilerplate Files

### main.py

```python
"""Application entry point."""
import sys
import os
import ctypes

def main():
    # Windows taskbar icon fix — must be before QApplication
    if sys.platform == "win32":
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(
            "mycompany.myapp.1.0"
        )

    from PySide6.QtWidgets import QApplication
    from PySide6.QtGui import QIcon, QFont
    from ui.main_window import MainWindow
    from utils.paths import resource_path

    app = QApplication(sys.argv)
    app.setApplicationName("My Application")
    app.setOrganizationName("MyCompany")
    app.setOrganizationDomain("mycompany.com")
    app.setWindowIcon(QIcon(resource_path("resources/icons/app.ico")))
    app.setFont(QFont("Segoe UI", 10))

    # Load stylesheet
    style_path = resource_path("ui/styles/dark_theme.qss")
    if os.path.exists(style_path):
        with open(style_path, "r") as f:
            app.setStyleSheet(f.read())

    # Global exception hook for crash logging
    sys.excepthook = _exception_hook

    window = MainWindow()
    window.show()
    sys.exit(app.exec())


def _exception_hook(exc_type, exc_value, exc_tb):
    """Log unhandled exceptions."""
    import traceback
    from pathlib import Path

    log_dir = Path.home() / "AppData" / "Local" / "MyApp" / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / "crash.log"

    with open(log_file, "a") as f:
        f.write(f"\n{'='*60}\n")
        traceback.print_exception(exc_type, exc_value, exc_tb, file=f)

    # Still call default handler
    sys.__excepthook__(exc_type, exc_value, exc_tb)


if __name__ == "__main__":
    main()
```

### utils/paths.py

```python
"""Path utilities for development and packaged environments."""
import sys
import os

def resource_path(relative_path: str) -> str:
    """Get absolute path to resource. Works in dev and when packaged with PyInstaller."""
    if getattr(sys, 'frozen', False):
        base_path = sys._MEIPASS
    else:
        # In development, resolve relative to project root
        base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    return os.path.join(base_path, relative_path)


def app_data_path(filename: str = "") -> str:
    """Get path in the app's local data directory (AppData/Local/MyApp/)."""
    base = os.path.join(os.getenv("LOCALAPPDATA", ""), "MyApp")
    os.makedirs(base, exist_ok=True)
    return os.path.join(base, filename) if filename else base
```

### core/workers.py

```python
"""Reusable background worker classes."""
from PySide6.QtCore import QThread, Signal, QObject


class Worker(QThread):
    """Generic worker thread. Pass a callable and its arguments."""
    progress = Signal(int)          # 0-100 progress percentage
    result = Signal(object)         # Final result
    error = Signal(str)             # Error message
    status = Signal(str)            # Status text updates

    def __init__(self, fn, *args, **kwargs):
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
        self._is_cancelled = False

    def run(self):
        try:
            # Pass self to allow progress reporting from the task
            result = self.fn(*self.args, worker=self, **self.kwargs)
            if not self._is_cancelled:
                self.result.emit(result)
        except Exception as e:
            self.error.emit(f"{type(e).__name__}: {e}")

    def cancel(self):
        """Request cancellation. The task function must check worker._is_cancelled."""
        self._is_cancelled = True


class WorkerPool:
    """Manage multiple workers and prevent garbage collection."""

    def __init__(self):
        self._workers = []

    def start(self, worker: Worker):
        """Start a worker and track it."""
        worker.finished.connect(lambda: self._cleanup(worker))
        self._workers.append(worker)
        worker.start()

    def _cleanup(self, worker):
        """Remove finished workers."""
        if worker in self._workers:
            self._workers.remove(worker)

    def cancel_all(self):
        """Cancel all running workers."""
        for worker in self._workers:
            worker.cancel()
            worker.quit()
            worker.wait(3000)
```

### core/config.py

```python
"""Application configuration using QSettings."""
from PySide6.QtCore import QSettings, QSize, QPoint


class AppConfig:
    """Centralized settings management."""

    def __init__(self):
        self._settings = QSettings("MyCompany", "MyApp")

    # Window state
    def save_window_state(self, window):
        self._settings.setValue("window/geometry", window.saveGeometry())
        self._settings.setValue("window/state", window.saveState())

    def restore_window_state(self, window):
        geometry = self._settings.value("window/geometry")
        if geometry:
            window.restoreGeometry(geometry)
        state = self._settings.value("window/state")
        if state:
            window.restoreState(state)

    # Generic get/set with type safety
    def get(self, key: str, default=None, type_=None):
        value = self._settings.value(key, default)
        if type_ and value is not None:
            try:
                return type_(value)
            except (ValueError, TypeError):
                return default
        return value

    def set(self, key: str, value):
        self._settings.setValue(key, value)

    # Recent files
    def get_recent_files(self, max_count=10):
        files = self._settings.value("recent_files", [])
        return files[:max_count] if isinstance(files, list) else []

    def add_recent_file(self, filepath: str, max_count=10):
        files = self.get_recent_files(max_count)
        if filepath in files:
            files.remove(filepath)
        files.insert(0, filepath)
        self._settings.setValue("recent_files", files[:max_count])
```

### requirements.txt

```
PySide6>=6.6.0
darkdetect>=0.8.0
```

### pyproject.toml

```toml
[project]
name = "my-app"
version = "1.0.0"
description = "My Windows Desktop Application"
requires-python = ">=3.10"
dependencies = [
    "PySide6>=6.6.0",
]

[project.optional-dependencies]
dev = [
    "pyinstaller>=6.0",
    "pyinstaller-hooks-contrib",
    "pytest>=7.0",
]
```

---

## 3. Virtual Environment Setup

```bash
# Create project virtual environment
python -m venv .venv

# Activate (Windows)
.venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# For development
pip install -r requirements.txt
pip install pyinstaller pyinstaller-hooks-contrib pytest
```

**Tip**: Use a SEPARATE build environment for packaging to keep it clean:

```bash
python -m venv build_env
build_env\Scripts\activate
pip install -r requirements.txt
pip install pyinstaller pyinstaller-hooks-contrib
```

---

## 4. Dependencies Management

### Choosing between PySide6 and PySide6-Essentials

- `PySide6` — Full install (~200MB), includes WebEngine, Multimedia, 3D, etc.
- `PySide6-Essentials` — Core modules only (~80MB), sufficient for most apps

If you don't need WebEngine, Multimedia, or 3D, use Essentials to save space
(especially important for packaged distributions):

```
PySide6-Essentials>=6.6.0
```

### Common optional dependencies

| Package | Purpose |
|---------|---------|
| `darkdetect` | Detect Windows dark/light mode |
| `qtawesome` | FontAwesome and Material icons for Qt |
| `sqlalchemy` | Database ORM (if using database) |
| `keyring` | Secure credential storage on Windows |
| `pyperclip` | Clipboard operations |
| `watchdog` | File system monitoring |
