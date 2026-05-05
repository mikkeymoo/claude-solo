# Python GUI Framework Comparison (2026)

## Table of Contents
1. **Flet** (Flutter-based, modern look default)
2. **NiceGUI** (Web-stack desktop, fantastic for dashboards)
3. PySide6 / PyQt6 (Qt-based — professional commercial apps)
4. customtkinter (modern tkinter)
5. Tkinter (built-in, dated)
6. Dear PyGui (GPU-accelerated)
7. Kivy (cross-platform incl. mobile)
8. PySimpleGUI (⚠️ no longer maintained — avoid for new projects)
9. Licensing Summary
10. Decision Matrix

---

## 1. Flet

**The modern look default for 2026.** Flet wraps Flutter for Python — you write Python, get a beautiful Material 3 UI as a real native desktop app (or web, or mobile, from the same codebase).

- **License**: Apache 2.0 — free for commercial use
- **Install**: `pip install flet`
- **Rendering**: Flutter / Skia (GPU-accelerated, no native widgets)
- **Look**: Material 3 by default; highly themeable; gorgeous animations baked in
- **Maintained by**: AppVeyor Systems Inc. (very active development as of 2026, ships frequently)

### Why choose Flet
- Stunning visual quality out of the box — looks 2026, not 2010
- Single codebase produces desktop (Windows/macOS/Linux), web, mobile (iOS/Android)
- Excellent dark mode, animations, and transitions built in
- Async-first — natural fit for modern Python
- Two packaging options: `flet build` (Flutter-based, fast offline executable) or `flet pack` (PyInstaller wrapper, simpler)
- No Electron-style memory bloat — uses Flutter, not Chromium

### When NOT to use Flet
- When you need pixel-perfect native Windows widgets (use PySide6)
- When you need deep integration with Windows-specific APIs (Qt has more bindings)
- When `flet build` is required and the user can't install Visual Studio's C++ workload (fall back to `flet pack` or pick another framework)

### Example
```python
import flet as ft

def main(page: ft.Page):
    page.title = "My App"
    page.theme_mode = ft.ThemeMode.DARK
    page.theme = ft.Theme(color_scheme_seed=ft.Colors.INDIGO)

    page.add(
        ft.Text("Welcome", size=28, weight=ft.FontWeight.W_600),
        ft.ElevatedButton(
            "Get Started",
            icon=ft.Icons.ROCKET_LAUNCH,
            on_click=lambda e: page.add(ft.Text("Started!")),
        ),
    )

ft.app(target=main)  # Native desktop window
```

---

## 2. NiceGUI

**Web stack, desktop delivery.** Built on FastAPI + Vue + Quasar, but you write only Python. Runs as a real native desktop window via pywebview, OR as a web server you can access from any browser on the network.

- **License**: MIT — most permissive
- **Install**: `pip install "nicegui[native]"` (the `native` extra installs pywebview)
- **Rendering**: Embedded Edge WebView2 on Windows (the same engine that powers VSCode, Teams, etc.)
- **Look**: Quasar/Material default theme + Tailwind-style utility classes for fast styling
- **Maintained by**: Zauberzeug GmbH (very active)

### Why choose NiceGUI
- Best framework on this list for **dashboards, internal tools, and data visualization**
- Built-in components for tables, plots, 3D scenes, file uploads, markdown, charts
- Hot reload during development
- Tailwind utility classes work out of the box (`.classes("text-2xl rounded-2xl")`)
- Same code can be exposed as a real web app on the LAN if you want — flip a flag
- Built-in storage: `app.storage.user`, `app.storage.general`, `app.storage.tab`

