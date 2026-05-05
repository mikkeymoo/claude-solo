# Patterns and Recipes — Common UI Components

> **Note:** This file is primarily PySide6/Qt-focused recipes. For Flet and NiceGUI equivalents of the most common patterns, see "Section 0: Modern Framework Recipes" below.

## Table of Contents

**0. Modern Framework Recipes (Flet & NiceGUI)** ← read first if using these frameworks
1. Data Tables with Sorting and Filtering (PySide6)
2. Forms with Validation (PySide6)
3. File Open/Save Dialogs (PySide6)
4. System Tray Icon (PySide6)
5. Multi-Tab Interface (PySide6)
6. Splash Screen (PySide6)
7. Progress Dialog with Cancel (PySide6)
8. Confirmation and Message Dialogs (PySide6)
9. Toolbar with Actions (PySide6)
10. Dock Widgets (PySide6)
11. Drag and Drop (PySide6)
12. Keyboard Shortcuts (PySide6)

---

## 0. Modern Framework Recipes (Flet & NiceGUI)

### 0a. Flet — Data Table with Search

```python
import flet as ft

DATA = [
    {"id": 1, "name": "Acme Corp", "status": "Active", "revenue": 125000},
    {"id": 2, "name": "Globex",    "status": "Pending", "revenue": 89000},
    {"id": 3, "name": "Initech",   "status": "Active", "revenue": 210000},
]

def main(page: ft.Page):
    page.theme_mode = ft.ThemeMode.DARK
    page.padding = 24

    search = ft.TextField(label="Search", prefix_icon=ft.Icons.SEARCH, expand=True)
    table = ft.DataTable(
        columns=[
            ft.DataColumn(ft.Text("ID")),
            ft.DataColumn(ft.Text("Name")),
            ft.DataColumn(ft.Text("Status")),
            ft.DataColumn(ft.Text("Revenue"), numeric=True),
        ],
        rows=[],
    )

    def render(filter_text=""):
        f = filter_text.lower()
        rows = [r for r in DATA if f in r["name"].lower()]
        table.rows = [
            ft.DataRow(cells=[
                ft.DataCell(ft.Text(str(r["id"]))),
                ft.DataCell(ft.Text(r["name"])),
                ft.DataCell(ft.Text(r["status"])),
                ft.DataCell(ft.Text(f"${r['revenue']:,}")),
            ]) for r in rows
        ]
        page.update()

    search.on_change = lambda e: render(search.value)
    render()

    page.add(ft.Column([search, table], spacing=16))

ft.app(target=main)
```

### 0b. Flet — Form with Validation

```python
import flet as ft

def main(page: ft.Page):
    page.theme_mode = ft.ThemeMode.DARK
    page.padding = 24

    name = ft.TextField(label="Name", helper_text="Required")
    email = ft.TextField(label="Email", helper_text="Required, must contain @")
    submit_status = ft.Text("")

    def submit(e):
        errors = []
        if not name.value:
            name.error_text = "Name is required"
            errors.append("name")
        else:
            name.error_text = None
        if not email.value or "@" not in email.value:
            email.error_text = "Valid email required"
            errors.append("email")
        else:
            email.error_text = None

        submit_status.value = "" if errors else f"Submitted: {name.value} <{email.value}>"
        submit_status.color = ft.Colors.GREEN if not errors else ft.Colors.RED
        page.update()

    page.add(
        ft.Column([
            ft.Text("Sign Up", size=24, weight=ft.FontWeight.W_600),
            name, email,
            ft.ElevatedButton("Submit", on_click=submit, icon=ft.Icons.CHECK),
            submit_status,
        ], spacing=12, width=400),
    )

ft.app(target=main)
```

### 0c. Flet — File Picker

```python
import flet as ft

def main(page: ft.Page):
    selected = ft.Text("No file selected")

    def on_pick(e: ft.FilePickerResultEvent):
        if e.files:
            selected.value = f"Selected: {e.files[0].path}"
            page.update()

    picker = ft.FilePicker(on_result=on_pick)
    page.overlay.append(picker)

    page.add(
        ft.ElevatedButton(
            "Pick a file",
            icon=ft.Icons.UPLOAD_FILE,
            on_click=lambda e: picker.pick_files(allow_multiple=False),
        ),
        selected,
    )

ft.app(target=main)
```

