#!/usr/bin/env bash
# =============================================================================
# shroud.sh — Mist Shroud (Tor isolation)
# Sun iN Moon — Network Anonymity Gate
# =============================================================================
# Manages Tor service lifecycle and nftables killswitch.
# Must run as root (sudo).
# =============================================================================
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

_ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
_warn() { echo -e "${YELLOW}[!]${NC} $*"; }
_err()  { echo -e "${RED}[✗]${NC} $*" >&2; }
_info() { echo -e "${CYAN}[-]${NC} $*"; }
_step() { echo -e "\n${BOLD}${CYAN}▶ $*${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ $EUID -eq 0 ]] || { _err "shroud.sh must run as root (sudo)"; exit 1; }

tor_active()       { systemctl is-active tor@default >/dev/null 2>&1; }
tor_bootstrapped() {
    journalctl -u tor@default --no-pager -b 2>/dev/null \
        | grep "Bootstrapped" | tail -1 \
        | grep -q "100%"
}

cmd_up() {
    _step "Raising the Mist"

    # Disable IPv6
    sysctl -qw net.ipv6.conf.all.disable_ipv6=1
    sysctl -qw net.ipv6.conf.default.disable_ipv6=1
    sysctl -qw net.ipv6.conf.lo.disable_ipv6=1
    _ok "IPv6 disabled"

    # Start Tor
    if tor_active && tor_bootstrapped; then
        _ok "Tor already bootstrapped"
    else
        systemctl restart tor@default
        _ok "Tor service started"
        _info "Waiting for Tor circuit (max 60s)…"
        local elapsed=0
        while (( elapsed < 60 )); do
            if tor_bootstrapped; then
                _ok "Tor circuit established (100%)"
                break
            fi
            sleep 2; (( elapsed += 2 ))
        done
        if ! tor_bootstrapped; then
            _err "Tor failed to bootstrap within 60s"
            return 1
        fi
    fi

    # nftables killswitch — drop all non-Tor traffic
    _info "Engaging killswitch…"
    nft flush ruleset table inet sim_shroud 2>/dev/null || true
    nft add table inet sim_shroud
    nft 'add chain inet sim_shroud output { type filter hook output priority 0; policy drop; }'
    nft add rule inet sim_shroud output oifname "lo" accept
    nft add rule inet sim_shroud output skuid "debian-tor" accept
    _ok "Killswitch engaged — only Tor traffic permitted"
    return 0
}

cmd_down() {
    _step "Lifting the Mist"
    systemctl stop tor@default 2>/dev/null && _ok "Tor stopped" || true
    nft delete table inet sim_shroud 2>/dev/null && _ok "Killswitch removed" || true
    sysctl -qw net.ipv6.conf.all.disable_ipv6=0
    sysctl -qw net.ipv6.conf.default.disable_ipv6=0
    sysctl -qw net.ipv6.conf.lo.disable_ipv6=0
    _ok "IPv6 re-enabled"
    _ok "Shroud lifted"
}

cmd_status() {
    echo -e "\n${BOLD}${CYAN}── Shroud Status ──────────────────────────────${NC}"
    if tor_active; then
        _ok "Tor: RUNNING"
        tor_bootstrapped && _ok "Circuit: ESTABLISHED (100%)" || _warn "Circuit: BOOTSTRAPPING"
    else
        _warn "Tor: STOPPED"
    fi
    if nft list table inet sim_shroud &>/dev/null 2>&1; then
        _ok "Killswitch: ACTIVE"
    else
        _warn "Killswitch: INACTIVE"
    fi
}

CMD="${1:-up}"
case "$CMD" in
    up)     cmd_up ;;
    down)   cmd_down ;;
    status) cmd_status ;;
    *)      echo "Usage: sudo bash shroud.sh [up|down|status]"; exit 1 ;;
esac
