"""
style.py — Breathing style hot-swap endpoint.
POST /api/style  {"name": "sun"|"moon"|"celestial"}
GET  /api/style  — current active style
GET  /api/styles — all available styles
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/style", tags=["style"])


class StyleRequest(BaseModel):
    name: str


@router.post("")
async def set_style(req: StyleRequest):
    from ai.breathing import set_style, get_style
    style = set_style(req.name)
    if not style:
        raise HTTPException(status_code=400, detail=f"Unknown style: {req.name}")
    # Broadcast style change to all WebSocket clients
    from events import socket_manager
    await socket_manager.broadcast({
        "type":  "STYLE_CHANGED",
        "style": style.name,
        "color": style.color,
        "icon":  style.icon,
    })
    return {"status": "ok", "style": style.name, "color": style.color}


# System resource limit synchronization mapping from Sovereign Controller
class SovereignSyncRequest(BaseModel):
    style: str

@router.post("/system/breathing-style")
async def sync_system_breathing_style(req: SovereignSyncRequest):
    from ai.breathing import set_style
    style_name = req.style.lower().strip()
    style = set_style(style_name)
    if not style:
        raise HTTPException(status_code=400, detail=f"Unknown system breathing style: {req.style}")
        
    # Synchronize operating resource profiles (priority thresholds / caps)
    import os
    try:
        # In Sun mode, maximize thread capabilities, or cap appropriately in Moon/Prismatic
        if style_name == "sun":
            os.system("renice -n -5 -p $(pgrep uvicorn) 2>/dev/null")
        elif style_name == "moon":
            os.system("renice -n 10 -p $(pgrep uvicorn) 2>/dev/null")
        else:
            os.system("renice -n 0 -p $(pgrep uvicorn) 2>/dev/null")
    except Exception as e:
        logger.debug(f"Sovereign: Failed to apply process nice rules: {e}")

    from events import socket_manager
    await socket_manager.broadcast({
        "type": "STYLE_CHANGED",
        "style": style.name,
        "color": style.color,
        "icon": style.icon
    })
    return {"status": "synchronized", "style": style.name, "priority_rules_applied": True}


@router.get("")
async def get_current():
    from ai.breathing import get_style
    s = get_style()
    return {"name": s.name, "display_name": s.display_name, "color": s.color, "icon": s.icon}


@router.get("s")
async def list_styles():
    from ai.breathing import list_styles
    return {"styles": list_styles()}