### 0d. Flet — Progress with Background Work

```python
import asyncio, flet as ft

def main(page: ft.Page):
    progress = ft.ProgressBar(width=400, value=0)
    status = ft.Text("Idle")
    button = ft.ElevatedButton("Start work", icon=ft.Icons.PLAY_ARROW)

    async def run_work(e):
        button.disabled = True
        for i in range(1, 11):
            await asyncio.sleep(0.3)  # Simulated work
            progress.value = i / 10
            status.value = f"Step {i}/10"
            page.update()
        status.value = "Done!"
        button.disabled = False
        page.update()

    button.on_click = run_work
    page.add(button, progress, status)

ft.app(target=main)
```

### 0e. NiceGUI — Data Table with Search

```python
from nicegui import ui, native

DATA = [
    {"id": 1, "name": "Acme Corp", "status": "Active", "revenue": 125000},
    {"id": 2, "name": "Globex",    "status": "Pending", "revenue": 89000},
    {"id": 3, "name": "Initech",   "status": "Active", "revenue": 210000},
]

columns = [
    {"name": "id",      "label": "ID",      "field": "id",      "sortable": True},
    {"name": "name",    "label": "Name",    "field": "name",    "sortable": True, "align": "left"},
    {"name": "status",  "label": "Status",  "field": "status"},
    {"name": "revenue", "label": "Revenue", "field": "revenue", "sortable": True, "align": "right"},
]

table = ui.table(columns=columns, rows=DATA, row_key="id").classes("w-full")

def filter_rows(e):
    f = e.value.lower()
    table.rows = [r for r in DATA if f in r["name"].lower()]
    table.update()

ui.input("Search", on_change=filter_rows).classes("w-full")

ui.run(native=True, reload=False, port=native.find_open_port(), title="My App", dark=True)
```

### 0f. NiceGUI — Form with Validation

```python
from nicegui import ui, native

def submit():
    if not name.value:
        ui.notify("Name is required", type="negative"); return
    if "@" not in (email.value or ""):
        ui.notify("Valid email required", type="negative"); return
    ui.notify(f"Submitted: {name.value} <{email.value}>", type="positive")

with ui.card().classes("w-96 p-6 rounded-2xl"):
    ui.label("Sign Up").classes("text-xl font-semibold")
    name = ui.input("Name").classes("w-full")
    email = ui.input("Email").classes("w-full")
    ui.button("Submit", icon="check", on_click=submit).classes("mt-2")

ui.run(native=True, reload=False, port=native.find_open_port(), title="My App", dark=True)
```

### 0g. NiceGUI — File Upload

```python
from nicegui import ui, native, events

def handle_upload(e: events.UploadEventArguments):
    ui.notify(f"Got file: {e.name} ({len(e.content.read())} bytes)")

ui.upload(on_upload=handle_upload).classes("max-w-full")

ui.run(native=True, reload=False, port=native.find_open_port(), title="My App", dark=True)
```

### 0h. NiceGUI — Live Chart with Background Refresh

```python
from nicegui import ui, native
import random

values = [random.randint(0, 100) for _ in range(20)]
chart = ui.echart({
    "xAxis": {"type": "category"},
    "yAxis": {"type": "value"},
    "series": [{"type": "line", "data": values, "smooth": True}],
}).classes("w-full h-64")

def tick():
    values.append(random.randint(0, 100))
    if len(values) > 20:
        values.pop(0)
    chart.options["series"][0]["data"] = values
    chart.update()

ui.timer(1.0, tick)

ui.run(native=True, reload=False, port=native.find_open_port(), title="Live Dashboard", dark=True)
```

---

## 1. Data Tables with Sorting and Filtering

Use `QTableView` with a model for best performance with large datasets.

