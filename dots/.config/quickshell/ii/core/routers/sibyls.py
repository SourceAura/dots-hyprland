"""
sibyls.py — Sibyl status and notification routing.
GET  /api/sibyls/status  — which Sibyls are active
POST /api/sibyls/notify  — push a notification to a fold's tarot card
"""

from datetime import datetime, timezone
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/sibyls", tags=["sibyls"])

# ── Sibyl registry ────────────────────────────────────────────────────
SIBYLS = {
    "eye":     {"name": "Delphic",       "domain": "TRUTH",      "icon": "◉", "color": "#00C2FF"},
    "phantom": {"name": "Hellespontine", "domain": "POWER",      "icon": "⊗", "color": "#B44FE8"},
    "blade":   {"name": "Cimmerian",     "domain": "WISDOM",     "icon": "⚔", "color": "#FF3CAC"},
    "sage":    {"name": "Persian",       "domain": "JUDGMENT",   "icon": "◈", "color": "#FFB300"},
    "shroud":  {"name": "Erythraean",    "domain": "LIFE",       "icon": "☁", "color": "#00FFC8"},
    "forge":   {"name": "Tiburtine",     "domain": "LOVE",       "icon": "⬡", "color": "#FF6B35"},
    "mirror":  {"name": "Cumaean",       "domain": "DISCIPLINE", "icon": "◌", "color": "#C8B8FF"},
}


class NotifyRequest(BaseModel):
    fold:    str
    title:   str
    message: str = ""
    level:   str = "info"   # info | warning | critical


@router.get("/status")
async def sibyl_status():
    return {
        "sibyls":    SIBYLS,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@router.post("/notify")
async def sibyl_notify(req: NotifyRequest):
    """Push a notification to a fold's tarot card via WebSocket broadcast."""
    if req.fold not in SIBYLS:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail=f"Unknown fold: {req.fold}")

    sibyl = SIBYLS[req.fold]
    from events import socket_manager
    await socket_manager.broadcast({
        "type":    "SIBYL_NOTIFICATION",
        "fold":    req.fold,
        "title":   req.title,
        "message": req.message,
        "level":   req.level,
        "icon":    sibyl["icon"],
        "color":   sibyl["color"],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })
    return {"status": "sent", "fold": req.fold}
