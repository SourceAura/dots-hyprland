"""
shroud.py — Shroud / anonymity status endpoints.
GET  /api/shroud         — current Tor + nftables posture
POST /api/shroud/event   — relay breach events from shroud.sh
GET  /api/shroud/ebpf    — eBPF egress telemetry (from sim-ebpf service)
"""

import asyncio
import logging
from datetime import datetime, timezone
from typing import Any, Dict

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(prefix="/shroud", tags=["shroud"])
logger = logging.getLogger("sim.shroud")


@router.get("")
async def get_shroud_status() -> Dict[str, Any]:
    """Tor bootstrap + nftables killswitch + IPv6 status."""
    result: Dict[str, Any] = {
        "tunnel":            False,
        "killswitch":        False,
        "ipv6_disabled":     True,
        "iface":             "tor",
        "tor_bootstrap_pct": 0,
        "status":            "Exposed",
        "timestamp":         datetime.now(timezone.utc).isoformat(),
    }

    # nftables killswitch
    try:
        import os
        if os.path.exists("/etc/nftables.d/sim.nft"):
            result["killswitch"] = True
        else:
            proc = await asyncio.create_subprocess_exec(
                "nft", "list", "table", "inet", "sim_filter",
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )
            await proc.wait()
            result["killswitch"] = (proc.returncode == 0)
    except Exception as e:
        logger.debug(f"nft check: {e}")

    # Tor bootstrap
    try:
        proc = await asyncio.create_subprocess_exec(
            "journalctl", "-u", "tor@default", "--no-pager", "-b", "-n", "200",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        stdout, _ = await proc.communicate()
        import re
        for line in reversed(stdout.decode(errors="replace").splitlines()):
            if "Bootstrapped" in line:
                m = re.search(r"Bootstrapped (\d+)%", line)
                if m:
                    result["tor_bootstrap_pct"] = int(m.group(1))
                    break
        result["tunnel"] = (result["tor_bootstrap_pct"] == 100)
    except Exception as e:
        logger.debug(f"Tor check: {e}")

    # IPv6
    try:
        proc = await asyncio.create_subprocess_exec(
            "sysctl", "-n", "net.ipv6.conf.all.disable_ipv6",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        stdout, _ = await proc.communicate()
        result["ipv6_disabled"] = stdout.strip() == b"1"
    except Exception as e:
        logger.debug(f"IPv6 check: {e}")

    result["status"] = "Secure" if (result["killswitch"] and result["tunnel"]) else "Exposed"
    return result


class ShroudEvent(BaseModel):
    event:     str
    raw:       str = ""
    timestamp: str = ""


@router.post("/event", status_code=202)
async def relay_shroud_event(payload: ShroudEvent):
    from events import socket_manager
    ts = payload.timestamp or datetime.now(timezone.utc).isoformat()
    logger.warning(f"SHROUD_BREACH: {payload.raw[:200]}")
    await socket_manager.broadcast({
        "type":      "SHROUD_BREACH",
        "severity":  "critical",
        "message":   f"Leak prevented: {payload.raw[:120]}",
        "raw":       payload.raw,
        "timestamp": ts,
    })
    return {"status": "relayed", "timestamp": ts}


@router.get("/ebpf")
async def get_ebpf_telemetry() -> Dict[str, Any]:
    """
    Read latest eBPF egress telemetry from /tmp/sim-ebpf-telemetry.json.
    Written by the sim-ebpf service. Returns empty if not running.
    """
    import os, json
    path = "/tmp/sim-ebpf-telemetry.json"
    if not os.path.exists(path):
        return {"status": "offline", "events": []}
    try:
        with open(path) as f:
            return json.load(f)
    except Exception as e:
        return {"status": "error", "error": str(e), "events": []}


@router.post("/up")
async def raise_shroud():
    """Execute shroud.sh up as root to activate the stealth tunnel."""
    try:
        proc = await asyncio.create_subprocess_exec(
            "sudo", "/home/sourceaura/.config/DankMaterialShell/plugins/SiM/core/scripts/shroud.sh", "up",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        # Wait a short moment or let it run in the background
        stdout, stderr = await proc.communicate()
        return {
            "status": "ok", 
            "code": proc.returncode,
            "stdout": stdout.decode(errors="replace").strip(),
            "stderr": stderr.decode(errors="replace").strip()
        }
    except Exception as e:
        logger.error(f"Shroud up failure: {e}")
        return {"status": "error", "message": str(e)}


@router.post("/down")
async def lift_shroud():
    """Execute shroud.sh down as root to disable the stealth tunnel."""
    try:
        proc = await asyncio.create_subprocess_exec(
            "sudo", "/home/sourceaura/.config/DankMaterialShell/plugins/SiM/core/scripts/shroud.sh", "down",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await proc.communicate()
        return {
            "status": "ok", 
            "code": proc.returncode,
            "stdout": stdout.decode(errors="replace").strip(),
            "stderr": stderr.decode(errors="replace").strip()
        }
    except Exception as e:
        logger.error(f"Shroud down failure: {e}")
        return {"status": "error", "message": str(e)}


@router.post("/toggle")
async def toggle_shroud():
    """Dynamically toggle the state of the shroud based on current status."""
    status_info = await get_shroud_status()
    is_secure = status_info.get("status") == "Secure"
    
    if is_secure:
        return await lift_shroud()
    else:
        return await raise_shroud()
