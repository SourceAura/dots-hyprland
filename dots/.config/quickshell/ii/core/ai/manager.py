"""
manager.py — SiM CognitiveManager
====================================
Three-tier inference pipeline:
  1. Reflex Core  — qwen2.5-coder:1.5b  (local, always-on, fast)
  2. Analytic Core — qwen2.5-coder:7b-q4 (local, on-demand, plugged-in)
  3. Cloud        — Nemotron via OpenRouter (fallback, requires API key)

All generation routes through decide_and_generate() → streaming.
"""

import os
import re
import json
import logging
import asyncio
import aiohttp
from pathlib import Path
from typing import Optional, AsyncGenerator

import nest_asyncio
try:
    nest_asyncio.apply()
except ValueError:
    pass

logger = logging.getLogger("sim.ai")


class OllamaLLM:
    """Direct Ollama streaming interface — /api/chat endpoint."""

    def __init__(self, model_id: str):
        from config import OLLAMA_URL, get_model_params
        self.base_url  = OLLAMA_URL
        self.model_id  = model_id
        self._params   = get_model_params(model_id)

    async def generate_stream(
        self,
        prompt: str,
        context: dict = None,
        override_params: dict = None,
    ) -> AsyncGenerator[str, None]:
        """
        Yield clean content tokens. Strips <think>…</think> blocks.
        Injects breathing style + operational context into system prompt.
        """
        from ai.breathing import get_style

        ctx       = context or {}
        style     = get_style()
        ctx_parts = []

        if ctx.get("breathing_style") and ctx["breathing_style"] != "moon":
            from ai.breathing import STYLES
            s = STYLES.get(ctx["breathing_style"])
            if s:
                ctx_parts.append(s.system_prompt)

        if ctx.get("active_rom") and ctx["active_rom"] not in ("none", ""):
            ctx_parts.append(f"Active tool: {ctx['active_rom'].upper()}")

        system = (
            "You are SiM — an intelligent development assistant. "
            "SourceAura is your operator. "
            "Be direct, precise, and brief. No preamble. No filler. "
            "For code: show it. For commands: run them. "
            "For analysis: be sharp.\n\n"
            + style.system_prompt
        )
        if ctx_parts:
            system += "\n\n" + " ".join(ctx_parts)

        params = dict(self._params)
        if override_params:
            params.update(override_params)

        # On battery — cap context and threads
        try:
            bat = Path("/sys/class/power_supply/BAT0/status").read_text().strip()
            if bat == "Discharging":
                params["num_ctx"]    = min(params.get("num_ctx", 4096), 2048)
                params["num_thread"] = min(params.get("num_thread", 4), 3)
                params["keep_alive"] = "0"
        except Exception:
            pass

        payload = {
            "model":      self.model_id,
            "messages":   [
                {"role": "system", "content": system},
                {"role": "user",   "content": prompt},
            ],
            "stream":     True,
            "think":      False,
            "keep_alive": params.pop("keep_alive", "5m"),
            "options":    params,
        }

        timeout  = aiohttp.ClientTimeout(total=120, connect=5, sock_read=120)
        in_think = False

        async with aiohttp.ClientSession(timeout=timeout) as session:
            try:
                async with session.post(
                    f"{self.base_url}/api/chat", json=payload
                ) as resp:
                    if resp.status != 200:
                        yield f"◌ Ollama error: HTTP {resp.status}"
                        return
                    async for line in resp.content:
                        if not line:
                            continue
                        try:
                            chunk = json.loads(line.decode("utf-8"))
                            token = chunk.get("message", {}).get("content", "")
                            if token:
                                buf, out = token, ""
                                while buf:
                                    if in_think:
                                        e = buf.find("</think>")
                                        if e >= 0:
                                            in_think = False
                                            buf = buf[e + 8:]
                                        else:
                                            buf = ""
                                    else:
                                        ts = buf.find("<think>")
                                        if ts >= 0:
                                            out += buf[:ts]
                                            in_think = True
                                            buf = buf[ts + 7:]
                                        else:
                                            out += buf
                                            buf = ""
                                if out:
                                    yield out
                            if chunk.get("done"):
                                break
                        except json.JSONDecodeError:
                            continue
            except asyncio.TimeoutError:
                yield "◌ SiM timeout — Ollama took too long."
            except aiohttp.ClientConnectorError:
                yield "◌ Ollama unreachable — is it running?"
            except Exception as e:
                yield f"◌ Stream error: {type(e).__name__}: {str(e)[:80]}"

    async def is_alive(self) -> bool:
        try:
            from config import OLLAMA_URL
            timeout = aiohttp.ClientTimeout(total=3)
            async with aiohttp.ClientSession(timeout=timeout) as s:
                async with s.get(f"{OLLAMA_URL}/api/tags") as r:
                    return r.status == 200
        except Exception:
            return False

    async def model_exists(self) -> bool:
        """Check if this specific model is pulled."""
        try:
            from config import OLLAMA_URL
            timeout = aiohttp.ClientTimeout(total=3)
            async with aiohttp.ClientSession(timeout=timeout) as s:
                async with s.get(f"{OLLAMA_URL}/api/tags") as r:
                    if r.status != 200:
                        return False
                    data = await r.json()
                    names = [m["name"] for m in data.get("models", [])]
                    # Match exact or with :latest suffix
                    return (self.model_id in names or
                            self.model_id + ":latest" in names or
                            any(n.startswith(self.model_id.split(":")[0]) for n in names))
        except Exception:
            return False


