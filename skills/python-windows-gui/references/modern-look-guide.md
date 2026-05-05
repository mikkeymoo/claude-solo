# Modern Look & Feel Guide for Python GUIs (2026)

This guide is what makes a Python desktop app look like 2026 instead of 2010. It's framework-agnostic — apply the same principles whether you're using PySide6, CustomTkinter, Flet, or NiceGUI.

> **Important:** "Modern look" does not require Flet. **PySide6 with a thoughtful QSS theme produces UIs every bit as polished as Flet or Electron-based apps.** The QSS theme in section 10c below gets you there in ~200 lines. The "default appearance" gap is real but closeable — and PySide6's stability and maturity make it the right choice for production work.

## Table of Contents
1. The Five Rules of Looking Modern
2. Color Systems and Dark Mode
3. Typography
4. Spacing, Radius, and Layout
5. Iconography
6. Motion and Animation
7. Surfaces and Elevation
8. Inputs and Controls
9. Accessibility
10. Framework Cookbooks

---

## 1. The Five Rules of Looking Modern

If you only remember five things, remember these:

1. **Dark mode by default.** Light mode is fine, but a sleek dark mode is the single biggest perceived-quality win. Always provide both.
2. **Use a real type system.** Two or three font sizes with deliberate weights beat a dozen random sizes every time.
3. **Generous spacing and rounded corners.** Tight 4-pixel padding and 0px corners scream "Win95." Use 12-24px padding and 8-16px border radius.
4. **One accent color, used sparingly.** Pick one brand/accent color and use neutral grays for 90% of the surface. Saturation everywhere = visual noise.
5. **Subtle motion, never jittery.** 150-250ms ease-out transitions on hover, focus, and state changes. Never bounce, never flash.

---

## 2. Color Systems and Dark Mode

### Modern Color Tokens

Don't hardcode hex values across your codebase. Define semantic tokens once:

```python
# colors.py
class DarkTheme:
    bg          = "#0F1115"   # Page background
    surface     = "#1A1D24"   # Cards, panels
    surface_alt = "#22262F"   # Hover states, secondary surfaces
    border      = "#2A2F3A"   # Subtle dividers
    text        = "#E6E8EC"   # Primary text
    text_muted  = "#9099A8"   # Secondary text, captions
    accent      = "#6366F1"   # Indigo primary action
    accent_hov  = "#7C7FFF"   # Hover state for accent
    success     = "#10B981"
    warning     = "#F59E0B"
    danger      = "#EF4444"

class LightTheme:
    bg          = "#FAFBFC"
    surface     = "#FFFFFF"
    surface_alt = "#F4F5F7"
    border      = "#E4E6EB"
    text        = "#0F1115"
    text_muted  = "#5A6373"
    accent      = "#4F46E5"
    accent_hov  = "#4338CA"
    success     = "#059669"
    warning     = "#D97706"
    danger      = "#DC2626"
```

### Recommended Palettes

These are battle-tested 2026 palettes. Pick ONE accent and stick with it:

| Vibe | Accent | Hover | Background (dark) |
|------|--------|-------|-------------------|
| **Modern Indigo** (default) | `#6366F1` | `#7C7FFF` | `#0F1115` |
| **Slack/Linear Purple** | `#7C3AED` | `#9359F0` | `#0E0E12` |
| **Stripe Blue** | `#635BFF` | `#7B73FF` | `#0A0E27` |
| **Vercel/GitHub Mono** | `#FFFFFF` | `#E6E8EC` | `#000000` |
| **Notion Soft** | `#2383E2` | `#3B95E5` | `#191919` |
| **Morae Brand** | (load `morae-brand` skill) | — | — |

### Dark Mode Done Right

- **Don't use pure black** (`#000`) for backgrounds. It looks harsh and OLED-y. Use `#0F1115`–`#1A1D24` for "dark slate."
- **Don't use pure white** for dark-mode text. Use `#E6E8EC` to reduce eye strain.
- **Lift surfaces, don't pile lines.** In dark mode, distinguish layers with brighter surface colors, not visible borders. (Borders should be very subtle: `rgba(255,255,255,0.06)` or a slightly lighter gray than the surface.)
- **Respect user preference.** Detect OS theme on startup and offer a manual toggle. On Windows: `winreg.OpenKey(HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize")` → check `AppsUseLightTheme`.

---

## 3. Typography

### Font Stack

| Platform | First choice | Fallback |
|----------|--------------|----------|
| **Windows 11** | **Segoe UI Variable** | Segoe UI, system-ui |
| **Cross-platform** | **Inter** | Segoe UI, -apple-system |
| **Monospace (code, IDs)** | **JetBrains Mono** | Cascadia Code, Consolas |

