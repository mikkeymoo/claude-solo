# Packaging Guide — Building and Distributing Windows GUI Apps

## Table of Contents
0. **Modern Framework Packaging (Flet & NiceGUI)** ← read first if using these frameworks
1. PyInstaller Setup
2. Basic Build Commands
3. Spec File Configuration
4. Handling Data Files and Resources
5. Common Build Issues and Fixes
6. Creating a Windows Installer
7. Code Signing
8. Alternative Packagers

---

## 0. Modern Framework Packaging (Flet & NiceGUI)

### 0a. Flet — `flet build` (recommended, modern)

`flet build` uses the Flutter SDK to produce a fast, offline, fully customizable executable with the Python runtime embedded **in-process** (not as a side process). This is the modern, recommended path.

**Prerequisites on Windows:**
- Visual Studio 2022 or 2026 with the **"Desktop development with C++"** workload installed
- Developer Mode enabled (`start ms-settings:developers` → toggle Developer Mode)
- Flet auto-downloads the matching Flutter SDK on first run

**Project layout (recommended):**
```
my_app/
├── pyproject.toml      # metadata + build settings
└── src/
    ├── main.py
    └── assets/
        └── icon.png
```

**Build command:**
```bash
flet build windows
```

The output goes to `build/windows/`. Zip it and ship.

**`pyproject.toml` key settings:**
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

### 0b. Flet — `flet pack` (simpler, PyInstaller wrapper)

If you can't install Visual Studio's C++ workload, `flet pack` falls back to PyInstaller and works with just Python. It's simpler but produces a slightly heavier bundle.

```bash
flet pack main.py \
    --name "MyApp" \
    --icon assets/icon.ico \
    --product-name "MyApp" \
    --product-version "1.0.0" \
    --company-name "MyCompany" \
    --copyright "Copyright 2026 MyCompany"
```

Use `--onedir` (`-D`) for production — faster startup than the default one-file mode.

**Key flags:**
- `--icon` — sets executable icon AND the running window's icon (ICO on Windows, PNG converted automatically if Pillow is installed)
- `--add-data "assets;assets"` — bundle data folder (use `;` separator on Windows, `:` on macOS/Linux)
- `--hidden-import` — for modules that PyInstaller misses
- `--debug-console` — show console for debugging; remove for production

### 0c. NiceGUI — `nicegui-pack` or PyInstaller

NiceGUI ships a `nicegui-pack` command that wraps PyInstaller with the correct flags. It's the path of least resistance.

```bash
nicegui-pack --onefile --windowed --name "MyApp" main.py
```

**Important:** Set `native=True, reload=False` in `ui.run()`, and use `port=native.find_open_port()` to avoid port collisions:

```python
from nicegui import ui, native

# ... your UI code ...

ui.run(
    native=True,
    reload=False,                  # MUST be False for packaged apps
    port=native.find_open_port(),  # avoid hardcoded ports
    title="MyApp",
    window_size=(1200, 800),
)
```

