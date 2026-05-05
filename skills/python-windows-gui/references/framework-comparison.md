# Python GUI Framework Comparison (2026)

## Table of Contents
1. **PySide6 / PyQt6** (Qt-based — the production best-practices default)
2. **CustomTkinter** (modern flat tkinter — quick utilities)
3. **Tkinter** (built-in, dated)
4. **Dear PyGui** (GPU-accelerated)
5. **Flet** (Flutter-based, pre-1.0, modern look default)
6. **NiceGUI** (web-stack desktop, dashboards)
7. **Kivy** (cross-platform incl. mobile)
8. **PySimpleGUI** (⚠️ no longer maintained — avoid for new projects)
9. Licensing Summary
10. Decision Matrix

## TL;DR

**For production Windows desktop apps, the default best-practices choice is PySide6.** It's mature (17+ years), officially developed by The Qt Company, classified Production/Stable, used by Spotify/Dropbox/Calibre, and has a permissive LGPL license.

Choose differently only when the trade-offs match the use case:
- **CustomTkinter** for quick utilities where Qt feels heavy
- **Flet** for cross-platform single-codebase apps OR when you specifically want Material 3 defaults — but accept the pre-1.0 stability cost
- **NiceGUI** for dashboards/data tools where web-style UI is fine
- **Dear PyGui** for realtime/GPU-accelerated viz

---

## 1. PySide6 / PyQt6

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

## 2. customtkinter

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

## 3. Tkinter

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

## 4. Dear PyGui

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

## 5. Flet

**Pre-1.0 modern-look framework.** Flet wraps Flutter for Python — you write Python, get a beautiful Material 3 UI as a real native desktop app (or web, or mobile, from the same codebase). Currently version 0.84 (April 2026); the team is working toward a 1.0 with API stability guarantees.

- **License**: Apache 2.0 — free for commercial use
- **Install**: `pip install flet`
- **Rendering**: Flutter / Skia (GPU-accelerated, no native widgets)
- **Look**: Material 3 by default; highly themeable; animations baked in
- **Maintained by**: AppVeyor Systems Inc. (very active, ships frequently)
- **Stability**: Pre-1.0 — APIs still evolving between releases; not yet a "best practices" default for production
- **GitHub**: ~15K stars (very popular, real momentum)

### Why choose Flet
- Stunning visual quality out of the box — looks 2026, not 2010
- Single codebase produces desktop (Windows/macOS/Linux), web, mobile (iOS/Android)
- Excellent dark mode, animations, and transitions built in
- Async-first — natural fit for modern Python
- Two packaging options: `flet build` (Flutter-based, fast offline executable) or `flet pack` (PyInstaller wrapper, simpler)
- No Electron-style memory bloat — uses Flutter, not Chromium

### Real-world trade-offs (be honest with the user about these)
- **Pre-1.0 instability** — APIs change between minor versions. Acceptable for prototypes and internal tools; risky for multi-year production code.
- **Architecture is a Python↔Flutter bridge** — UI events are messages over a local protocol, not direct widget calls. Adds latency and event chatter for UI-heavy apps with frequent state changes.
- **Split-brain debugging** — Flutter DevTools doesn't see Python; Python debuggers don't see Flutter rendering.
- **Non-native widgets** — Flutter renders its own widgets via Skia. Looks great, but doesn't pixel-match Windows 11 system widgets.
- **For pixel-perfect native Windows feel, deep Win32 API integration, or guaranteed long-term API stability — use PySide6 instead.**

### Best for
- Internal tools where time-to-first-UI matters
- Cross-platform projects that genuinely need desktop+web+mobile from one codebase
- Prototypes and design explorations
- Apps where Material 3 default look is desirable

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

## 6. NiceGUI

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
| **Production Windows desktop app** (default) | **PySide6** |
| "I'm building a real commercial Windows desktop app" | **PySide6** |
| "I need a dashboard / data tool / internal app" | **NiceGUI** |
| "Just a quick utility, modern look" | **CustomTkinter** |
| "Something tiny, no dependencies" | **tkinter** |
| "Real-time charts at 60fps" | **Dear PyGui** |
| "I want a beautiful modern app" + accepts pre-1.0 | **Flet** (or PySide6 with QSS theme for stable choice) |
| "Same app on desktop AND mobile" | **Flet** (or Kivy if heavy multitouch) |
| "Tablet/touch kiosk on Android" | **Kivy** |

**Default recommendation when the user hasn't specified preferences: PySide6.** It's the mature, stable, production-ready choice that covers the vast majority of Windows desktop app needs. The "default modern look" advantage of Flet/NiceGUI is real but not enough on its own to outweigh PySide6's stability for production work — and a thoughtful QSS theme (see `modern-look-guide.md`) brings PySide6's appearance fully up to 2026 standards.