Inter is the strongest cross-platform choice for 2026 — clean, neutral, designed for screens. Bundle it as a TTF in `resources/fonts/` and load it at startup. Segoe UI Variable is excellent on Windows 11 specifically and is already installed.

### Type Scale (Use This)

A simple modular scale beats picking sizes ad hoc:

| Token | Size | Weight | Use |
|-------|------|--------|-----|
| `display` | 32 | 700 | Hero headings, splash |
| `title` | 24 | 600 | Page titles |
| `heading` | 18 | 600 | Section headings |
| `body` | 14 | 400 | Default text |
| `body_strong` | 14 | 600 | Emphasized body text |
| `caption` | 12 | 400 | Secondary, captions, helper text |
| `mono` | 13 | 400 | IDs, code, numbers in tables |

**Rules:**
- Maximum 3 font sizes on a single screen
- Never use `italic` for emphasis — use weight (`600`) instead
- Line height: `1.5` for body, `1.25` for headings
- Letter spacing: tighten headings slightly (`-0.01em`), leave body alone

---

## 4. Spacing, Radius, and Layout

### 4-Point Spacing Scale

Pick spacing values from a fixed scale. This single rule eliminates 80% of "off" layouts:

```
4, 8, 12, 16, 24, 32, 48, 64
```

- Tight inline spacing (icons next to text): **4-8**
- Padding inside cards/buttons: **12-16**
- Gaps between sibling elements: **16-24**
- Section breaks: **32-48**
- Page margins: **24-32** (mobile) / **48-64** (desktop)

### Border Radius

Modern apps lean into rounded corners. Pick a system:

| Element | Radius |
|---------|--------|
| Buttons, chips, inputs | **8-10px** |
| Cards, panels | **12-16px** |
| Modal dialogs | **16-20px** |
| Avatars, status dots | **999px** (full circle) |

### Layout Containers

- **Don't center everything.** Use a sidebar + content layout for any app with more than one view.
- **Max content width.** Even on a 4K monitor, primary text content should cap at ~720-960px wide for readability. Use a padded centered container.
- **Density modes.** For dashboards, offer a "compact" mode that reduces padding by ~25%.

---

## 5. Iconography

**Don't ship emoji or system fontello icons.** They look amateur. Use one of these icon systems:

| Icon set | Why use it | Install |
|----------|------------|---------|
| **Lucide** | Clean, consistent, 1400+ icons, MIT | NiceGUI: built into Quasar; PySide6: download SVGs; Flet: use Material icons |
| **Material Symbols** | Google's modern icon set, variable weight | Built into Flet (`ft.Icons.*`); NiceGUI via Quasar |
| **Phosphor** | Friendly, six weights (thin/light/regular/bold/fill/duotone) | Download SVGs; great for distinctive branding |
| **Heroicons** | Tailwind's icon set, outline + solid variants | Download SVGs; great for solid/outline pairing |

**Rules:**
- Pick ONE icon set and stick with it across the entire app
- Use a consistent stroke width (typically 1.5-2px for outline icons)
- Icon size should match adjacent text height (16px next to 14px text, 20px next to 18px text)
- For interactive icons (buttons), give them a 36-40px hit target even if the icon is 16px

---

## 6. Motion and Animation

Motion turns a static UI into a living one. Done badly, it's nausea-inducing. Done well, it's invisible.

### The Three Durations

| Duration | Use |
|----------|-----|
| **100-150ms** | Hover state changes, button press feedback |
| **200-250ms** | Modal/dialog open, drawer slide, tab switch |
| **300-400ms** | Page transitions, large layout changes |

### The One Easing

Use **ease-out** (`cubic-bezier(0.16, 1, 0.3, 1)`) for almost everything — it feels "reactive." Only use ease-in for elements leaving the screen. Never use `linear` for UI transitions; never use `ease-in-out` unless you specifically need symmetry.

### What to Animate

✅ Opacity (fade in/out)
✅ Transform (translate, scale)
✅ Background color on hover

❌ Width/height (causes reflow, janky)
❌ Top/left/right/bottom (use `transform: translate` instead)
❌ Anything bouncy by default — bounces feel toy-like in productivity tools

### Framework-specific:
- **Flet:** `ft.Container(animate=ft.Animation(200, ft.AnimationCurve.EASE_OUT))`
- **NiceGUI:** Tailwind's `transition-all duration-200 ease-out` classes
- **PySide6:** `QPropertyAnimation` with `QEasingCurve.OutQuad` or `OutCubic`

---