```python
from PySide6.QtWidgets import QTableView, QVBoxLayout, QLineEdit, QWidget
from PySide6.QtCore import Qt, QSortFilterProxyModel, QAbstractTableModel


class DataTableModel(QAbstractTableModel):
    """Custom table model for structured data."""

    def __init__(self, data=None, headers=None):
        super().__init__()
        self._data = data or []
        self._headers = headers or []

    def rowCount(self, parent=None):
        return len(self._data)

    def columnCount(self, parent=None):
        return len(self._headers)

    def data(self, index, role=Qt.DisplayRole):
        if role == Qt.DisplayRole:
            return str(self._data[index.row()][index.column()])
        return None

    def headerData(self, section, orientation, role=Qt.DisplayRole):
        if role == Qt.DisplayRole and orientation == Qt.Horizontal:
            return self._headers[section]
        return None

    def update_data(self, new_data):
        """Replace all data and refresh the view."""
        self.beginResetModel()
        self._data = new_data
        self.endResetModel()


class FilterableTable(QWidget):
    """Table with search/filter bar."""

    def __init__(self, headers, parent=None):
        super().__init__(parent)
        layout = QVBoxLayout(self)

        # Search bar
        self.search_input = QLineEdit()
        self.search_input.setPlaceholderText("Search...")
        layout.addWidget(self.search_input)

        # Model → Proxy (filter/sort) → View
        self.model = DataTableModel(headers=headers)
        self.proxy = QSortFilterProxyModel()
        self.proxy.setSourceModel(self.model)
        self.proxy.setFilterCaseSensitivity(Qt.CaseInsensitive)
        self.proxy.setFilterKeyColumn(-1)  # Search all columns

        self.table = QTableView()
        self.table.setModel(self.proxy)
        self.table.setSortingEnabled(True)
        self.table.setAlternatingRowColors(True)
        self.table.setSelectionBehavior(QTableView.SelectRows)
        self.table.horizontalHeader().setStretchLastSection(True)
        layout.addWidget(self.table)

        # Connect search
        self.search_input.textChanged.connect(self.proxy.setFilterFixedString)
```

---

## 2. Forms with Validation

```python
from PySide6.QtWidgets import (
    QWidget, QFormLayout, QLineEdit, QPushButton, QLabel, QMessageBox
)
from PySide6.QtCore import Signal
from PySide6.QtGui import QRegularExpressionValidator
from PySide6.QtCore import QRegularExpression


class UserForm(QWidget):
    submitted = Signal(dict)

    def __init__(self, parent=None):
        super().__init__(parent)
        layout = QFormLayout(self)

        # Name field
        self.name_input = QLineEdit()
        self.name_input.setPlaceholderText("Enter full name")
        layout.addRow("Name:", self.name_input)

        # Email field with validation
        self.email_input = QLineEdit()
        self.email_input.setPlaceholderText("user@example.com")
        email_regex = QRegularExpression(r"^[\w\.-]+@[\w\.-]+\.\w+$")
        self.email_input.setValidator(QRegularExpressionValidator(email_regex))
        layout.addRow("Email:", self.email_input)

        # Error label (hidden by default)
        self.error_label = QLabel()
        self.error_label.setStyleSheet("color: #f38ba8;")
        self.error_label.hide()
        layout.addRow(self.error_label)

        # Submit button
        self.submit_btn = QPushButton("Submit")
        self.submit_btn.clicked.connect(self._validate_and_submit)
        layout.addRow(self.submit_btn)

    def _validate_and_submit(self):
        errors = []
        if not self.name_input.text().strip():
            errors.append("Name is required")
        if not self.email_input.hasAcceptableInput():
            errors.append("Valid email is required")

        if errors:
            self.error_label.setText("\n".join(errors))
            self.error_label.show()
            return

        self.error_label.hide()
        self.submitted.emit({
            "name": self.name_input.text().strip(),
            "email": self.email_input.text().strip(),
        })
```

---

## 3. File Open/Save Dialogs

```python
from PySide6.QtWidgets import QFileDialog


class FileDialogMixin:
    """Mix into any QWidget to add file dialog methods."""

    def open_file(self, filter_str="All Files (*);;CSV Files (*.csv);;Text Files (*.txt)"):
        path, _ = QFileDialog.getOpenFileName(self, "Open File", "", filter_str)
        if path:
            return path
        return None

    def open_files(self, filter_str="All Files (*)"):
        paths, _ = QFileDialog.getOpenFileNames(self, "Open Files", "", filter_str)
        return paths

    def save_file(self, default_name="", filter_str="All Files (*)"):
        path, _ = QFileDialog.getSaveFileName(self, "Save File", default_name, filter_str)
        if path:
            return path
        return None

    def open_directory(self):
        path = QFileDialog.getExistingDirectory(self, "Select Directory")
        if path:
            return path
        return None
```

