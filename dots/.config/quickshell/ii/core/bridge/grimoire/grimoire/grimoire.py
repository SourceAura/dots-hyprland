#!/usr/bin/env python3
"""
grimoire.py — ⬡ Grimoire IDE Process
=======================================
Three-pane IDE: file tree, editor with syntax highlighting, Ase chat.
Launched by Grimoire.qml via Quickshell.Io.Process.

IPC: ws://127.0.0.1:9053
  Commands (QML → IDE):
    {"cmd":"show"}
    {"cmd":"hide"}
    {"cmd":"openFile","path":"..."}
    {"cmd":"saveActive"}
    {"cmd":"askAse","text":"..."}
    {"cmd":"setMorphColor","color":"#rrggbb"}
    {"cmd":"setCwd","path":"..."}

  Events (IDE → QML):
    {"event":"ready"}
    {"event":"state","activeFile":"...","isDirty":false,"cwd":"..."}
    {"event":"aseResponse","text":"..."}
"""

import sys
import os
import json
import signal
import asyncio
import threading
import subprocess
from pathlib import Path
from typing import Optional, Set

import websockets
from websockets.server import WebSocketServerProtocol

from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QSplitter, QTreeView, QPlainTextEdit, QTabBar, QStackedWidget,
    QLabel, QPushButton, QFileSystemModel, QTextEdit, QLineEdit,
    QScrollArea, QFrame, QSizePolicy
)
from PyQt5.QtCore import Qt, QTimer, QObject, pyqtSignal, QDir, QModelIndex
from PyQt5.QtGui import (
    QColor, QPalette, QFont, QSyntaxHighlighter, QTextCharFormat,
    QTextCursor
)

import re

IPC_PORT = 9053

# ── Syntax highlighter ────────────────────────────────────────────────────────

