#!/usr/bin/env python3
"""
ori_weaver.py — 織 · Ori Weaver Process
=============================================
Multi-network reality browser with WebSocket IPC server.
Launched by OriWeaver.qml via Quickshell.Io.Process.

IPC: ws://127.0.0.1:9051
  Commands (JSON, ROM → browser):
    {"cmd":"show"}
    {"cmd":"hide"}
    {"cmd":"navigate","url":"..."}
    {"cmd":"newTab"}
    {"cmd":"closeTab","id":"..."}
    {"cmd":"back"}
    {"cmd":"forward"}
    {"cmd":"reload"}
    {"cmd":"stop"}
    {"cmd":"switchMode","mode":"clearnet|darknet|ipfs"}
    {"cmd":"vaultPin","cid":"Qm..."}
    {"cmd":"vaultUnpin","cid":"Qm..."}
    {"cmd":"focusTab","id":"..."}

  Events (JSON, browser → ROM):
    {"event":"ready"}
    {"event":"state","tabs":[...],"activeId":"...","url":"...","title":"...",
     "loading":false,"progress":100,"mode":"clearnet","modeLabel":"CLEAR","modeColor":"#00ff88",
     "ipfsGateway":true,"vaultPins":42}
    {"event":"targetDetected","ip":"..."}
"""

import sys
import os
import json
import re
import signal
import asyncio
import threading
import socket
from typing import Optional, Set

# ── Network mode configuration ───────────────────────────────────
import argparse

# Parse command line arguments
parser = argparse.ArgumentParser(description='Ori Weaver - Multi-network reality browser')
parser.add_argument('--mode', choices=['clearnet', 'darknet', 'ipfs'],
                    default='clearnet', help='Network mode (clearnet|darknet|ipfs)')
args = parser.parse_args()

# Set environment based on mode
if args.mode == "darknet":
    os.environ["QTWEBENGINE_CHROMIUM_FLAGS"] = (
        "--proxy-server=socks5://127.0.0.1:9050 "
        "--host-resolver-rules=MAP * ~NOTFOUND , EXCLUDE 127.0.0.1"
    )
elif args.mode == "ipfs":
    os.environ["QTWEBENGINE_CHROMIUM_FLAGS"] = ""
else:  # clearnet (default)
    os.environ.setdefault("QTWEBENGINE_CHROMIUM_FLAGS", "")

os.environ.setdefault("QTWEBENGINE_DISABLE_SANDBOX", "1")
os.environ.setdefault("QT_LOGGING_RULES", "qt.webenginecontext.info=false")

# Network modes configuration
NETWORK_MODES = {
    'clearnet': {
        'label': 'CLEAR',
        'color': '#00ff88',
        'proxy': None
    },
    'darknet': {
        'label': 'SHADOW',
        'color': '#f43f5e',
        'proxy': 'socks5://127.0.0.1:9050'
    },
    'ipfs': {
        'label': 'CRYSTAL',
        'color': '#00B4D8',
        'proxy': None,
        'gateway': 'http://localhost:8080'
    }
}

# Current mode state
current_mode = args.mode

from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget,
                              QVBoxLayout, QHBoxLayout, QLineEdit,
                              QPushButton, QTabBar, QStackedWidget,
                              QLabel)
from PyQt5.QtWebEngineWidgets import (QWebEngineView, QWebEngineSettings,
                                      QWebEngineProfile)
from PyQt5.QtWebEngineCore import QWebEngineUrlRequestInterceptor
from PyQt5.QtCore import QUrl, QTimer, pyqtSignal, QObject
from PyQt5.QtGui import QColor, QPalette

import websockets
from websockets.server import WebSocketServerProtocol

IPC_PORT    = 9051
HOME_URL    = "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion"
IP_PATTERN  = re.compile(r'\b(\d{1,3}(?:\.\d{1,3}){3})\b')
BLOCKED_DOMAINS = [
    "google-analytics.com", "doubleclick.net",
    "googletagmanager.com", "facebook.com/tr",
    "googlesyndication.com", "amazon-adsystem.com",
]