**Tip**: Always use the `filter_str` parameter to guide users to expected file types.

---

## 4. System Tray Icon

```python
from PySide6.QtWidgets import QSystemTrayIcon, QMenu
from PySide6.QtGui import QIcon, QAction


class SystemTray:
    """Add system tray icon with context menu."""

    def __init__(self, app, main_window, icon_path):
        self.app = app
        self.window = main_window

        self.tray = QSystemTrayIcon(QIcon(icon_path), parent=app)
        self.tray.setToolTip("My Application")

        # Context menu
        menu = QMenu()
        show_action = QAction("Show", menu)
        show_action.triggered.connect(main_window.show)
        menu.addAction(show_action)

        quit_action = QAction("Quit", menu)
        quit_action.triggered.connect(app.quit)
        menu.addAction(quit_action)

        self.tray.setContextMenu(menu)
        self.tray.activated.connect(self._on_tray_activated)
        self.tray.show()

    def _on_tray_activated(self, reason):
        if reason == QSystemTrayIcon.DoubleClick:
            self.window.show()
            self.window.raise_()
            self.window.activateWindow()

    def show_notification(self, title, message, duration=5000):
        self.tray.showMessage(title, message, QSystemTrayIcon.Information, duration)
```

---

## 5. Multi-Tab Interface

```python
from PySide6.QtWidgets import QTabWidget, QWidget, QVBoxLayout, QLabel


class TabbedInterface(QTabWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setTabsClosable(True)
        self.setMovable(True)
        self.tabCloseRequested.connect(self._close_tab)

    def add_page(self, title, widget):
        index = self.addTab(widget, title)
        self.setCurrentIndex(index)
        return index

    def _close_tab(self, index):
        widget = self.widget(index)
        self.removeTab(index)
        widget.deleteLater()
```

---

## 6. Splash Screen

```python
from PySide6.QtWidgets import QSplashScreen, QApplication
from PySide6.QtGui import QPixmap
from PySide6.QtCore import Qt
import time


def show_splash(app, image_path, duration=2):
    """Show a splash screen while the app loads."""
    pixmap = QPixmap(image_path)
    splash = QSplashScreen(pixmap, Qt.WindowStaysOnTopHint)
    splash.show()
    splash.showMessage(
        "Loading...",
        Qt.AlignBottom | Qt.AlignCenter,
        Qt.white
    )
    app.processEvents()
    return splash

# Usage in main.py:
# splash = show_splash(app, resource_path("resources/images/splash.png"))
# window = MainWindow()  # Heavy initialization happens here
# window.show()
# splash.finish(window)
```

---

## 7. Progress Dialog with Cancel

```python
from PySide6.QtWidgets import QProgressDialog
from PySide6.QtCore import Qt


def create_progress_dialog(parent, title="Processing", label="Please wait..."):
    """Create a cancellable progress dialog."""
    dialog = QProgressDialog(label, "Cancel", 0, 100, parent)
    dialog.setWindowTitle(title)
    dialog.setWindowModality(Qt.WindowModal)
    dialog.setMinimumDuration(500)  # Only show if operation takes > 500ms
    dialog.setAutoClose(True)
    dialog.setAutoReset(True)
    return dialog

# Usage:
# progress = create_progress_dialog(self, "Importing Data")
# worker.progress.connect(progress.setValue)
# progress.canceled.connect(worker.cancel)
```

---

## 8. Confirmation and Message Dialogs

```python
from PySide6.QtWidgets import QMessageBox


def confirm_action(parent, title, message):
    """Show a Yes/No confirmation dialog. Returns True if user clicks Yes."""
    result = QMessageBox.question(
        parent, title, message,
        QMessageBox.Yes | QMessageBox.No,
        QMessageBox.No  # Default button
    )
    return result == QMessageBox.Yes


def show_error(parent, title, message, details=None):
    """Show an error dialog with optional details."""
    box = QMessageBox(parent)
    box.setIcon(QMessageBox.Critical)
    box.setWindowTitle(title)
    box.setText(message)
    if details:
        box.setDetailedText(details)
    box.exec()


def show_info(parent, title, message):
    QMessageBox.information(parent, title, message)
```

---

