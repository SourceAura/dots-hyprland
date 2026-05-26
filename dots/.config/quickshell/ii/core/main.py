"""
main.py — SiM Syndicate FastAPI application.
Single-operator local tool. No auth, no multi-user.

The Seven Sibyls own the backend. SiM oversees them all.
"""

import asyncio
import logging
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(name)s %(levelname)s %(message)s",
)
logger = logging.getLogger("sim")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("SiM Syndicate: igniting core services")

    # Database
    from database import init_db
    await init_db()

    # CognitiveCore
    from ai.manager import cognitive_manager
    try:
        await cognitive_manager.initialize()
    except Exception as e:
        logger.error(f"CognitiveCore init failed: {e}")

    # Dependency Check
    from ai.discovery import scan_dependencies
    try:
        scan_dependencies()
    except Exception as e:
        logger.error(f"Dependency discovery failed: {e}")

    # Background tasks
    from events import broadcast_pulse, relay_governor
    tasks = {
        asyncio.create_task(broadcast_pulse()),
        asyncio.create_task(relay_governor()),
    }

    app.state.bg_tasks = tasks
    logger.info("SiM Syndicate API ready — all seven folds active")

    yield

    for t in tasks:
        t.cancel()
    from database import close_db
    await close_db()
    logger.info("SiM Syndicate shutdown complete")


app = FastAPI(
    title="SiM Syndicate",
    description="Sun iN Moon — AI Agency · Seven Sibyls",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
async def _error_handler(request, exc):
    from fastapi import HTTPException
    code = exc.status_code if isinstance(exc, HTTPException) else 500
    return JSONResponse(status_code=code, content={
        "status":    "error",
        "code":      code,
        "message":   str(exc.detail) if hasattr(exc, "detail") else str(exc),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "path":      request.url.path,
    })


# ── Routers ───────────────────────────────────────────────────────────
from routers.health  import router as health_router
from routers.style   import router as style_router
from routers.sibyls  import router as sibyls_router
from routers.shroud  import router as shroud_router
from routers.ori     import router as ori_router
from routers.substrate import router as substrate_router
from routers.wallhaven import router as wallhaven_router

app.include_router(health_router, prefix="/api")
app.include_router(style_router,  prefix="/api")
app.include_router(sibyls_router, prefix="/api")
app.include_router(shroud_router, prefix="/api")
app.include_router(ori_router,    prefix="/api")
app.include_router(substrate_router, prefix="/api")
app.include_router(wallhaven_router, prefix="/api")


# ── Intelligence feed WebSocket ───────────────────────────────────────
@app.websocket("/intelligence-feed")
async def intelligence_feed(ws: WebSocket):
    """
    Primary WebSocket — SiM_QUERY streaming, pulse, governor events.
    QML connects here via Quickshell.Io.WebSocket.
    """
    from events import socket_manager
    await socket_manager.connect(ws)
    try:
        while True:
            data = await ws.receive_text()
            await socket_manager.handle_message(ws, data)
    except WebSocketDisconnect:
        socket_manager.disconnect(ws)
    except Exception as e:
        logger.debug(f"WS error: {e}")
        socket_manager.disconnect(ws)


# ── Root ──────────────────────────────────────────────────────────────
@app.get("/")
async def root():
    return {
        "name":      "SiM Syndicate",
        "version":   "1.0.0",
        "status":    "online",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
