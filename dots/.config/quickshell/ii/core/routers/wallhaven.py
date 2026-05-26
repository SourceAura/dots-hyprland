"""
wallhaven.py — WallHaven API router for live backgrounds.
POST /api/sanctum/wallhaven/cycle — queries WallHaven, downloads high-res wallpaper, caches it, and broadcasts path.
"""

import os
import random
import logging
import asyncio
from pathlib import Path
import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional

logger = logging.getLogger("sim.wallhaven")
router = APIRouter(prefix="/sanctum/wallhaven", tags=["sanctum"])

class CycleRequest(BaseModel):
    query: Optional[str] = None

# Breathing style to query string mapping
STYLE_QUERIES = {
    "sun": ["rose red synthwave dark", "cyberpunk red dark", "minimalist dark red"],
    "moon": ["cerulean blue dark", "stealth cyberpunk", "minimalist dark blue"],
    "prismatic": ["neon rgb cyberpunk", "prismatic neon dark", "purple abstract dark"],
}

FALLBACK_QUERIES = [
    "cyberpunk stealth",
    "minimalist dark",
    "vaporwave dark",
    "retro futurism dark",
]

@router.post("/cycle")
async def cycle_wallpaper(req: Optional[CycleRequest] = None):
    from ai.breathing import get_style
    from events import socket_manager

    # 1. Determine the search query
    query_str = None
    if req and req.query:
        query_str = req.query
    else:
        try:
            style = get_style()
            style_name = style.name.lower().strip()
            queries = STYLE_QUERIES.get(style_name, FALLBACK_QUERIES)
            query_str = random.choice(queries)
        except Exception as e:
            logger.warning(f"Failed to fetch breathing style for WallHaven query: {e}")
            query_str = random.choice(FALLBACK_QUERIES)

    logger.info(f"Querying WallHaven for wallpaper matching: '{query_str}'")

    # 2. Call WallHaven Search API
    # categories: 111 (General, Anime, People)
    # purity: 100 (SFW only)
    # sorting: random (to get a fresh desktop wallpaper every cycle)
    # ratios: 16x9
    # resolutions: 1920x1080+
    wallhaven_url = "https://wallhaven.cc/api/v1/search"
    params = {
        "q": query_str,
        "categories": "111",
        "purity": "100",
        "sorting": "random",
        "ratios": "16x9",
        "atleast": "1920x1080"
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(wallhaven_url, params=params)
            if resp.status_code != 200:
                raise HTTPException(status_code=502, detail=f"WallHaven API returned HTTP {resp.status_code}")
            
            data = resp.json()
            wallpapers = data.get("data", [])
            if not wallpapers:
                # If no results, try with a broad fallback
                fallback_query = random.choice(FALLBACK_QUERIES)
                logger.info(f"No wallpapers found. Trying fallback query: '{fallback_query}'")
                params["q"] = fallback_query
                resp = await client.get(wallhaven_url, params=params)
                if resp.status_code == 200:
                    data = resp.json()
                    wallpapers = data.get("data", [])
            
            if not wallpapers:
                raise HTTPException(status_code=404, detail="No wallpapers found matching the search criteria")

            # Take the first random wallpaper
            chosen = wallpapers[0]
            img_id = chosen.get("id")
            img_url = chosen.get("path")
            img_ext = Path(img_url).suffix or ".jpg"

            if not img_url:
                raise HTTPException(status_code=502, detail="WallHaven returned empty image path")

            # 3. Create Cache Folder
            cache_dir = Path.home() / ".config" / "DankMaterialShell" / "plugins" / "SiM" / "cache"
            cache_dir.mkdir(parents=True, exist_ok=True)
            
            dest_filename = f"wallhaven-{img_id}{img_ext}"
            dest_path = cache_dir / dest_filename

            logger.info(f"Downloading high-res wallpaper: {img_url} to {dest_path}")

            # 4. Download the image
            img_resp = await client.get(img_url)
            if img_resp.status_code != 200:
                raise HTTPException(status_code=502, detail=f"Failed to download image from WallHaven: HTTP {img_resp.status_code}")

            # Save the image content
            with open(dest_path, "wb") as f:
                f.write(img_resp.content)

            # 5. Clean up old wallpapers in the cache to save space
            try:
                for existing_file in cache_dir.glob("wallhaven-*"):
                    if existing_file.is_file() and existing_file.name != dest_filename:
                        existing_file.unlink()
            except Exception as clean_err:
                logger.warning(f"Error cleaning old wallpapers in cache: {clean_err}")

            # 6. Broadcast the new wallpaper path to QML clients
            file_url = f"file://{dest_path.absolute()}"
            await socket_manager.broadcast({
                "type": "WALLPAPER_CHANGED",
                "path": file_url,
                "query": query_str,
                "id": img_id
            })

            logger.info(f"Successfully cycled and cached wallpaper {img_id}. URL broadcasted: {file_url}")
            return {
                "status": "ok",
                "id": img_id,
                "query": query_str,
                "path": file_url
            }

    except httpx.HTTPError as he:
        logger.error(f"WallHaven network connection failed: {he}")
        raise HTTPException(status_code=503, detail=f"WallHaven connection failed: {he}")
    except Exception as e:
        logger.error(f"Failed to cycle wallpaper: {e}")
        raise HTTPException(status_code=500, detail=str(e))
