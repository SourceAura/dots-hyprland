#!/usr/bin/env bash
# =============================================================================
# sim.sh — SiM Ignition Protocol
# Sun iN Moon — Intelligent Launcher & IDE
# =============================================================================
# Usage:
#   sim.sh           — full ignition (models + daemon)
#   sim.sh status    — check all components
#   sim.sh down      — graceful shutdown
#   sim.sh models    — pull/verify models only
#   sim.sh daemon    — start daemon only (skip model check)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_step() { echo -e "\n${BOLD}${CYAN}▶  $*${NC}"; }
log_ok()   { echo -e "  ${GREEN}[✓]${NC} $*"; }
log_warn() { echo -e "  ${YELLOW}[!]${NC} $*"; }
log_err()  { echo -e "  ${RED}[✗]${NC} $*" >&2; }
log_info() { echo -e "  ${CYAN}[-]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RELICS_DIR="${PLUGIN_DIR}"
LAPIDARY="${RELICS_DIR}/core/scripts/lapidary.sh"
GOVERNOR_BIN="${RELICS_DIR}/core/bridge/governor/governor/target/release/sim-governor"

# ── Model configuration ───────────────────────────────────────────────
REFLEX_MODEL="qwen2.5-coder:1.5b"
ANALYTIC_MODEL="qwen2.5-coder:7b-instruct-q4_K_M"
SIM_MODEL="sim:latest"
MODELFILE="${RELICS_DIR}/Modelfile"

# =============================================================================
# PHASES
# =============================================================================

phase_governor() {
    log_step "Governor (thermal/battery watchdog)"
    if [[ -f "${GOVERNOR_BIN}" ]]; then
        if pgrep -f "sim-governor" &>/dev/null; then
            log_ok "Governor already running"
        else
            nohup "${GOVERNOR_BIN}" > /tmp/sim-governor.log 2>&1 &
            log_ok "Governor started (PID $!)"
        fi
    else
        log_warn "Governor not built — run: cd ${RELICS_DIR}/core/bridge/governor/governor && cargo build --release"
    fi
}

phase_models() {
    log_step "AI Models"

    if ! command -v ollama &>/dev/null; then
        log_err "ollama not found — install from https://ollama.ai"
        return 1
    fi

    # Check Ollama is running
    if ! curl -sf http://localhost:11434/api/tags &>/dev/null; then
        log_info "Starting Ollama service…"
        systemctl start ollama 2>/dev/null || ollama serve &>/dev/null &
        sleep 2
    fi

    # Pull Reflex Core (required — always-on)
    if ollama list 2>/dev/null | grep -q "^${REFLEX_MODEL}"; then
        log_ok "Reflex Core: ${REFLEX_MODEL} ✓"
    else
        log_info "Pulling Reflex Core: ${REFLEX_MODEL} (~1.1GB)…"
        ollama pull "${REFLEX_MODEL}" && log_ok "Reflex Core ready" || {
            log_err "Failed to pull ${REFLEX_MODEL}"
            return 1
        }
    fi

    # Build sim:latest custom model
    if ollama list 2>/dev/null | grep -q "^sim:"; then
        log_ok "SiM model: sim:latest ✓"
    else
        if [[ -f "${MODELFILE}" ]]; then
            log_info "Building sim:latest from Modelfile…"
            ollama create sim -f "${MODELFILE}" && log_ok "sim:latest built" || log_warn "sim:latest build failed"
        else
            log_warn "Modelfile not found at ${MODELFILE}"
        fi
    fi

    # Check Analytic Core (optional — only pull if plugged in and user wants it)
    if ollama list 2>/dev/null | grep -q "${ANALYTIC_MODEL%%:*}"; then
        log_ok "Analytic Core: ${ANALYTIC_MODEL} ✓"
    else
        log_info "Analytic Core not installed (optional)"
        log_info "To install: ollama pull ${ANALYTIC_MODEL}"
        log_info "Required only for complex analysis tasks (plugged-in only)"
    fi
}

phase_daemon() {
    log_step "SiM Core Daemon (FastAPI + Ollama bridge)"
    if [[ -f "${LAPIDARY}" ]]; then
        bash "${LAPIDARY}" up || log_warn "Daemon failed to start — check /tmp/sim-core.log"
    else
        log_err "lapidary.sh not found at ${LAPIDARY}"
        return 1
    fi
}

# =============================================================================
# COMMANDS
# =============================================================================

cmd_ignite() {
    echo -e "\n${BOLD}${CYAN}◈  SiM — Sun iN Moon${NC}"
    echo -e "${CYAN}   Intelligent Launcher & IDE${NC}\n"

    phase_governor
    phase_models
    phase_daemon

    echo -e "\n${BOLD}${GREEN}  ◈  SiM ignited${NC}"
    echo -e "  ${CYAN}Daemon:${NC} http://127.0.0.1:8765"
    echo -e "  ${CYAN}Models:${NC} ${REFLEX_MODEL} (reflex) | ${ANALYTIC_MODEL} (analytic, optional)"
    echo -e "  ${CYAN}Logs:${NC}   /tmp/sim-core.log\n"
}

cmd_models() {
    phase_models
}

cmd_daemon() {
    phase_daemon
}

cmd_status() {
    echo -e "\n${BOLD}${CYAN}── SiM Status ──────────────────────────────────${NC}"

    # Governor
    if pgrep -f "sim-governor" &>/dev/null; then
        log_ok "Governor: running"
    else
        log_warn "Governor: not running"
    fi

    # Daemon
    if [[ -f "${LAPIDARY}" ]]; then
        bash "${LAPIDARY}" status
    fi

    # Ollama + models
    echo -e "\n${BOLD}${CYAN}── AI Models ───────────────────────────────────${NC}"
    if command -v ollama &>/dev/null && curl -sf http://localhost:11434/api/tags &>/dev/null; then
        log_ok "Ollama: running"
        ollama list 2>/dev/null | grep -E "^(sim|qwen)" | while read -r line; do
            log_ok "  $line"
        done || log_warn "No SiM models found — run: sim.sh models"
    else
        log_warn "Ollama: not running"
    fi

    # Battery state
    if [[ -f /sys/class/power_supply/BAT0/status ]]; then
        BAT_STATUS=$(cat /sys/class/power_supply/BAT0/status)
        BAT_PCT=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "?")
        if [[ "${BAT_STATUS}" == "Discharging" ]]; then
            log_warn "Battery: ${BAT_PCT}% (discharging — Reflex Core only)"
        else
            log_ok "Battery: ${BAT_PCT}% (${BAT_STATUS} — Analytic Core available)"
        fi
    fi
}

cmd_down() {
    log_step "SiM — Powering Down"
    [[ -f "${LAPIDARY}" ]] && bash "${LAPIDARY}" down || true
    pkill -f "sim-governor" 2>/dev/null && log_ok "Governor stopped" || true
    log_ok "SiM offline"
}

# =============================================================================
# ENTRY
# =============================================================================
case "${1:-ignite}" in
    ignite|up|"") cmd_ignite ;;
    status)       cmd_status ;;
    down|stop)    cmd_down ;;
    models)       cmd_models ;;
    daemon)       cmd_daemon ;;
    *)
        echo "Usage: $0 [ignite|status|down|models|daemon]"
        exit 1
        ;;
esac