# ── Tracker interceptor ───────────────────────────────────────────────────────
class TrackerInterceptor(QWebEngineUrlRequestInterceptor):
    def interceptRequest(self, info):
        url = info.requestUrl().toString()
        for domain in BLOCKED_DOMAINS:
            if domain in url:
                info.block(True)
                return

# ── WebSocket IPC bridge ──────────────────────────────────────────────────────
# Runs in a background thread. Communicates with Qt via pyqtSignal (thread-safe).
class IpcBridge(QObject):
    # Qt → asyncio: call send_to_all from Qt thread
    # asyncio → Qt: emit commandReceived signal
    commandReceived = pyqtSignal(dict)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._clients: Set[WebSocketServerProtocol] = set()
        self._loop:    Optional[asyncio.AbstractEventLoop] = None
        self._lock     = threading.Lock()

    def start(self):
        """Start the WebSocket server in a daemon thread."""
        t = threading.Thread(target=self._run_loop, daemon=True)
        t.start()

    def _run_loop(self):
        self._loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._loop)
        self._loop.run_until_complete(self._serve())

    async def _serve(self):
        # Try the preferred port, fall back to any free port if taken
        port = IPC_PORT
        for attempt in range(3):
            try:
                async with websockets.serve(self._handler, "127.0.0.1", port):
                    print(f"[ori-weaver] WebSocket server ready on ws://127.0.0.1:{port}", flush=True)
                    if port != IPC_PORT:
                        # Notify QML of the actual port via a special event
                        print(f"[ori-weaver] IPC_PORT_OVERRIDE={port}", flush=True)
                    await asyncio.Future()  # run forever
                    return
            except OSError as e:
                if e.errno == 98 and attempt < 2:
                    print(f"[ori-weaver] port {port} in use, trying {port + 1}", flush=True)
                    port += 1
                else:
                    raise

    async def _handler(self, ws: WebSocketServerProtocol):
        with self._lock:
            self._clients.add(ws)
        # Re-broadcast ready to this client immediately on connect —
        # handles the race where QML connects after the initial broadcast
        try:
            await ws.send(json.dumps({"event": "ready"}))
        except Exception:
            pass
        try:
            async for message in ws:
                try:
                    cmd = json.loads(message)
                    self.commandReceived.emit(cmd)
                except (json.JSONDecodeError, ValueError):
                    pass
        finally:
            with self._lock:
                self._clients.discard(ws)

    def broadcast(self, data: dict):
        """Thread-safe broadcast from Qt thread to all WebSocket clients."""
        if not self._loop:
            return
        msg = json.dumps(data)
        asyncio.run_coroutine_threadsafe(self._broadcast_async(msg), self._loop)

    async def _broadcast_async(self, msg: str):
        with self._lock:
            clients = set(self._clients)
        if not clients:
            return
        await asyncio.gather(
            *[ws.send(msg) for ws in clients],
            return_exceptions=True
        )

# ── Tor connectivity check ────────────────────────────────────────────────────
def _tor_reachable() -> bool:
    """Quick non-blocking check: can we reach the Tor SOCKS proxy?"""
    try:
        s = socket.create_connection(("127.0.0.1", 9050), timeout=1.0)
        s.close()
        return True
    except OSError:
        return False

