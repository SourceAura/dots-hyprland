#!/usr/bin/env bash
# =============================================================================
# lapidary.sh — SiM Core Daemon Manager
# Manages the FastAPI backend process lifecycle.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENV_DIR="${CORE_DIR}/venv"
PID_FILE="/tmp/sim-core.pid"
LOG_FILE="/tmp/sim-core.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log_ok()   { echo -e "  ${GREEN}[✓]${NC} $*"; }
log_warn() { echo -e "  ${YELLOW}[!]${NC} $*"; }
log_err()  { echo -e "  ${RED}[✗]${NC} $*" >&2; }
log_info() { echo -e "  ${CYAN}[-]${NC} $*"; }

# ── Venv bootstrap ────────────────────────────────────────────────────
ensure_venv() {
    if [[ ! -d "${VENV_DIR}" ]]; then
        log_info "Creating Python venv..."
        python3 -m venv "${VENV_DIR}"
        "${VENV_DIR}/bin/pip" install --quiet --upgrade pip
        "${VENV_DIR}/bin/pip" install --quiet -r "${CORE_DIR}/requirements.txt"
        log_ok "Venv ready"
    fi
}

# ── Commands ──────────────────────────────────────────────────────────
cmd_up() {
    ensure_venv

    if [[ -f "${PID_FILE}" ]]; then
        PID=$(cat "${PID_FILE}")
        if kill -0 "${PID}" 2>/dev/null; then
            log_ok "SiM core already running (PID ${PID})"
            return
        fi
        rm -f "${PID_FILE}"
    fi

    log_info "Starting SiM core daemon..."
    cd "${CORE_DIR}"
    nohup "${VENV_DIR}/bin/uvicorn" main:app \
        --host 127.0.0.1 \
        --port 8765 \
        --log-level warning \
        > "${LOG_FILE}" 2>&1 &
    echo $! > "${PID_FILE}"
    sleep 1

    PID=$(cat "${PID_FILE}")
    if kill -0 "${PID}" 2>/dev/null; then
        log_ok "SiM core running (PID ${PID}) → http://127.0.0.1:8765"
    else
        log_err "SiM core failed to start — check ${LOG_FILE}"
        exit 1
    fi
}

cmd_down() {
    if [[ -f "${PID_FILE}" ]]; then
        PID=$(cat "${PID_FILE}")
        if kill -0 "${PID}" 2>/dev/null; then
            kill "${PID}"
            rm -f "${PID_FILE}"
            log_ok "SiM core stopped"
        else
            rm -f "${PID_FILE}"
            log_warn "SiM core was not running"
        fi
    else
        log_warn "No PID file found"
    fi
}

cmd_status() {
    if [[ -f "${PID_FILE}" ]]; then
        PID=$(cat "${PID_FILE}")
        if kill -0 "${PID}" 2>/dev/null; then
            log_ok "SiM core running (PID ${PID})"
            # Quick health check
            if command -v curl &>/dev/null; then
                STATUS=$(curl -sf http://127.0.0.1:8765/api/health/live 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','?'))" 2>/dev/null || echo "unreachable")
                log_info "Health: ${STATUS}"
            fi
        else
            log_warn "SiM core not running (stale PID)"
            rm -f "${PID_FILE}"
        fi
    else
        log_warn "SiM core not running"
    fi
}

case "${1:-up}" in
    up)     cmd_up ;;
    down)   cmd_down ;;
    status) cmd_status ;;
    restart) cmd_down; cmd_up ;;
    *) echo "Usage: $0 [up|down|status|restart]" ;;
esac