## 7. Surfaces and Elevation

Modern apps use elevation (shadow) sparingly to suggest hierarchy.

### Shadow Tokens

```python
# Light mode shadows
shadow_sm = "0 1px 2px rgba(0,0,0,0.04), 0 1px 3px rgba(0,0,0,0.06)"
shadow_md = "0 4px 6px rgba(0,0,0,0.05), 0 10px 15px rgba(0,0,0,0.08)"
shadow_lg = "0 10px 25px rgba(0,0,0,0.10), 0 20px 50px rgba(0,0,0,0.12)"

# Dark mode — shadows mostly invisible; use brighter surface colors instead
# But for hovering modals, still use a strong shadow:
shadow_dark_modal = "0 25px 50px rgba(0,0,0,0.5)"
```

### When to Elevate

- **Cards on a page:** No shadow (or very subtle `shadow_sm`)
- **Hover state on a card:** `shadow_md`
- **Dropdowns and menus:** `shadow_md`
- **Modal dialogs:** `shadow_lg` + a backdrop overlay
- **Toasts/notifications:** `shadow_lg`

Don't shadow buttons, inputs, or list items by default. They should be flat.

---

## 8. Inputs and Controls

### Buttons

Three button variants cover 95% of cases:

| Variant | Use | Style |
|---------|-----|-------|
| **Primary** | One per screen, the main action | Filled with accent color, white text |
| **Secondary** | Other actions | Outlined or subtle background |
| **Ghost / Tertiary** | Cancel, less important actions | Text-only with hover background |

**Sizing:** 36-40px height for default, 44-48px for primary/important actions. Padding `12px 20px` minimum.

### Text Inputs

- Height: 36-40px
- Padding: `8px 12px`
- Border: 1px solid (subtle)
- Border on focus: 2px solid accent color (or 1px + outer ring)
- Border radius: matches button radius (8-10px)
- Placeholder color: muted text token, not the same as real text
- Show validation errors **below** the input in `danger` color, with an icon

### Checkboxes and Toggles

- Use **toggles/switches** for instant-apply settings (like dark mode)
- Use **checkboxes** for "select multiple" lists or form fields that submit later
- Animate the toggle thumb sliding (150ms ease-out)

---

## 9. Accessibility

Modern means accessible. These are not optional.

- **Contrast:** WCAG AA minimum (4.5:1 for body text, 3:1 for large text). Test at https://webaim.org/resources/contrastchecker/
- **Keyboard navigation:** Every interactive element must be reachable via Tab; show a clear focus ring (2px outline in accent color).
- **Click targets:** 40x40px minimum, even for icon-only buttons. Never make a 16px X icon the click target.
- **Screen reader labels:** Set accessible names on icon-only buttons. PySide6: `setAccessibleName(...)`. Flet: `tooltip="..."`. NiceGUI: `aria-label`.
- **Reduced motion:** Respect `prefers-reduced-motion` (NiceGUI/Flet inherit this from the OS via web/Flutter).
- **Don't rely on color alone:** Pair color with icons or text for status (e.g., green checkmark, not just green text).

---

## 10. Framework Cookbooks

### PySide6 — Modern QSS Theme

Save this as `styles/dark.qss` and load with `app.setStyleSheet(...)`:

```css
* {
    font-family: "Segoe UI Variable", "Inter", "Segoe UI", sans-serif;
    font-size: 14px;
    color: #E6E8EC;
}

QMainWindow, QDialog {
    background-color: #0F1115;
}

QWidget {
    background-color: transparent;
}

/* Cards / panels */
QFrame[role="card"] {
    background-color: #1A1D24;
    border: 1px solid #2A2F3A;
    border-radius: 12px;
    padding: 16px;
}

/* Primary button */
QPushButton[role="primary"] {
    background-color: #6366F1;
    color: white;
    border: none;
    border-radius: 8px;
    padding: 10px 20px;
    font-weight: 600;
}
QPushButton[role="primary"]:hover { background-color: #7C7FFF; }
QPushButton[role="primary"]:pressed { background-color: #4F46E5; }
QPushButton[role="primary"]:disabled { background-color: #2A2F3A; color: #5A6373; }

/* Secondary button */
QPushButton {
    background-color: #22262F;
    color: #E6E8EC;
    border: 1px solid #2A2F3A;
    border-radius: 8px;
    padding: 10px 20px;
}
QPushButton:hover { background-color: #2A2F3A; }

/* Inputs */
QLineEdit, QTextEdit, QPlainTextEdit, QComboBox, QSpinBox {
    background-color: #1A1D24;
    border: 1px solid #2A2F3A;
    border-radius: 8px;
    padding: 8px 12px;
    selection-background-color: #6366F1;
}
QLineEdit:focus, QTextEdit:focus, QComboBox:focus {
    border: 2px solid #6366F1;
    padding: 7px 11px;
}

/* Tab bar */
QTabBar::tab {
    background-color: transparent;
    color: #9099A8;
    padding: 8px 16px;
    border: none;
}
QTabBar::tab:selected {
    color: #E6E8EC;
    border-bottom: 2px solid #6366F1;
}

/* Scrollbars - subtle */
QScrollBar:vertical {
    background: transparent;
    width: 10px;
}
QScrollBar::handle:vertical {
    background: #2A2F3A;
    border-radius: 5px;
    min-height: 30px;
}
QScrollBar::handle:vertical:hover { background: #3A4050; }
QScrollBar::add-line, QScrollBar::sub-line { height: 0; }
```