class CodeHighlighter(QSyntaxHighlighter):
    """Minimal multi-language syntax highlighter."""

    RULES = {
        "py": [
            (r'\b(def|class|import|from|return|if|elif|else|for|while|with|as|'
             r'try|except|finally|raise|pass|break|continue|lambda|yield|async|await|True|False|None)\b',
             "#818cf8", True),
            (r'#[^\n]*',                    "#667", False),
            (r'"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'', "#4ade80", False),
            (r'"[^"\\]*(?:\\.[^"\\]*)*"|\'[^\'\\]*(?:\\.[^\'\\]*)*\'', "#4ade80", False),
            (r'\b\d+\.?\d*\b',              "#f59e0b", False),
        ],
        "js": [
            (r'\b(const|let|var|function|return|if|else|for|while|class|import|'
             r'export|default|new|this|typeof|instanceof|true|false|null|undefined|async|await)\b',
             "#818cf8", True),
            (r'//[^\n]*',                   "#667", False),
            (r'/\*[\s\S]*?\*/',             "#667", False),
            (r'"[^"\\]*(?:\\.[^"\\]*)*"|\'[^\'\\]*(?:\\.[^\'\\]*)*\'|`[^`]*`',
             "#4ade80", False),
            (r'\b\d+\.?\d*\b',              "#f59e0b", False),
        ],
        "rs": [
            (r'\b(fn|let|mut|pub|use|mod|struct|enum|impl|trait|where|match|if|'
             r'else|for|while|loop|return|true|false|self|Self|super|crate|async|await)\b',
             "#818cf8", True),
            (r'//[^\n]*',                   "#667", False),
            (r'"[^"\\]*(?:\\.[^"\\]*)*"',   "#4ade80", False),
            (r'\b\d+\.?\d*\b',              "#f59e0b", False),
        ],
        "qml": [
            (r'\b(import|property|signal|function|var|let|const|if|else|for|while|'
             r'return|true|false|null|undefined|readonly|alias|on|id)\b',
             "#818cf8", True),
            (r'//[^\n]*',                   "#667", False),
            (r'/\*[\s\S]*?\*/',             "#667", False),
            (r'"[^"\\]*(?:\\.[^"\\]*)*"',   "#4ade80", False),
            (r'\b\d+\.?\d*\b',              "#f59e0b", False),
        ],
    }
    # Fallback — generic keywords
    RULES["ts"]  = RULES["js"]
    RULES["tsx"] = RULES["js"]
    RULES["jsx"] = RULES["js"]
    RULES["sh"]  = [(r'#[^\n]*', "#667", False), (r'"[^"]*"', "#4ade80", False)]
    RULES["toml"]= [(r'#[^\n]*', "#667", False), (r'"[^"]*"', "#4ade80", False),
                    (r'\[[^\]]*\]', "#818cf8", True)]

    def __init__(self, document, ext: str = ""):
        super().__init__(document)
        self._rules = []
        rules_src = self.RULES.get(ext.lower(), [])
        for pattern, color, bold in rules_src:
            fmt = QTextCharFormat()
            fmt.setForeground(QColor(color))
            if bold:
                fmt.setFontWeight(700)
            self._rules.append((re.compile(pattern), fmt))

    def highlightBlock(self, text: str):
        for regex, fmt in self._rules:
            for m in regex.finditer(text):
                self.setFormat(m.start(), m.end() - m.start(), fmt)


# ── WebSocket IPC bridge ──────────────────────────────────────────────────────

class IpcBridge(QObject):
    commandReceived = pyqtSignal(dict)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._clients: Set[WebSocketServerProtocol] = set()
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._lock = threading.Lock()

    def start(self):
        t = threading.Thread(target=self._run_loop, daemon=True)
        t.start()

    def _run_loop(self):
        self._loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._loop)
        self._loop.run_until_complete(self._serve())

    async def _serve(self):
        port = IPC_PORT
        for attempt in range(3):
            try:
                async with websockets.serve(self._handler, "127.0.0.1", port):
                    print(f"[grimoire] WebSocket ready on ws://127.0.0.1:{port}", flush=True)
                    await asyncio.Future()
                    return
            except OSError:
                if attempt < 2:
                    port += 1
                else:
                    raise

    async def _handler(self, ws: WebSocketServerProtocol):
        with self._lock:
            self._clients.add(ws)
        try:
            await ws.send(json.dumps({"event": "ready"}))
        except Exception:
            pass
        try:
            async for message in ws:
                try:
                    self.commandReceived.emit(json.loads(message))
                except Exception:
                    pass
        finally:
            with self._lock:
                self._clients.discard(ws)

    def broadcast(self, data: dict):
        if not self._loop:
            return
        msg = json.dumps(data)
        asyncio.run_coroutine_threadsafe(self._broadcast_async(msg), self._loop)

    async def _broadcast_async(self, msg: str):
        with self._lock:
            clients = set(self._clients)
        if clients:
            await asyncio.gather(*[ws.send(msg) for ws in clients], return_exceptions=True)


# ── Editor tab ────────────────────────────────────────────────────────────────

class EditorTab:
    def __init__(self, path: str):
        self.path     = path
        self.name     = Path(path).name
        self.ext      = Path(path).suffix.lstrip(".")
        self.is_dirty = False
        self.editor   = QPlainTextEdit()
        self._setup_editor()
        self._highlighter = CodeHighlighter(self.editor.document(), self.ext)
        self._load()

    def _setup_editor(self):
        font = QFont("Fira Code, monospace", 12)
        font.setFixedPitch(True)
        self.editor.setFont(font)
        self.editor.setStyleSheet(
            "QPlainTextEdit{background:#0a0614;color:#e2e8f0;"
            "border:none;selection-background-color:#1a3a5a;}"
        )
        self.editor.setLineWrapMode(QPlainTextEdit.NoWrap)
        self.editor.textChanged.connect(self._on_changed)

    def _load(self):
        try:
            text = Path(self.path).read_text(errors="replace")
            self.editor.blockSignals(True)
            self.editor.setPlainText(text)
            self.editor.blockSignals(False)
            self.is_dirty = False
        except Exception as e:
            self.editor.setPlainText(f"# Error loading file: {e}")

    def save(self):
        try:
            Path(self.path).write_text(self.editor.toPlainText())
            self.is_dirty = False
            return True
        except Exception:
            return False

    def _on_changed(self):
        self.is_dirty = True

    def content(self) -> str:
        return self.editor.toPlainText()


