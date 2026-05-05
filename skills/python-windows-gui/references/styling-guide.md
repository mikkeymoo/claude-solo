# Styling Guide — QSS Theming for Windows GUI Apps

## Table of Contents
1. QSS Basics
2. Dark Theme Template
3. Light Theme Template
4. Widget-Specific Styling
5. System-Aware Theming
6. Custom Fonts and Icons
7. Tips and Best Practices

---

## 1. QSS Basics

Qt Style Sheets (QSS) work like CSS for Qt widgets. Apply them at the application level
for global theming or per-widget for targeted styling.

**Loading a QSS file (preferred approach):**

```python
import sys
from pathlib import Path

def load_stylesheet(app, theme="dark"):
    qss_path = Path(__file__).parent / "styles" / f"{theme}_theme.qss"
    if qss_path.exists():
        app.setStyleSheet(qss_path.read_text())
```

**QSS selector types:**

```css
/* Type selector — all QPushButtons */
QPushButton { background-color: #3498db; }

/* ID selector — widget with objectName "saveBtn" */
#saveBtn { font-weight: bold; }

/* Class selector — only exact QLabel, not subclasses */
.QLabel { color: #333; }

/* Descendant — QLabel inside QGroupBox */
QGroupBox QLabel { font-size: 12px; }

/* Pseudo-states */
QPushButton:hover { background-color: #2980b9; }
QPushButton:pressed { background-color: #1a6fa3; }
QPushButton:disabled { background-color: #7f8c8d; }
```

---

## 2. Dark Theme Template

Save as `styles/dark_theme.qss`:

```css
/* === GLOBAL === */
QWidget {
    background-color: #1e1e2e;
    color: #cdd6f4;
    font-family: "Segoe UI";
    font-size: 10pt;
}

/* === MAIN WINDOW === */
QMainWindow {
    background-color: #1e1e2e;
}

QMenuBar {
    background-color: #181825;
    color: #cdd6f4;
    border-bottom: 1px solid #313244;
}

QMenuBar::item:selected {
    background-color: #313244;
}

QMenu {
    background-color: #1e1e2e;
    border: 1px solid #313244;
}

QMenu::item:selected {
    background-color: #45475a;
}

QStatusBar {
    background-color: #181825;
    color: #a6adc8;
    border-top: 1px solid #313244;
}

/* === BUTTONS === */
QPushButton {
    background-color: #89b4fa;
    color: #1e1e2e;
    border: none;
    border-radius: 6px;
    padding: 8px 16px;
    font-weight: bold;
    min-height: 20px;
}

QPushButton:hover {
    background-color: #74c7ec;
}

QPushButton:pressed {
    background-color: #89dceb;
}

QPushButton:disabled {
    background-color: #45475a;
    color: #6c7086;
}

/* === INPUT FIELDS === */
QLineEdit, QTextEdit, QPlainTextEdit, QSpinBox, QDoubleSpinBox {
    background-color: #313244;
    color: #cdd6f4;
    border: 2px solid #45475a;
    border-radius: 6px;
    padding: 6px 10px;
    selection-background-color: #89b4fa;
    selection-color: #1e1e2e;
}

QLineEdit:focus, QTextEdit:focus, QPlainTextEdit:focus {
    border-color: #89b4fa;
}

/* === COMBO BOX === */
QComboBox {
    background-color: #313244;
    color: #cdd6f4;
    border: 2px solid #45475a;
    border-radius: 6px;
    padding: 6px 10px;
    min-height: 20px;
}

QComboBox::drop-down {
    border: none;
    width: 30px;
}

QComboBox QAbstractItemView {
    background-color: #1e1e2e;
    color: #cdd6f4;
    selection-background-color: #45475a;
    border: 1px solid #313244;
}

/* === TABLES === */
QTableView, QTableWidget {
    background-color: #1e1e2e;
    alternate-background-color: #181825;
    color: #cdd6f4;
    gridline-color: #313244;
    border: 1px solid #313244;
    border-radius: 6px;
    selection-background-color: #45475a;
}

QHeaderView::section {
    background-color: #181825;
    color: #cdd6f4;
    padding: 8px;
    border: none;
    border-bottom: 2px solid #313244;
    font-weight: bold;
}

/* === TABS === */
QTabWidget::pane {
    border: 1px solid #313244;
    border-radius: 6px;
    background-color: #1e1e2e;
}

QTabBar::tab {
    background-color: #181825;
    color: #a6adc8;
    padding: 8px 16px;
    border-top-left-radius: 6px;
    border-top-right-radius: 6px;
    margin-right: 2px;
}

QTabBar::tab:selected {
    background-color: #1e1e2e;
    color: #cdd6f4;
    border-bottom: 2px solid #89b4fa;
}

/* === SCROLLBARS === */
QScrollBar:vertical {
    background-color: #1e1e2e;
    width: 12px;
    border-radius: 6px;
}

QScrollBar::handle:vertical {
    background-color: #45475a;
    border-radius: 6px;
    min-height: 30px;
}

QScrollBar::handle:vertical:hover {
    background-color: #585b70;
}

QScrollBar::add-line, QScrollBar::sub-line {
    height: 0px;
}

/* === PROGRESS BAR === */
QProgressBar {
    background-color: #313244;
    border-radius: 6px;
    text-align: center;
    color: #cdd6f4;
    min-height: 20px;
}

QProgressBar::chunk {
    background-color: #89b4fa;
    border-radius: 6px;
}

/* === GROUP BOX === */
QGroupBox {
    border: 1px solid #313244;
    border-radius: 6px;
    margin-top: 12px;
    padding-top: 12px;
    font-weight: bold;
}

QGroupBox::title {
    subcontrol-origin: margin;
    left: 12px;
    padding: 0 6px;
}

/* === TOOLTIPS === */
QToolTip {
    background-color: #313244;
    color: #cdd6f4;
    border: 1px solid #45475a;
    border-radius: 4px;
    padding: 4px 8px;
}
```