# ── Browser tab ───────────────────────────────────────────────────────────────
class BrowserTab:
    def __init__(self, tab_id: str, profile: QWebEngineProfile):
        self.id       = tab_id
        self.title    = "New Tab"
        self.url      = ""
        self.loading  = False
        self.progress = 0
        self.view     = QWebEngineView()
        self.view.setPage(self.view.page().__class__(profile, self.view))
        self.apply_security(2)

    def apply_security(self, level: int):
        s = self.view.settings()
        s.setAttribute(QWebEngineSettings.JavascriptEnabled,          level < 3)
        s.setAttribute(QWebEngineSettings.PluginsEnabled,             False)
        s.setAttribute(QWebEngineSettings.WebGLEnabled,               level == 1)
        s.setAttribute(QWebEngineSettings.LocalStorageEnabled,        level < 3)
        s.setAttribute(QWebEngineSettings.DnsPrefetchEnabled,         False)
        s.setAttribute(QWebEngineSettings.AutoLoadImages,             True)
        s.setAttribute(QWebEngineSettings.WebRTCPublicInterfacesOnly, True)

    def to_dict(self) -> dict:
        return {
            "id":       self.id,
            "title":    self.title,
            "url":      self.url,
            "loading":  self.loading,
            "progress": self.progress,
        }

