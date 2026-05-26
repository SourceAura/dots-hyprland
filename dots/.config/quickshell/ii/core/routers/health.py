"""
health.py — SiM health endpoints.
GET /api/health/live   — liveness (always 200 if process is up)
GET /api/health/ready  — readiness (checks Ollama)
GET /api/health/status — full vitals for the HUD
"""

import time
import psutil
import shutil
from datetime import datetime, timezone

from fastapi import APIRouter
from fastapi.responses import JSONResponse

router = APIRouter(prefix="/health", tags=["health"])

_start = time.time()


@router.get("/live")
async def liveness():
    return {"status": "alive", "timestamp": datetime.now(timezone.utc).isoformat()}


@router.get("/ready")
async def readiness():
    from ai.manager import cognitive_manager
    if not cognitive_manager.is_ready:
        return JSONResponse(status_code=503, content={"status": "not_ready", "reason": "Ollama not connected"})
    return {"status": "ready", "timestamp": datetime.now(timezone.utc).isoformat()}


@router.get("/status")
async def status():
    from ai.manager import cognitive_manager
    from events import socket_manager

    cpu  = psutil.cpu_percent(interval=None)
    mem  = psutil.virtual_memory()
    disk = shutil.disk_usage("/")

    return {
        "status":    "HEALTHY" if cognitive_manager.is_ready else "DEGRADED",
        "uptime":    round(time.time() - _start, 1),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "components": {
            "ollama":    "up" if cognitive_manager.is_ready else "down",
            "websocket": f"{len(socket_manager.active)} clients",
            "cpu":       f"{cpu}%",
            "memory":    f"{mem.percent}%",
            "disk":      f"{round((disk.used / disk.total) * 100, 1)}%",
        },
    }


@router.post("/reset")
async def reset_system():
    """Trigger a graceful power down and re-ignition of SiM services using sim.sh."""
    import asyncio
    import logging
    logger = logging.getLogger("sim.health")
    
    try:
        # First trigger down
        proc_down = await asyncio.create_subprocess_exec(
            "bash", "/home/sourceaura/.config/DankMaterialShell/plugins/SiM/core/scripts/sim.sh", "down",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        await proc_down.communicate()
        
        # Then trigger ignite/up
        proc_up = await asyncio.create_subprocess_exec(
            "bash", "/home/sourceaura/.config/DankMaterialShell/plugins/SiM/core/scripts/sim.sh", "ignite",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        # Let it run in the background as it pulls/verifies models
        async def wait_for_ignite():
            stdout, stderr = await proc_up.communicate()
            logger.info("SiM Reset: System re-ignited successfully")
            
        asyncio.create_task(wait_for_ignite())
        
        return {
            "status": "resetting",
            "message": "System shutdown initiated. Ignite triggered in background."
        }
    except Exception as e:
        logger.error(f"System reset failure: {e}")
        return {"status": "error", "message": str(e)}
