"""
config.py — SiM Core Configuration
=====================================
Hardware target: Dell Inspiron 17 7791 — i7-10510U, 16GB DDR4, MX250.

Model strategy:
  REFLEX  — qwen2.5-coder:1.5b  (~1.1GB RAM, ~150ms first token)
             Always-on. Handles all inline queries, terminal help, quick tasks.
  ANALYTIC — qwen2.5-coder:7b-instruct-q4_K_M  (~4.1GB RAM, ~800ms first token)
             On-demand. Complex architecture, deep analysis. Plugged-in only.
  CLOUD   — Nemotron via OpenRouter (0 RAM, ~300ms API latency)
             Fallback for tasks that exceed local capability.

Override any value via ~/.config/DankMaterialShell/plugins/SiM/.env
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# ── Paths ─────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CORE_ROOT    = Path(__file__).resolve().parent

load_dotenv(dotenv_path=PROJECT_ROOT / ".env", override=False)

# ── Data ──────────────────────────────────────────────────────────────
DATA_DIR = CORE_ROOT / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)

DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{DATA_DIR}/sim.db")

# ── Ollama ────────────────────────────────────────────────────────────
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434")

# Reflex Core — always-on, fast, fits in RAM alongside everything else
SIM_REFLEX_MODEL   = os.getenv("SIM_REFLEX_MODEL",   "qwen2.5-coder:1.5b")

# Analytic Core — on-demand, plugged-in only
SIM_ANALYTIC_MODEL = os.getenv("SIM_ANALYTIC_MODEL", "qwen2.5-coder:7b-instruct-q4_K_M")

# Cloud fallback — OpenRouter / Nemotron
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
CLOUD_MODEL        = os.getenv("CLOUD_MODEL", "nvidia/nemotron-mini-4b-instruct")
OPENROUTER_URL     = "https://openrouter.ai/api/v1/chat/completions"

# ── Hardware-aware model selection ────────────────────────────────────
def _on_battery() -> bool:
    """True when discharging — use Reflex only."""
    try:
        status = Path("/sys/class/power_supply/BAT0/status").read_text().strip()
        return status == "Discharging"
    except Exception:
        return False

def _cpu_temp_c() -> float:
    """Max CPU temp from thermal zones."""
    try:
        import glob
        temps = []
        for zone in glob.glob("/sys/class/thermal/thermal_zone*/temp"):
            try:
                temps.append(int(Path(zone).read_text().strip()) / 1000.0)
            except Exception:
                pass
        return max(temps) if temps else 0.0
    except Exception:
        return 0.0

def select_model(force_reflex: bool = False) -> str:
    """
    Pick the right model based on current hardware state.
    Returns the Ollama model name to use.
    """
    if force_reflex:
        return SIM_REFLEX_MODEL
    if _on_battery():
        return SIM_REFLEX_MODEL
    if _cpu_temp_c() >= 80.0:
        return SIM_REFLEX_MODEL
    return SIM_REFLEX_MODEL  # Default to reflex; caller can override to analytic

# ── Inference parameters per model ────────────────────────────────────
MODEL_PARAMS = {
    # Reflex — fast, low context, 4 threads (leave 4 for OS + DMS)
    "qwen2.5-coder:1.5b": {
        "num_ctx":     4096,
        "num_thread":  4,
        "temperature": 0.7,
        "keep_alive":  "5m",
    },
    # Analytic — higher context, more threads, longer keep-alive
    "qwen2.5-coder:7b-instruct-q4_K_M": {
        "num_ctx":     8192,
        "num_thread":  6,
        "temperature": 0.6,
        "keep_alive":  "10m",
    },
}

def get_model_params(model: str) -> dict:
    return MODEL_PARAMS.get(model, MODEL_PARAMS["qwen2.5-coder:1.5b"])

# ── IPC sockets ───────────────────────────────────────────────────────
SIM_GOVERNOR_SOCK   = "/tmp/sim-governor.sock"
SIM_KASUGAI_SOCK    = "/tmp/sim-kasugai-events.sock"

# ── Bridge ports ──────────────────────────────────────────────────────
CODEX_PORT      = int(os.getenv("CODEX_PORT",      "9052"))
GRIMOIRE_PORT   = int(os.getenv("GRIMOIRE_PORT",   "9053"))
ORI_WEAVER_PORT = int(os.getenv("ORI_WEAVER_PORT", "9051"))

# ── API ───────────────────────────────────────────────────────────────
API_HOST = os.getenv("SIM_API_HOST", "127.0.0.1")
API_PORT = int(os.getenv("SIM_API_PORT", "8765"))