### CustomTkinter — Modern Setup

```python
import customtkinter as ctk

ctk.set_appearance_mode("dark")     # "system" / "light" / "dark"
ctk.set_default_color_theme("blue") # blue / green / dark-blue, or path to .json

app = ctk.CTk()
app.title("My App")
app.geometry("1000x700")

frame = ctk.CTkFrame(app, corner_radius=16)
frame.pack(padx=24, pady=24, fill="both", expand=True)

ctk.CTkLabel(
    frame,
    text="Welcome",
    font=ctk.CTkFont(family="Segoe UI Variable", size=24, weight="bold"),
).pack(pady=(20, 4), padx=20, anchor="w")

ctk.CTkButton(
    frame,
    text="Get Started",
    corner_radius=10,
    height=40,
).pack(pady=20, padx=20, anchor="w")

app.mainloop()
```

### Flet — Modern Theme Setup

```python
import flet as ft

def main(page: ft.Page):
    # Theme
    page.theme_mode = ft.ThemeMode.DARK
    page.theme = ft.Theme(
        color_scheme_seed=ft.Colors.INDIGO,
        font_family="Inter",
        visual_density=ft.VisualDensity.COMFORTABLE,
    )

    # Bundle Inter font
    page.fonts = {
        "Inter": "fonts/Inter-Regular.ttf",
        "Inter Bold": "fonts/Inter-Bold.ttf",
    }

    # Window
    page.window.width = 1200
    page.window.height = 800
    page.window.min_width = 800
    page.window.min_height = 600
    page.window.title_bar_hidden = False  # set True for fully custom chrome
    page.padding = 0

    # Modern card example
    card = ft.Container(
        content=ft.Column([
            ft.Text("Quick Stats", size=18, weight=ft.FontWeight.W_600),
            ft.Text("Updated 2 minutes ago", size=12, color=ft.Colors.with_opacity(0.6, ft.Colors.ON_SURFACE)),
        ], spacing=4),
        padding=20,
        border_radius=16,
        bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH,
        animate=ft.Animation(200, ft.AnimationCurve.EASE_OUT),
    )
    page.add(card)

ft.app(target=main, assets_dir="assets")
```

### NiceGUI — Modern Theme Setup

```python
from nicegui import ui, native, app

# Custom Tailwind colors via Quasar
ui.colors(primary="#6366F1", secondary="#22262F", accent="#7C7FFF")

# Global styles
ui.add_head_html("""
<link href="https://rsms.me/inter/inter.css" rel="stylesheet">
<style>
  body { font-family: 'Inter', system-ui, sans-serif; }
</style>
""")

# Modern card
with ui.card().classes("w-96 p-6 rounded-2xl shadow-lg"):
    ui.label("Quick Stats").classes("text-lg font-semibold")
    ui.label("Updated 2 minutes ago").classes("text-sm text-gray-500")

ui.run(
    native=True,
    reload=False,
    port=native.find_open_port(),
    title="My App",
    window_size=(1200, 800),
    dark=True,
)
```

---

## Quick Self-Check

Before shipping any UI, ask:

1. ☐ Does it have a real dark mode (or thoughtful light-only)?
2. ☐ Are there at most 3 font sizes on screen?
3. ☐ Do all corners follow the same radius system?
4. ☐ Is one accent color used sparingly (not 5 colors competing)?
5. ☐ Do hover and focus states have a 150ms transition?
6. ☐ Are click targets at least 40x40px?
7. ☐ Does keyboard Tab navigation work and show a focus ring?
8. ☐ Are icons from a single icon set?
9. ☐ Is content padding at least 16px from container edges?
10. ☐ Does the app use Inter or Segoe UI Variable, not the default font?

If you can check all 10, your app looks 2026.
