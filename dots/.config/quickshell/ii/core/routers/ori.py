"""
ori.py — Ori Weaver API router.
Relay endpoints for the Ori browser process (ws://127.0.0.1:9051).
GET  /api/ori/status   — browser process alive check
POST /api/ori/navigate — send navigate command to Ori
POST /api/ori/mode     — switch network mode (clearnet|darknet|ipfs)
"""

import asyncio
import json
import logging
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/ori", tags=["ori"])
logger = logging.getLogger("sim.ori")

NETWORK_MODES = {
    "clearnet": {"label": "CLEAR",  "color": "#00ff88"},
    "darknet":  {"label": "SHADOW", "color": "#f43f5e"},
    "ipfs":     {"label": "CRYSTAL","color": "#00B4D8"},
}


class NavigateRequest(BaseModel):
    url: str


class ModeRequest(BaseModel):
    mode: str   # clearnet | darknet | ipfs


async def _send_to_ori(cmd: dict) -> dict:
    """Send a JSON command to the Ori Weaver WebSocket process."""
    from config import ORI_WEAVER_PORT
    import websockets
    try:
        async with websockets.connect(
            f"ws://127.0.0.1:{ORI_WEAVER_PORT}",
            open_timeout=3,
        ) as ws:
            await ws.send(json.dumps(cmd))
            resp = await asyncio.wait_for(ws.recv(), timeout=5)
            return json.loads(resp)
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Ori Weaver unreachable: {e}")


@router.get("/status")
async def ori_status():
    from config import ORI_WEAVER_PORT
    import socket
    try:
        s = socket.create_connection(("127.0.0.1", ORI_WEAVER_PORT), timeout=1)
        s.close()
        return {"status": "online", "port": ORI_WEAVER_PORT}
    except Exception:
        return {"status": "offline", "port": ORI_WEAVER_PORT}


@router.post("/navigate")
async def navigate(req: NavigateRequest):
    return await _send_to_ori({"cmd": "navigate", "url": req.url})


@router.post("/mode")
async def set_mode(req: ModeRequest):
    if req.mode not in NETWORK_MODES:
        raise HTTPException(status_code=400, detail=f"Unknown mode: {req.mode}")
    return await _send_to_ori({"cmd": "switchMode", "mode": req.mode})