**Manual PyInstaller invocation (when nicegui-pack isn't enough):**

```bash
pyinstaller --windowed --onefile \
    --name "MyApp" \
    --icon assets/icon.ico \
    --collect-all nicegui \
    --hidden-import numpy \
    main.py
```

**The `--collect-all nicegui` flag is mandatory.** Without it, the static assets folder isn't bundled and the app crashes silently with `static folder does not exist` from Starlette. This is the #1 cause of "my NiceGUI exe does nothing" reports.

If your app uses additional packages with native extensions, you may need extra `--hidden-import` or `--collect-all` flags for them too.

### Comparison: Which Flet/NiceGUI packager?

| Need | Use |
|------|-----|
| Smallest, fastest Flet executable | `flet build` (needs VS C++ workload) |
| Flet without installing VS | `flet pack` |
| NiceGUI quick path | `nicegui-pack` |
| NiceGUI with custom flags | raw `pyinstaller --collect-all nicegui ...` |

---

## 1. PyInstaller Setup

### Environment preparation (critical)

Always build from a **clean virtual environment** that contains only your app's dependencies.
Extra packages in your environment get bundled, bloating the output.

```bash
# Create a dedicated build environment
python -m venv build_env
build_env\Scripts\activate

# Install only what your app needs
pip install PySide6
pip install -r requirements.txt

# Install PyInstaller and hooks
pip install pyinstaller pyinstaller-hooks-contrib
```

**Important**: Only install ONE Qt binding package. PyInstaller will error if it detects
multiple Qt bindings (PySide6 + PyQt6, etc.) in the same environment.

### Verify before building

```bash
# Check PyInstaller version
pyinstaller --version

# Verify hooks are up to date
pip install --upgrade pyinstaller-hooks-contrib
```

---

## 2. Basic Build Commands

### Recommended: onedir mode

```bash
pyinstaller --name "MyApp" ^
    --windowed ^
    --icon=resources/icons/app.ico ^
    --onedir ^
    src/main.py
```

### Flag reference

| Flag | Purpose |
|------|---------|
| `--name "MyApp"` | Name of the output executable |
| `--windowed` / `-w` | No console window (essential for GUI apps) |
| `--onedir` | Output as directory (recommended) |
| `--onefile` | Output as single .exe (slower startup) |
| `--icon=path.ico` | Application icon (.ico format on Windows) |
| `--add-data "src;dest"` | Bundle data files (`;` separator on Windows) |
| `--hidden-import module` | Force-include a module PyInstaller missed |
| `--exclude-module module` | Exclude an unnecessary module to reduce size |
| `--clean` | Clean cache before building |
| `--noconfirm` | Overwrite output without asking |

### Output structure

```
dist/
└── MyApp/
    ├── MyApp.exe              # Your application
    ├── PySide6/               # Qt libraries
    │   ├── plugins/
    │   └── ...
    ├── python3.dll
    ├── resources/             # Your bundled data files
    └── ...                    # Other dependencies
```

---

## 3. Spec File Configuration

After your first build, PyInstaller creates a `.spec` file. Use this for reproducible builds
instead of command-line flags.

### Example spec file (`app.spec`)

```python
# -*- mode: python ; coding: utf-8 -*-

import sys
from pathlib import Path

block_cipher = None

# Determine paths
src_path = Path('src')
resources_path = src_path / 'resources'

a = Analysis(
    [str(src_path / 'main.py')],
    pathex=[],
    binaries=[],
    datas=[
        # (source, destination_in_bundle)
        (str(resources_path / 'icons'), 'resources/icons'),
        (str(resources_path / 'images'), 'resources/images'),
        (str(src_path / 'ui' / 'styles'), 'ui/styles'),
    ],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter',        # Exclude unused frameworks
        'unittest',
        'email',
        'xml',
        'pydoc',
    ],
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='MyApp',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,              # Compress with UPX if available
    console=False,         # No console window
    disable_windowed_traceback=False,
    argv_emulation=False,
    icon='src/resources/icons/app.ico',
    # Windows version info
    version='version_info.txt',
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='MyApp',
)
```

### Build from spec file

```bash
pyinstaller app.spec --clean --noconfirm
```

### Version info file (`version_info.txt`)

Create this for Windows file properties (right-click → Properties → Details):

```python
VSVersionInfo(
    ffi=FixedFileInfo(
        filevers=(1, 0, 0, 0),
        prodvers=(1, 0, 0, 0),
        mask=0x3f,
        flags=0x0,
        OS=0x40004,
        fileType=0x1,
        subtype=0x0,
        date=(0, 0)
    ),
    kids=[
        StringFileInfo([
            StringTable(
                '040904B0', [
                    StringStruct('CompanyName', 'My Company'),
                    StringStruct('FileDescription', 'My Application'),
                    StringStruct('FileVersion', '1.0.0.0'),
                    StringStruct('InternalName', 'myapp'),
                    StringStruct('OriginalFilename', 'MyApp.exe'),
                    StringStruct('ProductName', 'My App'),
                    StringStruct('ProductVersion', '1.0.0.0'),
                ])
        ]),
        VarFileInfo([VarStruct('Translation', [1033, 1200])])
    ]
)
```

---

## 4. Handling Data Files and Resources

### The resource_path helper (essential)

When packaged with `--onefile`, PyInstaller extracts to a temp directory. This helper
resolves paths correctly in both development and packaged modes:

```python
import sys
import os

def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller."""
    if getattr(sys, 'frozen', False):
        # Running as packaged exe
        base_path = sys._MEIPASS
    else:
        # Running in development
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

# Usage
icon_path = resource_path("resources/icons/app.ico")
style_path = resource_path("ui/styles/dark_theme.qss")
```

### Adding data files via command line

```bash
# Single file
pyinstaller --add-data "src/config.json;."

# Entire directory
pyinstaller --add-data "src/resources;resources"

# Multiple entries
pyinstaller --add-data "src/resources;resources" --add-data "src/ui/styles;ui/styles"
```

Note: On Windows use `;` as the separator. On Linux/macOS use `:`.

### Using Qt Resource System (alternative)

Instead of bundling loose files, compile resources into a Python module:

```bash
# Create a .qrc file listing your resources
# Then compile it:
pyside6-rcc resources.qrc -o resources_rc.py
```

```xml
<!-- resources.qrc -->
<RCC>
    <qresource prefix="/">
        <file>icons/app.ico</file>
        <file>icons/save.png</file>
        <file>styles/dark_theme.qss</file>
    </qresource>
</RCC>
```

```python
# Then access via Qt resource paths:
import resources_rc  # Import the compiled module
icon = QIcon(":/icons/app.ico")
```

This approach eliminates path issues entirely since resources are embedded in the Python code.

---

## 5. Common Build Issues and Fixes

### "No Qt platform plugin could be initialized"

The most common PyInstaller + Qt error. Causes and fixes:

1. **Multiple Qt installations**: Ensure only one Qt binding is installed
   ```bash
   pip uninstall PySide6 PySide6_Essentials PySide6_Addons PyQt6 -y
   pip install PySide6  # Install only the one you use
   ```

2. **Missing plugins**: Add plugins explicitly
   ```bash
   pyinstaller --add-data "path/to/site-packages/PySide6/plugins;PySide6/plugins"
   ```

3. **Clean rebuild**: Delete `build/`, `dist/`, and `__pycache__/` then rebuild

### Missing modules / ImportError

```bash
# Add hidden imports for modules PyInstaller can't detect
pyinstaller --hidden-import=PySide6.QtSvg --hidden-import=PySide6.QtSvgWidgets
```

Or in the spec file:
```python
hiddenimports=['PySide6.QtSvg', 'PySide6.QtSvgWidgets', 'some_module'],
```

### Reducing build size

PySide6 bundles are large (~150MB+). Reduce with:

```python
# In spec file, exclude unused Qt modules:
excludes=[
    'PySide6.QtWebEngine',
    'PySide6.QtWebEngineCore',
    'PySide6.QtWebEngineWidgets',
    'PySide6.Qt3DCore',
    'PySide6.Qt3DRender',
    'PySide6.QtBluetooth',
    'PySide6.QtNfc',
    'PySide6.QtPositioning',
    'PySide6.QtMultimedia',
    'tkinter',
]
```

Also consider `pip install PySide6-Essentials` instead of full `PySide6` — it excludes
Qt WebEngine, Multimedia, and 3D modules, saving ~50-80MB.

### App crashes silently when packaged

Add a global exception handler to catch and log errors:

```python
import sys
import traceback
from pathlib import Path

def exception_hook(exc_type, exc_value, exc_tb):
    """Log unhandled exceptions to file and show dialog."""
    log_path = Path.home() / "AppData" / "Local" / "MyApp" / "crash.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with open(log_path, "a") as f:
        traceback.print_exception(exc_type, exc_value, exc_tb, file=f)
    # Optionally show error dialog
    sys.__excepthook__(exc_type, exc_value, exc_tb)

sys.excepthook = exception_hook
```

---

## 6. Creating a Windows Installer

### Option A: InstallForge (free, GUI-based)

1. Download InstallForge from https://installforge.net/
2. Create a new project
3. Add all files from `dist/MyApp/`
4. Configure: install path, shortcuts, uninstaller
5. Build the installer

### Option B: Inno Setup (free, script-based)

Create a `.iss` script:

```iss
[Setup]
AppName=My Application
AppVersion=1.0.0
DefaultDirName={autopf}\MyApp
DefaultGroupName=My Application
OutputDir=installer_output
OutputBaseFilename=MyApp_Setup_1.0.0
Compression=lzma2
SolidCompression=yes

[Files]
Source: "dist\MyApp\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\My Application"; Filename: "{app}\MyApp.exe"
Name: "{autodesktop}\My Application"; Filename: "{app}\MyApp.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional"

[Run]
Filename: "{app}\MyApp.exe"; Description: "Launch My Application"; Flags: postinstall nowait
```

Compile: `"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" setup.iss`

### Option C: NSIS (free, script-based)

Another popular option. More complex scripting but very flexible.

---

## 7. Code Signing

Unsigned applications trigger Windows SmartScreen warnings. For distribution:

1. **Obtain a code signing certificate** from a Certificate Authority (DigiCert, Sectigo, etc.)
2. **Sign the .exe** with `signtool`:
   ```bash
   signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 ^
       /f certificate.pfx /p password dist\MyApp\MyApp.exe
   ```
3. **Sign the installer** too — both the .exe and installer should be signed

Without signing, users will see "Windows protected your PC" warnings. For internal tools
distributed within a company, this may be acceptable.

---

## 8. Alternative Packagers

| Tool | Notes |
|------|-------|
| **cx_Freeze** | Cross-platform, good alternative to PyInstaller |
| **Nuitka** | Compiles Python to C — faster execution, smaller builds |
| **briefcase** | Part of BeeWare — creates native packages for each platform |
| **pyside6-deploy** | Official PySide6 deployment tool — simpler but less flexible |
| **fbs** | Build tool specifically for Qt apps — handles packaging + updates |

### Build script template (`scripts/build.bat`)

```batch
@echo off
echo === Building MyApp ===

:: Activate virtual environment
call build_env\Scripts\activate

:: Clean previous builds
rmdir /s /q build 2>nul
rmdir /s /q dist 2>nul

:: Update PyInstaller hooks
pip install --upgrade pyinstaller pyinstaller-hooks-contrib

:: Build
pyinstaller app.spec --clean --noconfirm

:: Verify output
if exist dist\MyApp\MyApp.exe (
    echo === Build successful! ===
    echo Output: dist\MyApp\
) else (
    echo === BUILD FAILED ===
    exit /b 1
)

pause
```
