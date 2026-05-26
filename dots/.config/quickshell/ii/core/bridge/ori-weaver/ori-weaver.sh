#!/usr/bin/env bash
# ori-weaver.sh — Ori Weaver launcher
# Sets network mode env vars before starting PyQt5 browser process.
# Called by OriWeaver.qml via Quickshell.Io.Process.

MODE="${1:-clearnet}"

# Kill any stale process already holding port 9051
fuser -k 9051/tcp 2>/dev/null || true

case "$MODE" in
    darknet)
        export QTWEBENGINE_CHROMIUM_FLAGS="--proxy-server=socks5://127.0.0.1:9050 --host-resolver-rules=MAP * ~NOTFOUND , EXCLUDE 127.0.0.1"
        ;;
    ipfs)
        export QTWEBENGINE_CHROMIUM_FLAGS=""
        ;;
    *)
        # Default to clearnet
        export QTWEBENGINE_CHROMIUM_FLAGS=""
        ;;
esac

export QTWEBENGINE_DISABLE_SANDBOX=1
export QT_LOGGING_RULES="qt.webenginecontext.info=false"
export ORI_MODE="$MODE"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec python3 "$SCRIPT_DIR/ori_weaver.py" --mode "$MODE" "$@"