# ── Main browser window ───────────────────────────────────────────────────────
class OriWeaver(QMainWindow):
    stateChanged   = pyqtSignal(dict)
    targetDetected = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self.setWindowTitle("織 · Ori Weaver")
        self.resize(1280, 800)
        self.setMinimumSize(800, 600)

        pal = QPalette()
        pal.setColor(QPalette.Window,     QColor(8, 4, 12))
        pal.setColor(QPalette.WindowText, QColor(220, 230, 255))
        pal.setColor(QPalette.Base,       QColor(12, 6, 18))
        pal.setColor(QPalette.Text,       QColor(220, 230, 255))
        self.setPalette(pal)

        self._profile     = QWebEngineProfile("ori", self)
        self._interceptor = TrackerInterceptor()
        self._profile.setUrlRequestInterceptor(self._interceptor)
        self._profile.setHttpUserAgent(
            "Mozilla/5.0 (Windows NT 10.0; rv:109.0) Gecko/20100101 Firefox/115.0"
        )

        self._tabs:      list[BrowserTab] = []
        self._active:    Optional[BrowserTab] = None
        self._sec_level: int = 2
        self._tor_ok:    bool = False
        self._current_mode: str = current_mode

        self._build_ui()
        self._new_tab(HOME_URL)

        # Tor check every 30s
        self._tor_timer = QTimer(self)
        self._tor_timer.setInterval(30_000)
        self._tor_timer.timeout.connect(self._check_tor)
        self._tor_timer.start()
        self._check_tor()

    # ── Tor check ─────────────────────────────────────────────────────────────
    def _check_tor(self):
        ok = _tor_reachable()
        if ok != self._tor_ok:
            self._tor_ok = ok
            self._emit_state()

    # ── UI ────────────────────────────────────────────────────────────────────
    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        root_layout = QVBoxLayout(central)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(0)

        btn_style = (
            "QPushButton{background:transparent;color:#00B4D8;"
            "border:1px solid #1a3a4a;border-radius:5px;padding:2px 6px;font-size:12px;}"
            "QPushButton:hover{background:#0a2a3a;}"
            "QPushButton:disabled{color:#333;border-color:#111;}"
        )

        # Chrome bar
        chrome = QWidget()
        chrome.setFixedHeight(44)
        chrome.setStyleSheet("background:#0a0614;border-bottom:1px solid #1a0a2a;")
        cl = QHBoxLayout(chrome)
        cl.setContentsMargins(8, 6, 8, 6)
        cl.setSpacing(4)

        self._btn_back   = QPushButton("◀"); self._btn_back.setFixedSize(30, 30);   self._btn_back.setStyleSheet(btn_style)
        self._btn_fwd    = QPushButton("▶"); self._btn_fwd.setFixedSize(30, 30);    self._btn_fwd.setStyleSheet(btn_style)
        self._btn_reload = QPushButton("↺"); self._btn_reload.setFixedSize(30, 30); self._btn_reload.setStyleSheet(btn_style)

        self._addr = QLineEdit()
        self._addr.setPlaceholderText("Search or enter address…  .onion supported")
        self._addr.setStyleSheet(
            "QLineEdit{background:#0d0618;color:#e0e8ff;border:1px solid #1a0a2a;"
            "border-radius:5px;padding:2px 8px;font-family:monospace;font-size:12px;}"
            "QLineEdit:focus{border-color:#00B4D8;}"
        )
        self._addr.returnPressed.connect(self._on_addr_enter)

        self._tor_label = QLabel("⚠ NO TOR")
        self._tor_label.setStyleSheet("color:#f43f5e;font-size:10px;font-family:monospace;padding:0 4px;")

        cl.addWidget(self._btn_back)
        cl.addWidget(self._btn_fwd)
        cl.addWidget(self._btn_reload)
        cl.addWidget(self._addr, 1)
        cl.addWidget(self._tor_label)

        self._btn_back.clicked.connect(lambda: self._active and self._active.view.back())
        self._btn_fwd.clicked.connect(lambda: self._active and self._active.view.forward())
        self._btn_reload.clicked.connect(self._on_reload_click)

        # Tab bar
        self._tab_bar = QTabBar()
        self._tab_bar.setTabsClosable(True)
        self._tab_bar.setMovable(True)
        self._tab_bar.setExpanding(False)
        self._tab_bar.setStyleSheet("""
            QTabBar::tab{background:#0a0614;color:#667;border:1px solid #1a0a2a;
                border-radius:4px;padding:4px 12px;margin:2px;
                font-family:monospace;font-size:11px;}
            QTabBar::tab:selected{background:#0d0a1a;color:#00B4D8;border-color:#00B4D8;}
            QTabBar::tab:hover{background:#0d0a1a;color:#aaa;}
        """)
        self._tab_bar.currentChanged.connect(self._on_tab_changed)
        self._tab_bar.tabCloseRequested.connect(self._close_tab_by_index)

        new_tab_btn = QPushButton("＋")
        new_tab_btn.setFixedSize(28, 26)
        new_tab_btn.setStyleSheet(btn_style)
        new_tab_btn.clicked.connect(lambda: self._new_tab(""))

        tab_row = QWidget()
        tab_row.setFixedHeight(32)
        tab_row.setStyleSheet("background:#080410;border-bottom:1px solid #1a0a2a;")
        trl = QHBoxLayout(tab_row)
        trl.setContentsMargins(4, 2, 4, 2)
        trl.setSpacing(2)
        trl.addWidget(self._tab_bar, 1)
        trl.addWidget(new_tab_btn)

        self._stack = QStackedWidget()
        self._stack.setStyleSheet("background:#000;")

        self._status = QLabel("Ready")
        self._status.setFixedHeight(20)
        self._status.setStyleSheet(
            "background:#080410;color:#334;font-family:monospace;"
            "font-size:10px;padding:0 8px;border-top:1px solid #1a0a2a;"
        )

        root_layout.addWidget(chrome)
        root_layout.addWidget(tab_row)
        root_layout.addWidget(self._stack, 1)
        root_layout.addWidget(self._status)

    # ── Tab management ────────────────────────────────────────────────────────
    def _new_tab(self, url: str = ""):
        tab = BrowserTab(f"tab_{len(self._tabs)}_{id(self)}", self._profile)
        tab.apply_security(self._sec_level)
        self._tabs.append(tab)
        self._stack.addWidget(tab.view)

        idx = self._tab_bar.addTab("New Tab")
        self._tab_bar.setCurrentIndex(idx)

        tab.view.titleChanged.connect(   lambda title, t=tab: self._on_title(t, title))
        tab.view.urlChanged.connect(     lambda url,   t=tab: self._on_url(t, url))
        tab.view.loadStarted.connect(    lambda        t=tab: self._on_load_start(t))
        tab.view.loadFinished.connect(   lambda ok,    t=tab: self._on_load_finish(t, ok))
        tab.view.loadProgress.connect(   lambda p,     t=tab: self._on_progress(t, p))

        target = url if url else HOME_URL
        tab.view.load(QUrl(self._resolve_url(target)))
        self._emit_state()

    def _close_tab_by_index(self, idx: int):
        if len(self._tabs) <= 1:
            return
        tab = self._tabs.pop(idx)
        self._stack.removeWidget(tab.view)
        tab.view.deleteLater()
        self._tab_bar.removeTab(idx)
        self._emit_state()

    def _on_tab_changed(self, idx: int):
        if 0 <= idx < len(self._tabs):
            self._active = self._tabs[idx]
            self._stack.setCurrentWidget(self._active.view)
            self._addr.setText(self._active.url)
            self._update_nav_buttons()
            self._emit_state()

    # ── Navigation ────────────────────────────────────────────────────────────
    def _resolve_url(self, text: str) -> str:
        text = text.strip()
        if not text:
            return HOME_URL

        # IPFS hash detection
        if text.startswith("Qm") or text.startswith("baf") or text.startswith("ipfs://"):
            cid = text.replace("ipfs://", "")
            return f"http://localhost:8080/ipfs/{cid}"

        # Standard URL resolution
        if text.startswith("http://") or text.startswith("https://"):
            return text
        if text.endswith(".onion") or ".onion/" in text:
            return "http://" + text
        if "." in text and " " not in text:
            return "https://" + text
        return (
            "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion"
            f"/html/?q={text}"
        )

    def _on_addr_enter(self):
        if self._active:
            self._active.view.load(QUrl(self._resolve_url(self._addr.text())))

    def _on_reload_click(self):
        if not self._active:
            return
        if self._active.loading:
            self._active.view.stop()
        else:
            self._active.view.reload()

    def navigate(self, url: str):
        if self._active:
            self._active.view.load(QUrl(self._resolve_url(url)))

    # ── View signal handlers ──────────────────────────────────────────────────
    def _on_title(self, tab: BrowserTab, title: str):
        tab.title = title or "New Tab"
        if tab in self._tabs:
            self._tab_bar.setTabText(self._tabs.index(tab), tab.title[:24])
        if tab is self._active:
            self.setWindowTitle(f"蜘蛛鬼 · {tab.title}")
        self._emit_state()

    def _on_url(self, tab: BrowserTab, url: QUrl):
        tab.url = url.toString()
        if tab is self._active:
            self._addr.setText(tab.url)
            self._update_nav_buttons()
        for m in IP_PATTERN.finditer(tab.url):
            self.targetDetected.emit(m.group(1))
        self._emit_state()

    def _on_load_start(self, tab: BrowserTab):
        tab.loading  = True
        tab.progress = 0
        if tab is self._active:
            self._btn_reload.setText("✕")
            self._status.setText("Loading…")
        self._emit_state()

    def _on_load_finish(self, tab: BrowserTab, ok: bool):
        tab.loading  = False
        tab.progress = 100
        if tab is self._active:
            self._btn_reload.setText("↺")
            self._status.setText(tab.url)
            self._update_nav_buttons()
        self._emit_state()

    def _on_progress(self, tab: BrowserTab, p: int):
        tab.progress = p
        if tab is self._active:
            self._status.setText(f"Loading… {p}%")
        self._emit_state()

    def _update_nav_buttons(self):
        if self._active:
            self._btn_back.setEnabled(self._active.view.history().canGoBack())
            self._btn_fwd.setEnabled(self._active.view.history().canGoForward())
        # Update tor label
        if self._tor_ok:
            self._tor_label.setText("🔐 TOR")
            self._tor_label.setStyleSheet("color:#4ade80;font-size:10px;font-family:monospace;padding:0 4px;")
        else:
            self._tor_label.setText("⚠ NO TOR")
            self._tor_label.setStyleSheet("color:#f43f5e;font-size:10px;font-family:monospace;padding:0 4px;")

    # ── IPC command handler ───────────────────────────────────────────────────
    def handle_command(self, cmd: dict):
        action = cmd.get("cmd", "")
        if action == "show":
            self.show(); self.raise_(); self.activateWindow()
        elif action == "hide":
            self.hide()
        elif action == "navigate":
            self.navigate(cmd.get("url", ""))
        elif action == "newTab":
            self._new_tab(cmd.get("url", ""))
        elif action == "closeTab":
            tid = cmd.get("id", "")
            for i, t in enumerate(self._tabs):
                if t.id == tid:
                    self._close_tab_by_index(i); break
        elif action == "focusTab":
            tid = cmd.get("id", "")
            for i, t in enumerate(self._tabs):
                if t.id == tid:
                    self._tab_bar.setCurrentIndex(i); break
        elif action == "back":
            if self._active: self._active.view.back()
        elif action == "forward":
            if self._active: self._active.view.forward()
        elif action == "reload":
            if self._active: self._active.view.reload()
        elif action == "stop":
            if self._active: self._active.view.stop()
        elif action == "switchMode":
            new_mode = cmd.get("mode", "clearnet")
            if new_mode in NETWORK_MODES:
                self._current_mode = new_mode
                self._emit_state()
        elif action == "vaultPin":
            cid = cmd.get("cid", "")
            if cid and self._current_mode == "ipfs":
                # TODO: Implement IPFS pinning
                pass
        elif action == "vaultUnpin":
            cid = cmd.get("cid", "")
            if cid and self._current_mode == "ipfs":
                # TODO: Implement IPFS unpinning
                pass
        elif action == "setSecLevel":
            self._sec_level = max(1, min(3, int(cmd.get("level", 2))))
            for t in self._tabs:
                t.apply_security(self._sec_level)

    # ── State broadcast ───────────────────────────────────────────────────────
    def _emit_state(self):
        mode_config = NETWORK_MODES[self._current_mode]
        self.stateChanged.emit({
            "event":        "state",
            "tabs":         [t.to_dict() for t in self._tabs],
            "activeId":     self._active.id       if self._active else "",
            "url":          self._active.url      if self._active else "",
            "title":        self._active.title    if self._active else "",
            "loading":      self._active.loading  if self._active else False,
            "progress":     self._active.progress if self._active else 0,
            "torConnected": self._tor_ok,
            "secLevel":     self._sec_level,
            "mode":         self._current_mode,
            "modeLabel":    mode_config["label"],
            "modeColor":    mode_config["color"],
            "ipfsGateway": self._current_mode == "ipfs",
            "vaultPins":    42,  # TODO: Get from Akasha IPFS pins.json
        })