---

## 3. Light Theme Template

Save as `styles/light_theme.qss` — follow the same structure with light colors:

```css
QWidget {
    background-color: #eff1f5;
    color: #4c4f69;
    font-family: "Segoe UI";
    font-size: 10pt;
}

QPushButton {
    background-color: #1e66f5;
    color: #ffffff;
    border: none;
    border-radius: 6px;
    padding: 8px 16px;
    font-weight: bold;
}

QPushButton:hover { background-color: #2a6ff7; }
QPushButton:pressed { background-color: #1558d8; }

QLineEdit, QTextEdit, QPlainTextEdit {
    background-color: #ffffff;
    color: #4c4f69;
    border: 2px solid #ccd0da;
    border-radius: 6px;
    padding: 6px 10px;
}

QLineEdit:focus { border-color: #1e66f5; }

/* Continue with the same pattern as dark theme using light palette */
```

---

## 4. Widget-Specific Styling

### Flat/borderless buttons
```css
QPushButton#flatButton {
    background-color: transparent;
    color: #89b4fa;
    border: none;
}
QPushButton#flatButton:hover {
    background-color: rgba(137, 180, 250, 0.1);
    border-radius: 4px;
}
```

### Danger/destructive buttons
```css
QPushButton#dangerBtn {
    background-color: #f38ba8;
    color: #1e1e2e;
}
QPushButton#dangerBtn:hover {
    background-color: #eba0ac;
}
```

### Rounded avatar/icon labels
```css
QLabel#avatar {
    border-radius: 25px;  /* half of width/height for circle */
    border: 2px solid #89b4fa;
}
```

Use `setObjectName("flatButton")` in Python to target specific widgets by ID.

---

## 5. System-Aware Theming

Detect the Windows system theme and respond accordingly:

```python
from PySide6.QtWidgets import QApplication
from PySide6.QtGui import QPalette
import darkdetect  # pip install darkdetect

def apply_system_theme(app):
    """Apply theme matching the Windows system setting."""
    if darkdetect.isDark():
        load_stylesheet(app, "dark")
    else:
        load_stylesheet(app, "light")

# For dynamic theme switching (watches for system changes):
# Use darkdetect.listener() in a background thread
```

Alternatively, use `QPalette` for a purely Qt-native approach without external themes:

```python
from PySide6.QtGui import QPalette, QColor
from PySide6.QtCore import Qt

def set_dark_palette(app):
    palette = QPalette()
    palette.setColor(QPalette.Window, QColor(30, 30, 46))
    palette.setColor(QPalette.WindowText, QColor(205, 214, 244))
    palette.setColor(QPalette.Base, QColor(49, 50, 68))
    palette.setColor(QPalette.AlternateBase, QColor(24, 24, 37))
    palette.setColor(QPalette.Text, QColor(205, 214, 244))
    palette.setColor(QPalette.Button, QColor(69, 71, 90))
    palette.setColor(QPalette.ButtonText, QColor(205, 214, 244))
    palette.setColor(QPalette.Highlight, QColor(137, 180, 250))
    palette.setColor(QPalette.HighlightedText, QColor(30, 30, 46))
    app.setPalette(palette)
```

---

## 6. Custom Fonts and Icons

### Loading custom fonts
```python
from PySide6.QtGui import QFontDatabase, QFont

font_id = QFontDatabase.addApplicationFont("resources/fonts/Inter-Regular.ttf")
if font_id != -1:
    families = QFontDatabase.applicationFontFamilies(font_id)
    app.setFont(QFont(families[0], 10))
```

### Using system icons
```python
from PySide6.QtWidgets import QStyle

# Access platform-native icons
save_icon = self.style().standardIcon(QStyle.SP_DialogSaveButton)
open_icon = self.style().standardIcon(QStyle.SP_DialogOpenButton)
```

### Using icon libraries (recommended: qtawesome)
```python
# pip install qtawesome
import qtawesome as qta

icon = qta.icon("fa5s.save", color="#89b4fa")
button.setIcon(icon)
```

---

## 7. Tips and Best Practices

1. **Keep QSS in separate files** — Don't scatter `setStyleSheet()` calls across your code.
   Load one global stylesheet at app startup.

2. **Use objectName for targeted styling** — Set `widget.setObjectName("myWidget")` and
   target with `#myWidget` in QSS.

3. **Don't over-style** — Let the platform handle things where native behavior is expected
   (scrollbar behavior, focus rings, etc.).

4. **Test both themes** — If you support dark/light, test every screen in both modes.

5. **Use consistent spacing** — Pick a spacing scale (4px, 8px, 12px, 16px, 24px) and
   stick to it in padding/margins.

6. **Windows font: Segoe UI** — This is the Windows system font. Using it makes your app
   feel native. Fallback: `"Segoe UI", "Arial", sans-serif`.

7. **Color contrast** — Ensure text has sufficient contrast against backgrounds. Use
   WCAG AA guidelines (4.5:1 ratio for normal text).

8. **Avoid !important** — QSS doesn't support `!important`. Specificity is determined by
   selector depth, similar to CSS.