# ── Main window ───────────────────────────────────────────────────────────────

class GrimoireWindow(QMainWindow):
    def __init__(self, ipc: IpcBridge):
        super().__init__()
        self._ipc    = ipc
        self._tabs:  list[EditorTab] = []
        self._active = -1
        self._morph  = "#818cf8"
        self._cwd    = str(Path.home())
        self._ase_buffer = ""

        self.setWindowTitle("⬡ Grimoire")
        self.resize(1280, 800)
        self.setMinimumSize(700, 500)
        self._apply_palette()
        self._build_ui()

    def _apply_palette(self):
        pal = QPalette()
        pal.setColor(QPalette.Window,     QColor("#0a0614"))
        pal.setColor(QPalette.WindowText, QColor("#e2e8f0"))
        pal.setColor(QPalette.Base,       QColor("#0a0614"))
        pal.setColor(QPalette.Text,       QColor("#e2e8f0"))
        pal.setColor(QPalette.Highlight,  QColor("#1a3a5a"))
        self.setPalette(pal)

    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        root_layout = QVBoxLayout(central)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(0)

        # Tab bar
        tab_row = QWidget()
        tab_row.setFixedHeight(32)
        tab_row.setStyleSheet("background:#080410;border-bottom:1px solid #1a0a2a;")
        trl = QHBoxLayout(tab_row)
        trl.setContentsMargins(4, 2, 4, 2)
        trl.setSpacing(2)

        self._tab_bar = QTabBar()
        self._tab_bar.setTabsClosable(True)
        self._tab_bar.setMovable(True)
        self._tab_bar.setExpanding(False)
        self._tab_bar.setStyleSheet(f"""
            QTabBar::tab{{background:#0a0614;color:#667;border:1px solid #1a0a2a;
                border-radius:4px;padding:4px 14px;margin:2px;font-family:monospace;font-size:11px;}}
            QTabBar::tab:selected{{background:#0d0a1a;color:{self._morph};border-color:{self._morph};}}
            QTabBar::tab:hover{{background:#0d0a1a;color:#aaa;}}
        """)
        self._tab_bar.currentChanged.connect(self._on_tab_changed)
        self._tab_bar.tabCloseRequested.connect(self._close_tab)

        trl.addWidget(self._tab_bar, 1)
        root_layout.addWidget(tab_row)

        # Three-pane splitter
        splitter = QSplitter(Qt.Horizontal)
        splitter.setStyleSheet("QSplitter::handle{background:#1a0a2a;width:1px;}")

        # 1. File tree
        self._fs_model = QFileSystemModel()
        self._fs_model.setRootPath(self._cwd)
        self._tree = QTreeView()
        self._tree.setModel(self._fs_model)
        self._tree.setRootIndex(self._fs_model.index(self._cwd))
        self._tree.setColumnHidden(1, True)
        self._tree.setColumnHidden(2, True)
        self._tree.setColumnHidden(3, True)
        self._tree.setHeaderHidden(True)
        self._tree.setStyleSheet(
            "QTreeView{background:#080410;color:#8892a4;border:none;font-family:monospace;font-size:11px;}"
            "QTreeView::item:selected{background:#1a0a2a;color:#e2e8f0;}"
            "QTreeView::item:hover{background:#0d0618;}"
        )
        self._tree.setMinimumWidth(160)
        self._tree.setMaximumWidth(280)
        self._tree.doubleClicked.connect(self._on_tree_double_click)
        splitter.addWidget(self._tree)

        # 2. Editor stack
        self._editor_stack = QStackedWidget()
        self._editor_stack.setStyleSheet("background:#0a0614;")

        # Empty state
        empty = QLabel("⬡  open a file to start scripting")
        empty.setAlignment(Qt.AlignCenter)
        empty.setStyleSheet("color:#334;font-family:monospace;font-size:13px;")
        self._editor_stack.addWidget(empty)
        splitter.addWidget(self._editor_stack)

        # 3. Ase chat pane
        ase_pane = QWidget()
        ase_pane.setMinimumWidth(240)
        ase_pane.setMaximumWidth(360)
        ase_pane.setStyleSheet("background:#080410;border-left:1px solid #1a0a2a;")
        ase_layout = QVBoxLayout(ase_pane)
        ase_layout.setContentsMargins(8, 8, 8, 8)
        ase_layout.setSpacing(6)

        ase_header = QLabel("◈  ASE NEXUS")
        ase_header.setStyleSheet(f"color:{self._morph};font-family:monospace;font-size:10px;font-weight:bold;")
        ase_layout.addWidget(ase_header)

        self._ase_chat = QTextEdit()
        self._ase_chat.setReadOnly(True)
        self._ase_chat.setStyleSheet(
            "QTextEdit{background:#0a0614;color:#e2e8f0;border:none;"
            "font-family:monospace;font-size:11px;}"
        )
        ase_layout.addWidget(self._ase_chat, 1)

        self._ase_input = QLineEdit()
        self._ase_input.setPlaceholderText("ask ase…")
        self._ase_input.setStyleSheet(
            f"QLineEdit{{background:#0d0618;color:#e2e8f0;border:1px solid #1a0a2a;"
            f"border-radius:8px;padding:4px 10px;font-family:monospace;font-size:11px;}}"
            f"QLineEdit:focus{{border-color:{self._morph};}}"
        )
        self._ase_input.returnPressed.connect(self._on_ase_submit)
        ase_layout.addWidget(self._ase_input)

        splitter.addWidget(ase_pane)
        splitter.setSizes([200, 820, 260])

        root_layout.addWidget(splitter, 1)

        # Status bar
        self._status = QLabel(f"  {self._cwd}")
        self._status.setFixedHeight(20)
        self._status.setStyleSheet(
            "background:#080410;color:#334;font-family:monospace;"
            "font-size:10px;border-top:1px solid #1a0a2a;"
        )
        root_layout.addWidget(self._status)

    # ── File operations ───────────────────────────────────────────────────────

    def open_file(self, path: str):
        # Check if already open
        for i, tab in enumerate(self._tabs):
            if tab.path == path:
                self._tab_bar.setCurrentIndex(i)
                return

        tab = EditorTab(path)
        self._tabs.append(tab)
        self._editor_stack.addWidget(tab.editor)

        idx = self._tab_bar.addTab(tab.name)
        self._tab_bar.setCurrentIndex(idx)
        self._emit_state()

    def _save_active(self):
        if 0 <= self._active < len(self._tabs):
            tab = self._tabs[self._active]
            if tab.save():
                self._tab_bar.setTabText(self._active, tab.name)
                self._emit_state()

    def _close_tab(self, idx: int):
        if not (0 <= idx < len(self._tabs)):
            return
        tab = self._tabs.pop(idx)
        self._editor_stack.removeWidget(tab.editor)
        tab.editor.deleteLater()
        self._tab_bar.removeTab(idx)
        if self._tabs:
            self._active = min(idx, len(self._tabs) - 1)
        else:
            self._active = -1
            self._editor_stack.setCurrentIndex(0)
        self._emit_state()

    def _on_tab_changed(self, idx: int):
        self._active = idx
        if 0 <= idx < len(self._tabs):
            self._editor_stack.setCurrentWidget(self._tabs[idx].editor)
            self._tabs[idx].editor.setFocus()
        self._emit_state()

    def _on_tree_double_click(self, index: QModelIndex):
        path = self._fs_model.filePath(index)
        if Path(path).is_file():
            self.open_file(path)

    # ── Ase integration ───────────────────────────────────────────────────────

    def _on_ase_submit(self):
        query = self._ase_input.text().strip()
        if not query:
            return
        self._ase_input.clear()
        self._append_ase_chat("you", query)
        self._ask_ase(query)

    def _ask_ase(self, query: str):
        ctx = ""
        if 0 <= self._active < len(self._tabs):
            tab = self._tabs[self._active]
            cursor = tab.editor.textCursor()
            selected = cursor.selectedText()
            ctx = f"File: {tab.path}\n"
            if selected:
                ctx += f"Selection:\n{selected}\n\n"
            else:
                # Send surrounding context (±20 lines)
                lines = tab.content().split("\n")
                ln    = cursor.blockNumber()
                start = max(0, ln - 20)
                end   = min(len(lines), ln + 20)
                ctx  += f"Context (lines {start}–{end}):\n" + "\n".join(lines[start:end])

        import urllib.request
        payload = json.dumps({
            "type":    "SIM_QUERY",
            "message": f"{ctx}\n\nQuery: {query}" if ctx else query,
            "context": "grimoire_ide"
        }).encode()
        try:
            req = urllib.request.Request(
                "http://127.0.0.1:8765/api/chat/stream",
                data=payload,
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                text = resp.read().decode()
                self._append_ase_chat("ase", text)
                self._ipc.broadcast({"event": "aseResponse", "text": text})
        except Exception as e:
            self._append_ase_chat("ase", f"[offline: {e}]")

    def _append_ase_chat(self, role: str, text: str):
        color = self._morph if role == "ase" else "#667"
        self._ase_chat.append(
            f'<span style="color:{color};font-size:9px;font-weight:bold;">'
            f'{role.upper()}</span><br>'
            f'<span style="color:#e2e8f0;font-size:11px;">{text}</span><br>'
        )

    # ── IPC command handler ───────────────────────────────────────────────────

    def handle_command(self, cmd: dict):
        action = cmd.get("cmd", "")
        if action == "show":
            self.show(); self.raise_(); self.activateWindow()
        elif action == "hide":
            self.hide()
        elif action == "openFile":
            self.open_file(cmd.get("path", ""))
        elif action == "saveActive":
            self._save_active()
        elif action == "askAse":
            self._ask_ase(cmd.get("text", ""))
        elif action == "setMorphColor":
            self._morph = cmd.get("color", "#818cf8")
        elif action == "setCwd":
            path = cmd.get("path", "")
            if Path(path).is_dir():
                self._cwd = path
                self._fs_model.setRootPath(path)
                self._tree.setRootIndex(self._fs_model.index(path))
                self._status.setText(f"  {path}")

    def _emit_state(self):
        active_file = ""
        is_dirty    = False
        if 0 <= self._active < len(self._tabs):
            tab         = self._tabs[self._active]
            active_file = tab.path
            is_dirty    = tab.is_dirty
        self._ipc.broadcast({
            "event":      "state",
            "activeFile": active_file,
            "isDirty":    is_dirty,
            "cwd":        self._cwd,
        })

    # ── Keyboard shortcuts ────────────────────────────────────────────────────

    def keyPressEvent(self, event):
        if event.modifiers() & Qt.ControlModifier:
            if event.key() == Qt.Key_S:
                self._save_active()
                return
            if event.key() == Qt.Key_W:
                if self._active >= 0:
                    self._close_tab(self._active)
                return
        super().keyPressEvent(event)


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    signal.signal(signal.SIGINT,  signal.SIG_DFL)
    signal.signal(signal.SIGTERM, signal.SIG_DFL)

    print(f"[grimoire] IPC listening on ws://127.0.0.1:{IPC_PORT}", flush=True)

    app = QApplication(sys.argv)
    app.setApplicationName("grimoire")
    app.setOrganizationName("shigurui")

    ipc    = IpcBridge()
    window = GrimoireWindow(ipc)

    ipc.commandReceived.connect(window.handle_command)
    ipc.start()

    QTimer.singleShot(300, lambda: ipc.broadcast({"event": "ready"}))

    window.hide()
    print("[grimoire] ready — waiting for commands", flush=True)

    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