class CloudLLM:
    """OpenRouter cloud fallback — Nemotron or any OpenAI-compatible model."""

    async def generate_stream(
        self,
        prompt: str,
        context: dict = None,
    ) -> AsyncGenerator[str, None]:
        from config import OPENROUTER_API_KEY, OPENROUTER_URL, CLOUD_MODEL
        from ai.breathing import get_style

        if not OPENROUTER_API_KEY:
            yield "◌ Cloud fallback unavailable — set OPENROUTER_API_KEY in .env"
            return

        style = get_style()
        system = (
            "You are SiM — an intelligent development assistant. "
            "Be direct, precise, and brief. " + style.system_prompt
        )

        payload = {
            "model": CLOUD_MODEL,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user",   "content": prompt},
            ],
            "stream": True,
            "temperature": 0.7,
            "max_tokens": 2048,
        }

        headers = {
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "Content-Type":  "application/json",
            "HTTP-Referer":  "https://github.com/sourceaura/sim",
            "X-Title":       "SiM",
        }

        timeout = aiohttp.ClientTimeout(total=60, connect=5)
        last_pos = 0

        async with aiohttp.ClientSession(timeout=timeout) as session:
            try:
                async with session.post(
                    OPENROUTER_URL, json=payload, headers=headers
                ) as resp:
                    if resp.status != 200:
                        yield f"◌ Cloud error: HTTP {resp.status}"
                        return
                    async for line in resp.content:
                        if not line:
                            continue
                        text = line.decode("utf-8").strip()
                        if not text.startswith("data: "):
                            continue
                        data = text[6:]
                        if data == "[DONE]":
                            break
                        try:
                            chunk   = json.loads(data)
                            content = chunk["choices"][0]["delta"].get("content", "")
                            if content:
                                yield content
                        except Exception:
                            continue
            except asyncio.TimeoutError:
                yield "◌ Cloud timeout."
            except Exception as e:
                yield f"◌ Cloud error: {type(e).__name__}: {str(e)[:80]}"


