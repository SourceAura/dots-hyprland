"""
events.py — SiM WebSocket hub and pulse broadcaster.
Handles SIM_QUERY streaming, GOVERNOR_STATE relay, and system pulse.
"""

import asyncio
import json
import logging
import time
from datetime import datetime, timezone
from typing import List

from fastapi import WebSocket
from fastapi.websockets import WebSocketState

logger = logging.getLogger("sim.events")

# ── Inference phase token thresholds ──────────────────────────────────
_PHASE_REASON_TOKEN  = 1   # first token → REASON
_PHASE_RESPOND_TOKEN = 8   # 8 tokens   → RESPOND


class SocketManager:
    """WebSocket hub — all QML clients connect here."""

    def __init__(self):
        self.active: List[WebSocket] = []
        self._locks: dict = {}
        self.broadcast_count = 0
        self.last_pulse = time.time()

    def _lock(self, ws: WebSocket):
        ws_id = id(ws)
        if ws_id not in self._locks:
            self._locks[ws_id] = asyncio.Lock()
        return self._locks[ws_id]

    async def connect(self, ws: WebSocket):
        if ws.client_state == WebSocketState.CONNECTING:
            await ws.accept()
        if ws not in self.active:
            self.active.append(ws)
            logger.info(f"WS connected — {len(self.active)} active")

    def disconnect(self, ws: WebSocket):
        if ws in self.active:
            self.active.remove(ws)
        self._locks.pop(id(ws), None)
        logger.info(f"WS disconnected — {len(self.active)} remaining")

    async def send(self, ws: WebSocket, msg: dict):
        async with self._lock(ws):
            try:
                await ws.send_json(msg)
                self.broadcast_count += 1
            except Exception:
                self.disconnect(ws)

    async def broadcast(self, msg: dict | str):
        if isinstance(msg, str):
            try:
                msg = json.loads(msg)
            except Exception:
                msg = {"type": "raw", "data": msg}
        self.last_pulse = time.time()
        for ws in list(self.active):
            await self.send(ws, msg)

    async def handle_message(self, ws: WebSocket, data: str):
        """Route incoming WebSocket messages."""
        try:
            msg = json.loads(data)
        except Exception:
            await self.send(ws, {"type": "error", "message": "Invalid JSON"})
            return

        msg_type = msg.get("type", "")
        message  = msg.get("message", "")

        if msg_type == "SIM_QUERY":
            await self._handle_query(ws, msg, message)
        elif msg_type == "PING":
            await self.send(ws, {"type": "PONG", "ts": datetime.now(timezone.utc).isoformat()})
        else:
            await self.send(ws, {"type": "error", "message": f"Unknown type: {msg_type}"})

    async def _handle_query(self, ws: WebSocket, msg: dict, message: str):
        from ai.manager import cognitive_manager

        if not cognitive_manager.is_ready:
            await self.send(ws, {
                "type":     "SIM_RESPONSE",
                "response": "◌ SiM initializing — Ollama is loading. Try again in a moment.",
            })
            return

        context = {
            "focused_rom":    msg.get("focused_rom",    "none"),
            "active_fold":    msg.get("active_fold",    "dormant"),
            "locked_target":  msg.get("locked_target",  ""),
            "breathing_style": msg.get("breathing_style", "moon"),
        }

        # Phase 1: INFERENCE_START
        await self.send(ws, {"type": "INFERENCE_START", "phase": "recall"})

        try:
            full        = ""
            token_count = 0
            stream_start = time.monotonic()

            async for token in cognitive_manager.decide_and_generate(message, context=context):
                full        += token
                token_count += 1
                elapsed      = time.monotonic() - stream_start
                tps          = token_count / elapsed if elapsed > 0.001 else 0.0

                if token_count == _PHASE_REASON_TOKEN:
                    await self.send(ws, {"type": "THINKING_PHASE", "phase": "reason"})
                elif token_count == _PHASE_RESPOND_TOKEN:
                    await self.send(ws, {"type": "THINKING_PHASE", "phase": "respond"})

                await self.send(ws, {
                    "type":           "STREAM_TOKEN",
                    "token":          token,
                    "tokens_per_sec": round(tps, 1),
                })

            if full:
                await self.send(ws, {"type": "STREAM_END", "response": full})
            else:
                raise ValueError("Empty stream")

        except Exception as e:
            logger.warning(f"Streaming failed ({e}), falling back to process_message")
            try:
                response = await cognitive_manager.process_message(message)
                await self.send(ws, {"type": "SIM_RESPONSE", "response": response})
            except Exception as e2:
                await self.send(ws, {
                    "type":     "SIM_RESPONSE",
                    "response": f"◌ SiM error: {type(e).__name__}: {str(e)[:80]}",
                })


socket_manager = SocketManager()


async def broadcast_pulse():
    """Broadcast system vitals every 5s. Backs off to 10s under load."""
    import psutil
    while True:
        try:
            if not socket_manager.active:
                await asyncio.sleep(5)
                continue

            cpu = psutil.cpu_percent(interval=None)
            mem = psutil.virtual_memory()
            interval = 10 if cpu > 65 else 5

            await socket_manager.broadcast({
                "type":      "pulse",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "vitals": {
                    "cpu":    round(cpu, 1),
                    "memory": round(mem.percent, 1),
                },
            })
        except Exception as e:
            logger.error(f"Pulse error: {e}")
            interval = 10
        await asyncio.sleep(interval)


async def relay_governor():
    """
    Read GOVERNOR_STATE events from the sim-governor Unix socket
    and broadcast them to all WebSocket clients.
    """
    import os
    from config import SIM_GOVERNOR_SOCK

    while True:
        if not os.path.exists(SIM_GOVERNOR_SOCK):
            await asyncio.sleep(3)
            continue
        try:
            reader, _ = await asyncio.open_unix_connection(SIM_GOVERNOR_SOCK)
            while True:
                line = await reader.readline()
                if not line:
                    break
                try:
                    state = json.loads(line.decode())
                    state["type"] = "GOVERNOR_STATE"
                    await socket_manager.broadcast(state)
                except json.JSONDecodeError:
                    continue
        except Exception as e:
            logger.debug(f"Governor relay: {e}")
            await asyncio.sleep(5)