# ── Entry point ───────────────────────────────────────────────────────────────
def main():
    signal.signal(signal.SIGINT,  signal.SIG_DFL)
    signal.signal(signal.SIGTERM, signal.SIG_DFL)

    # ── Early stdout signal — flips _procRunning in QML immediately ──
    # Printed before QApplication so the QML WebSocket starts connecting
    # while WebEngine initializes (which can take several seconds).
    print(f"[ori-weaver] IPC listening on ws://127.0.0.1:{IPC_PORT}", flush=True)
    print(f"[ori-weaver] mode={current_mode} — initializing WebEngine…", flush=True)

    app = QApplication(sys.argv)
    app.setApplicationName("ori-weaver")
    app.setOrganizationName("shigurui")
    print("[ori-weaver] QApplication initialized", flush=True)

    browser = OriWeaver()
    print("[ori-weaver] browser window created", flush=True)
    ipc     = IpcBridge()

    # Wire IPC ↔ browser (thread-safe via Qt signals)
    ipc.commandReceived.connect(browser.handle_command)
    browser.stateChanged.connect(ipc.broadcast)
    browser.targetDetected.connect(
        lambda ip: ipc.broadcast({"event": "targetDetected", "ip": ip})
    )

    # Start WebSocket server in background thread
    ipc.start()
    print("[ori-weaver] IPC bridge started", flush=True)

    # Signal ready after event loop settles — gives QML time to connect
    QTimer.singleShot(300, lambda: ipc.broadcast({"event": "ready"}))

    # Start hidden — show only on "show" command from ROM
    browser.hide()
    print("[ori-weaver] ready — waiting for commands", flush=True)

    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