### When NOT to use NiceGUI
- For an app that absolutely must look like a native Windows app (it looks like a clean web app — that's intentional but not for everyone)
- When you can't bundle a ~200MB executable (the WebView2 runtime is included)
- For latency-critical desktop interactions (web stack adds overhead vs Qt)

### Example
```python
from nicegui import ui, native

ui.label("Welcome").classes("text-2xl font-semibold")
ui.button("Get Started", on_click=lambda: ui.notify("Started!"))

ui.run(
    native=True,
    reload=False,
    port=native.find_open_port(),
    title="My App",
    window_size=(1000, 700),
    dark=True,
)
```

### Packaging gotcha
When packaging with PyInstaller, you MUST use `--collect-all nicegui`, otherwise the static assets folder is missing at runtime. Use the bundled `nicegui-pack` helper to handle this automatically.

---

## 3. PySide6 / PyQt6

**The professional choice.** Both wrap the Qt6 C++ framework — identical API, different licenses.

### PySide6 (Recommended for new projects)
- **License**: LGPL — free for commercial use, no license fees
- **Maintained by**: The Qt Company (official Python bindings)
- **Install**: `pip install PySide6`

### PyQt6
- **License**: GPL — you must open-source your app OR buy a commercial license from Riverbank Computing
- **Maintained by**: Riverbank Computing
- **Install**: `pip install PyQt6`

### Why choose Qt-based frameworks
- 600+ classes covering widgets, networking, databases, multimedia, 3D, web engine
- Qt Designer — drag-and-drop visual UI builder
- Mature signal/slot system for clean event-driven architecture
- QThread for safe background processing
- QSettings for platform-native persistence (Windows Registry)
- QSS (Qt Style Sheets) for CSS-like theming
- Extensive documentation and large community
- Battle-tested in commercial software (used by Dropbox, Calibre, Spyder, Orange)

### When NOT to use Qt
- For a tiny script that just needs a file picker — overkill
- For mobile-first apps — Qt mobile support exists but isn't mature
- If the install size matters greatly (Qt adds ~80-150MB to packaged apps)

### Porting between PySide6 and PyQt6
The APIs are nearly identical. Main differences:
- Signal definition: `Signal()` (PySide6) vs `pyqtSignal()` (PyQt6)
- Slot decorator: `Slot()` vs `pyqtSlot()`
- Property: `Property()` vs `pyqtProperty()`
- Exec method: both use `.exec()` in Qt6 versions

---

## 4. customtkinter

**Modern-looking tkinter.** A wrapper that replaces tkinter's dated appearance with a
contemporary flat design while keeping the simple API.

- **License**: MIT
- **Install**: `pip install customtkinter`
- **Base**: Built on top of tkinter (ships with Python)
- **Look**: Modern flat widgets with built-in dark/light mode
- **Complexity**: Low — similar API to tkinter but better looking

### Best for
- Internal tools and utilities
- Scripts that need a quick, decent-looking GUI
- Developers who know tkinter but want a modern appearance

### Limitations
- Fewer widget types than Qt
- Limited customization compared to QSS
- No built-in networking, database, or multimedia modules
- Smaller community than Qt

### Example
```python
import customtkinter as ctk

app = ctk.CTk()
app.title("My Tool")
app.geometry("600x400")
ctk.set_appearance_mode("dark")

label = ctk.CTkLabel(app, text="Hello!")
label.pack(padx=20, pady=20)

button = ctk.CTkButton(app, text="Click Me", command=lambda: print("Clicked"))
button.pack(padx=20, pady=10)

app.mainloop()
```

---

## 5. Tkinter

**The built-in option.** Ships with Python — zero additional installs.

- **License**: Part of Python (PSF License)
- **Install**: None needed (bundled with Python on Windows/macOS)
- **Look**: Dated by default but can use `ttk` themed widgets

### Best for
- Learning GUI programming
- Tiny utilities where you want zero dependencies
- Educational projects

### Limitations
- Looks outdated without significant styling effort
- Limited widget set
- No signals/slots — uses command callbacks and StringVar/IntVar
- Threading is more manual (use `threading` + `after()` for safe updates)
- No built-in support for modern UI patterns

### Threading pattern for tkinter
```python
import threading

def long_task():
    result = heavy_work()
    # Schedule GUI update on main thread
    root.after(0, lambda: update_gui(result))

thread = threading.Thread(target=long_task, daemon=True)
thread.start()
```

---

## 6. Dear PyGui

**GPU-accelerated immediate-mode GUI.** Built on Dear ImGui, renders via DirectX/OpenGL.

- **License**: MIT
- **Install**: `pip install dearpygui`
- **Rendering**: DirectX 11 (Windows), OpenGL (Linux/macOS)
- **Paradigm**: Immediate mode — different from retained-mode Qt/tkinter

### Best for
- Real-time data visualization dashboards
- Debug/development tools
- Applications that need 60fps UI updates
- Scientific/engineering tools with live plots

### Limitations
- Different mental model (immediate vs retained mode)
- Smaller ecosystem than Qt
- Less conventional for standard business apps
- Fewer native OS integration features

### Example
```python
import dearpygui.dearpygui as dpg

dpg.create_context()
dpg.create_viewport(title="My App", width=800, height=600)

with dpg.window(label="Main", tag="primary"):
    dpg.add_text("Hello, Dear PyGui!")
    dpg.add_button(label="Click Me", callback=lambda: print("Clicked"))
    dpg.add_slider_float(label="Value", default_value=0.5)

dpg.setup_dearpygui()
dpg.show_viewport()
dpg.set_primary_window("primary", True)
dpg.start_dearpygui()
dpg.destroy_context()
```

---

## 7. Kivy

**Cross-platform with mobile support.** Best if you need Android/iOS deployment.

- **License**: MIT
- **Install**: `pip install kivy`
- **Rendering**: OpenGL ES 2 — custom rendering, not native widgets
- **Unique**: Supports multi-touch, gestures, mobile deployment

### Best for
- Apps targeting mobile (Android/iOS) AND desktop
- Touch-based kiosk applications
- Games and interactive applications

### Limitations
- Doesn't look native on any platform (custom rendering)
- Different layout system from other frameworks
- Steeper learning curve for its KV language
- Not ideal for traditional Windows business applications

---

---

## 8. PySimpleGUI ⚠️ Deprecated for new projects

**No longer actively maintained as of 2026 — do not use for new projects.** The project went through a paid-license model and active development has stalled.

If you're maintaining an existing PySimpleGUI app, fine — but for anything new, pick:
- **Flet** if you want simple-but-modern
- **NiceGUI** if you want simple-but-data-friendly
- **CustomTkinter** if you want simple-and-tkinter-based

---

## Licensing Summary

| Framework | License | Commercial Use |
|-----------|---------|---------------|
| **Flet** | Apache 2.0 | ✅ Free |
| **NiceGUI** | MIT | ✅ Free |
| PySide6 | LGPL | ✅ Free |
| PyQt6 | GPL | ⚠️ Must open-source OR buy license |
| customtkinter | MIT | ✅ Free |
| Tkinter | PSF | ✅ Free |
| Dear PyGui | MIT | ✅ Free |
| Kivy | MIT | ✅ Free |
| ~~PySimpleGUI~~ | LGPL | ⚠️ Deprecated — avoid for new projects |

---

## Decision Matrix

When the user describes what they want, map to a framework:

| User goal | Pick |
|-----------|------|
| "I want a beautiful modern app" | **Flet** |
| "I need a dashboard / data tool / internal app" | **NiceGUI** |
| "I'm building a real commercial Windows desktop app" | **PySide6** |
| "Just a quick utility, modern look" | **CustomTkinter** |
| "Something tiny, no dependencies" | **tkinter** |
| "Real-time charts at 60fps" | **Dear PyGui** |
| "Same app on desktop AND mobile" | **Flet** (or Kivy if heavy multitouch) |
| "Tablet/touch kiosk on Android" | **Kivy** |

**Default recommendation when unspecified: Flet for greenfield modern apps, PySide6 for commercial desktop apps with native polish.**