## 9. Toolbar with Actions

```python
from PySide6.QtWidgets import QToolBar
from PySide6.QtGui import QAction, QIcon, QKeySequence


def setup_toolbar(main_window):
    """Create a toolbar with common actions."""
    toolbar = QToolBar("Main Toolbar")
    toolbar.setMovable(False)
    main_window.addToolBar(toolbar)

    # New action with icon and shortcut
    new_action = QAction(QIcon(":/icons/new.png"), "&New", main_window)
    new_action.setShortcut(QKeySequence.New)
    new_action.setStatusTip("Create a new file")
    new_action.triggered.connect(main_window.on_new)
    toolbar.addAction(new_action)

    # Open
    open_action = QAction(QIcon(":/icons/open.png"), "&Open", main_window)
    open_action.setShortcut(QKeySequence.Open)
    open_action.triggered.connect(main_window.on_open)
    toolbar.addAction(open_action)

    toolbar.addSeparator()

    # Save
    save_action = QAction(QIcon(":/icons/save.png"), "&Save", main_window)
    save_action.setShortcut(QKeySequence.Save)
    save_action.triggered.connect(main_window.on_save)
    toolbar.addAction(save_action)

    return toolbar
```

---

## 10. Dock Widgets

```python
from PySide6.QtWidgets import QDockWidget, QTextEdit
from PySide6.QtCore import Qt


def add_dock(main_window, title, widget, area=Qt.RightDockWidgetArea):
    """Add a dockable panel to the main window."""
    dock = QDockWidget(title, main_window)
    dock.setWidget(widget)
    dock.setAllowedAreas(Qt.LeftDockWidgetArea | Qt.RightDockWidgetArea)
    main_window.addDockWidget(area, dock)
    return dock

# Usage:
# log_widget = QTextEdit()
# log_widget.setReadOnly(True)
# log_dock = add_dock(self, "Log Output", log_widget)
```

---

## 11. Drag and Drop

### Accept file drops on a widget

```python
from PySide6.QtWidgets import QLabel
from PySide6.QtCore import Qt, Signal


class DropZone(QLabel):
    """Widget that accepts file drops."""
    files_dropped = Signal(list)

    def __init__(self, parent=None):
        super().__init__("Drop files here", parent)
        self.setAlignment(Qt.AlignCenter)
        self.setAcceptDrops(True)
        self.setStyleSheet("""
            QLabel {
                border: 2px dashed #45475a;
                border-radius: 12px;
                padding: 40px;
                color: #a6adc8;
                font-size: 14px;
            }
        """)

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
            self.setStyleSheet(self.styleSheet().replace("#45475a", "#89b4fa"))

    def dragLeaveEvent(self, event):
        self.setStyleSheet(self.styleSheet().replace("#89b4fa", "#45475a"))

    def dropEvent(self, event):
        self.setStyleSheet(self.styleSheet().replace("#89b4fa", "#45475a"))
        files = [url.toLocalFile() for url in event.mimeData().urls()]
        self.files_dropped.emit(files)
```

---

## 12. Keyboard Shortcuts

```python
from PySide6.QtGui import QShortcut, QKeySequence


def setup_shortcuts(window):
    """Register global keyboard shortcuts."""

    # Ctrl+Q to quit
    quit_shortcut = QShortcut(QKeySequence("Ctrl+Q"), window)
    quit_shortcut.activated.connect(window.close)

    # F5 to refresh
    refresh_shortcut = QShortcut(QKeySequence("F5"), window)
    refresh_shortcut.activated.connect(window.on_refresh)

    # Ctrl+Shift+P for command palette (if you have one)
    palette_shortcut = QShortcut(QKeySequence("Ctrl+Shift+P"), window)
    palette_shortcut.activated.connect(window.show_command_palette)

    # Escape to close dialogs
    # (Handled automatically by QDialog)
```

**Standard shortcuts to include in any app:**
- `Ctrl+N` — New
- `Ctrl+O` — Open
- `Ctrl+S` — Save
- `Ctrl+Shift+S` — Save As
- `Ctrl+Z` / `Ctrl+Y` — Undo/Redo
- `Ctrl+Q` or `Alt+F4` — Quit
- `F1` — Help
- `F5` — Refresh (if applicable)
- `Ctrl+F` — Find/Search