class CognitiveManager:
    """
    Single entry point for all SiM inference.

    decide_and_generate() — streaming, used by WebSocket handler.
    Tier selection:
      1. Reflex (qwen2.5-coder:1.5b) — default, always-on
      2. Analytic (qwen2.5-coder:7b) — when query is complex + plugged in
      3. Cloud (Nemotron/OpenRouter) — explicit @cloud prefix or local failure
    """

    def __init__(self):
        from config import SIM_REFLEX_MODEL, SIM_ANALYTIC_MODEL, DATA_DIR
        self.reflex_model   = SIM_REFLEX_MODEL
        self.analytic_model = SIM_ANALYTIC_MODEL
        self.memory_path    = str(DATA_DIR / "memory.json")

        self._reflex:   Optional[OllamaLLM] = None
        self._analytic: Optional[OllamaLLM] = None
        self._cloud     = CloudLLM()

        self.is_ready         = False
        self.reflex_available = False
        self.analytic_available = False

        self.memory = {"interactions": 0, "chat_history": []}
        self._load_memory()

    async def initialize(self):
        from config import OLLAMA_URL
        logger.info("SiM CognitiveManager: initializing…")

        # Wait for Ollama to be reachable (up to 30s)
        for i in range(10):
            try:
                async with aiohttp.ClientSession() as s:
                    async with s.get(
                        f"{OLLAMA_URL}/api/tags",
                        timeout=aiohttp.ClientTimeout(total=3)
                    ) as r:
                        if r.status == 200:
                            break
            except Exception:
                pass
            logger.info(f"Waiting for Ollama ({i+1}/10)…")
            await asyncio.sleep(3)
        else:
            logger.error("Ollama unreachable after 30s.")
            return

        # Check which models are available
        self._reflex   = OllamaLLM(self.reflex_model)
        self._analytic = OllamaLLM(self.analytic_model)

        self.reflex_available   = await self._reflex.model_exists()
        self.analytic_available = await self._analytic.model_exists()
        self.is_ready           = True  # Ready even if models need pulling

        logger.info(
            f"CognitiveManager ready — "
            f"reflex={'✓' if self.reflex_available else '✗ (needs pull)'} "
            f"analytic={'✓' if self.analytic_available else '✗ (needs pull)'}"
        )

    def _should_use_analytic(self, prompt: str) -> bool:
        """
        Use the analytic model when:
        - Explicit @analytic prefix
        - Plugged in AND prompt is complex (>50 words or contains architecture keywords)
        """
        if prompt.startswith("@analytic ") or prompt.startswith("@7b "):
            return True
        try:
            bat = Path("/sys/class/power_supply/BAT0/status").read_text().strip()
            if bat == "Discharging":
                return False
        except Exception:
            pass
        words = len(prompt.split())
        complex_keywords = [
            "architecture", "design", "refactor", "explain", "analyze",
            "compare", "review", "optimize", "debug", "why", "how does"
        ]
        is_complex = words > 50 or any(k in prompt.lower() for k in complex_keywords)
        return is_complex and self.analytic_available

    def _should_use_cloud(self, prompt: str) -> bool:
        return prompt.startswith("@cloud ") or prompt.startswith("@nemotron ")

    async def decide_and_generate(
        self,
        prompt: str,
        context: dict = None,
    ) -> AsyncGenerator[str, None]:
        """Primary streaming path — called by WebSocket handler."""

        # Strip routing prefixes
        clean = prompt
        for prefix in ("@analytic ", "@7b ", "@cloud ", "@nemotron "):
            if prompt.startswith(prefix):
                clean = prompt[len(prefix):]
                break

        # Tier 3: Cloud
        if self._should_use_cloud(prompt):
            logger.info("SiM: routing to Cloud (Nemotron)")
            async for token in self._cloud.generate_stream(clean, context):
                yield token
            return

        # Tier 2: Analytic
        if self._should_use_analytic(prompt) and self._analytic:
            logger.info(f"SiM: routing to Analytic ({self.analytic_model})")
            async for token in self._analytic.generate_stream(clean, context):
                yield token
            return

        # Tier 1: Reflex (default)
        if not self._reflex:
            yield "◌ SiM not initialized."
            return

        if not self.reflex_available:
            yield (
                f"◌ Model not pulled. Run:\n"
                f"  ollama pull {self.reflex_model}\n"
                f"Then restart the SiM daemon."
            )
            return

        logger.info(f"SiM: routing to Reflex ({self.reflex_model})")
        async for token in self._reflex.generate_stream(clean, context):
            yield token

        # Persist to memory
        self.memory["interactions"] = self.memory.get("interactions", 0) + 1
        self._persist(clean, "")  # response captured by caller

    async def process_message(self, message: str) -> str:
        """Non-streaming fallback."""
        response = ""
        async for token in self.decide_and_generate(message):
            response += token
        return response.strip()

    def _persist(self, user_msg: str, sim_msg: str):
        from datetime import datetime
        hist = self.memory.setdefault("chat_history", [])
        hist.append({
            "role": "user", "content": user_msg,
            "ts": datetime.now().isoformat()
        })
        if sim_msg:
            hist.append({
                "role": "assistant", "content": sim_msg,
                "ts": datetime.now().isoformat()
            })
        if len(hist) > 200:
            self.memory["chat_history"] = hist[-200:]
        self._save_memory()

    def _load_memory(self):
        try:
            if os.path.exists(self.memory_path):
                with open(self.memory_path) as f:
                    self.memory = json.load(f)
        except Exception:
            pass

    def _save_memory(self):
        try:
            os.makedirs(os.path.dirname(self.memory_path), exist_ok=True)
            with open(self.memory_path, "w") as f:
                json.dump(self.memory, f, indent=2)
        except Exception:
            pass


cognitive_manager = CognitiveManager()
