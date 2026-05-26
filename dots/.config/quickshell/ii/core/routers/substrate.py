# core/routers/substrate.py
# Sun iN Moon (SiM) — Substrate Gateway Router

import json
import logging
import asyncio
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from ai.breathing import get_style
from events import socket_manager

logger = logging.getLogger("sim.substrate")

router = APIRouter(prefix="/substrate", tags=["substrate"])

class CommandRequest(BaseModel):
    command: str

SOCKET_PATH = "/tmp/sim-kasugai.sock"

@router.post("/execute")
async def execute_substrate_command(req: CommandRequest):
    """
    Delegate process execution to the Rust Kasugai Substrate Manager daemon.
    Verifies LAW.mdx policies, synchronizes style contexts, and streams stdout/stderr
    logs via the central WebSocket feed.
    """
    cmd_str = req.command.strip()
    if not cmd_str:
        raise HTTPException(status_code=400, detail="Empty command request")

    style = get_style().name
    logger.info(f"Substrate: Intercepting command '{cmd_str}' under style '{style}'")

    try:
        # Connect to Rust Kasugai daemon Unix socket
        reader, writer = await asyncio.open_unix_connection(SOCKET_PATH)
    except Exception as e:
        logger.error(f"Substrate: Failed to connect to Kasugai socket: {e}")
        raise HTTPException(
            status_code=503, 
            detail="Kasugai Substrate Daemon unreachable. Ensure cargo build and ignitions are complete."
        )

    try:
        # 1. Sync style with Kasugai Guard first
        sync_payload = json.dumps({"type": "SET_STYLE", "payload": style})
        writer.write(f"{sync_payload}\n".encode())
        await writer.drain()
        
        sync_resp = await reader.readline()
        logger.debug(f"Substrate: Kasugai style synced: {sync_resp.decode().strip()}")

        # 2. Invoke execute request
        exec_payload = json.dumps({"type": "EXECUTE_COMMAND", "payload": cmd_str})
        writer.write(f"{exec_payload}\n".encode())
        await writer.drain()

        # 3. Read initial authorization decision
        auth_resp_line = await reader.readline()
        if not auth_resp_line:
            raise ValueError("Empty authorization response from Kasugai")

        auth_decision = json.loads(auth_resp_line.decode())
        logger.info(f"Substrate: Authorization decision: {auth_decision}")

        # Broadcast thoughts and auth decision over the WS feed
        await socket_manager.broadcast({
            "type": "SUBSTRATE_STREAM",
            "stream_type": "auth",
            "data": auth_decision
        })

        if not auth_decision.get("authorized", False):
            writer.close()
            await writer.wait_closed()
            return {
                "status": "denied", 
                "reason": auth_decision.get("reason", "Denied by security manifest."),
                "thoughts": auth_decision.get("thoughts", [])
            }

        # 4. Asynchronously read streaming stdout/stderr lines in background
        async def stream_worker():
            try:
                while True:
                    line_bytes = await reader.readline()
                    if not line_bytes:
                        break
                    
                    line_str = line_bytes.decode().strip()
                    if not line_str:
                        continue
                        
                    try:
                        packet = json.loads(line_str)
                        packet_type = packet.get("type", "")
                        
                        # Forward stdout/stderr packets down the WebSocket pipeline
                        if packet_type in ("STDOUT", "STDERR", "EXIT"):
                            await socket_manager.broadcast({
                                "type": "SUBSTRATE_STREAM",
                                "stream_type": packet_type.lower(),
                                "data": packet.get("data", ""),
                                "code": packet.get("code", 0)
                            })
                            
                            if packet_type == "EXIT":
                                break
                    except json.JSONDecodeError:
                        continue
            except Exception as e:
                logger.error(f"Substrate: Streaming read loop failed: {e}")
            finally:
                writer.close()
                await writer.wait_closed()

        # Fire and forget the stream reader so the API returns immediately with execution acknowledgement
        asyncio.create_task(stream_worker())

        return {
            "status": "executing", 
            "rewritten_command": auth_decision.get("command", cmd_str),
            "thoughts": auth_decision.get("thoughts", [])
        }

    except Exception as e:
        logger.error(f"Substrate: Invocation failed: {e}")
        writer.close()
        await writer.wait_closed()
        raise HTTPException(status_code=500, detail=f"Substrate invocation error: {str(e)}")
